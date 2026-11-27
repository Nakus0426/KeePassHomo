import { common } from '@kit.AbilityKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { FileUtil, LogUtil, PreferencesUtil } from '@pura/harmony-utils'
import { pickFiles, pickSaveTarget } from './DocumentPicker'
import {
  DefaultVaultSession,
  FileVaultRepository,
  generateRandomKeyFile,
  KdbxVaultEngine,
  keyFileFingerprint,
  VaultAttachmentChange,
  VaultAuthMode,
  VaultCredential,
  VaultDocument,
  VaultEntry,
  VaultEntryInput,
  VaultField,
  VaultFormat,
  VaultGroup,
  VaultRepository,
  VaultRepositoryError,
  VaultRepositoryErrorCategory,
  VaultSource,
  VaultSourceType,
  WebDavClient,
  WebDavVaultRepository,
} from '@ohos/common'

const PREFERENCES_NAME: string = 'vault_source'
const SOURCE_URI: string = 'source_uri'
const SOURCE_NAME: string = 'source_name'
const SOURCE_FORMAT: string = 'source_format'
const SOURCE_MTIME: string = 'source_mtime'
const KEY_FILE_URI: string = 'key_file_uri'
const KEY_FILE_NAME: string = 'key_file_name'

export enum VaultAccess {
  ReadWrite = 'readWrite',
  // KDBX 3.1 只能读；备份并升级到 4.x 后恢复写入。
  ReadOnlyFormat = 'readOnlyFormat',
  // 缺少持久写授权；重新选择同一文件即可获得新的临时写授权。
  ReadOnlyPermission = 'readOnlyPermission',
  // 文件系统只读；换位置另存才能写入。
  ReadOnlyFileSystem = 'readOnlyFileSystem',
  // 文件内容不可用：无法读取，或不是受支持的 KDBX。
  Unreadable = 'unreadable',
}

export enum VaultUnreadableReason {
  // 不是 KDBX 3.1 / 4.x：重新选择才有意义。
  NotKdbx = 'notKdbx',
  // 文件读不到：被移动、已被删除或授权失效，重试有意义。
  CannotOpen = 'cannotOpen',
}

export interface VaultFileSummary {
  name: string;
  format: VaultFormat;
  size: number;
  modifiedAt: number;
  access: VaultAccess;
  // 仅 access 为 Unreadable 时有值。
  unreadableReason?: VaultUnreadableReason;
}

// 远端只读打开所需的现场凭据：不落盘，进程内使用。
export interface WebDavVaultTarget {
  username: string;
  webDavPassword: string;
  fileUrl: string;
  fileName: string;
  modifiedAt: number;
}

export enum VaultBrowseMode {
  All,
  Favorites,
  Archived,
}

export enum VaultSortField {
  Title,
  LastModified,
}

// 搜索命中的维度：同一条目只归入第一个命中的分区，避免结果重复。
export enum VaultSearchMatch {
  Title,
  Tag,
  Group,
  Body,
}

export interface VaultSearchSection {
  match: VaultSearchMatch;
  entries: VaultEntry[];
  // 标签分区里每条条目命中的标签：列表副标题据此说明命中原因，无需再次扫描标签。
  matchedTags: Map<string, string>;
}

export interface VaultTagOption {
  tag: string;
  count: number;
}

export class StageOneVaultStore {
  private context: common.UIAbilityContext | undefined
  private repository: FileVaultRepository | undefined
  private webDavRepository: WebDavVaultRepository | undefined
  private source: VaultSource | undefined
  private keyFileSource: VaultSource | undefined
  private keyFileFingerprint: string = ''
  private keyFileSize: number = 0
  private format: VaultFormat = VaultFormat.Unsupported
  private sourceModifiedAt: number = 0
  private credential: VaultCredential | undefined
  private engine: KdbxVaultEngine = new KdbxVaultEngine()
  private readonly session: DefaultVaultSession = new DefaultVaultSession()
  // 打开失败时保留来源，供摘要页「重试」重新探测同一个文件。
  private lastAttemptedSource: VaultSource | undefined
  // 平铺条目与头像随文档实例缓存，落盘后失效：单条查找不再遍历整棵分组树。
  private entryCacheDocument: VaultDocument | undefined = undefined
  private flatEntriesCache: VaultEntry[] = []
  private entryIndexCache: Map<string, VaultEntry> = new Map()
  private avatarCache: Map<string, ArrayBuffer | undefined> = new Map()

  get failedSource(): VaultSource | undefined {
    return this.lastAttemptedSource
  }

  get hasRecentVault(): boolean {
    return this.source !== undefined
  }

  get locked(): boolean {
    return this.session.locked
  }

  get currentSource(): VaultSource {
    if (this.source === undefined) {
      throw new Error('尚未选择保险库')
    }
    return this.source
  }

  get currentKeyFileName(): string {
    return this.keyFileSource?.displayName ?? ''
  }

  get currentKeyFileUri(): string {
    return this.keyFileSource?.uri ?? ''
  }

  get currentKeyFileFingerprint(): string {
    return this.keyFileFingerprint
  }

  get currentKeyFileSize(): number {
    return this.keyFileSize
  }

  get currentFormat(): VaultFormat {
    return this.format
  }

  get currentModifiedAt(): number {
    return this.sourceModifiedAt
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    this.repository = new FileVaultRepository(context.filesDir)
    try {
      const uri: string = PreferencesUtil.getSync(SOURCE_URI, '', PREFERENCES_NAME) as string
      if (uri.length === 0) {
        return
      }
      // 权限不落盘：先按可读打开，写权限在解锁时现场探测。
      this.source = {
        type: VaultSourceType.LocalFile,
        uri,
        displayName: PreferencesUtil.getSync(SOURCE_NAME, '', PREFERENCES_NAME) as string,
        readOnly: true,
      }
      const keyFileUri: string = PreferencesUtil.getSync(KEY_FILE_URI, '', PREFERENCES_NAME) as string
      if (keyFileUri.length > 0) {
        this.keyFileSource = {
          type: VaultSourceType.LocalFile,
          uri: keyFileUri,
          displayName: PreferencesUtil.getSync(KEY_FILE_NAME, '', PREFERENCES_NAME) as string,
          readOnly: true,
        }
      }
      this.format = PreferencesUtil.getSync(SOURCE_FORMAT, VaultFormat.Unsupported, PREFERENCES_NAME) as VaultFormat
      this.sourceModifiedAt = PreferencesUtil.getSync(SOURCE_MTIME, 0, PREFERENCES_NAME) as number
    } catch (error) {
      throw new Error((error as Error).message)
    }
  }

  async inspect(source: VaultSource): Promise<VaultFileSummary> {
    // 失败时保留来源，摘要页的重试据此重新探测同一文件。
    this.lastAttemptedSource = source
    const repository: FileVaultRepository = this.requireRepository()
    const readableSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: true,
    }
    // picker 的临时授权足以完成识别，持久授权留到模式确定后一次性写入。
    let data: ArrayBuffer
    try {
      data = await repository.read(readableSource)
    } catch (error) {
      // 读不到文件时仍要能展示文件名与体积，错误页据此说明是哪个文件出的问题。
      const failure: Error = error as Error
      LogUtil.error(`读取保险库文件失败，文件名=${source.displayName}，错误=${failure.message}`)
      return this.unreadableSummary(source, VaultUnreadableReason.CannotOpen)
    }
    const format: VaultFormat = this.engine.identify(data)
    if (format === VaultFormat.Unsupported) {
      return this.unreadableSummary(source, VaultUnreadableReason.NotKdbx)
    }
    const access: VaultAccess = await this.resolveAccess(source, format)
    const selectedSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: access !== VaultAccess.ReadWrite,
    }
    this.source = selectedSource
    this.format = format
    await this.persistRecentSource()
    try {
      const stat = FileUtil.statSync(source.uri)
      this.sourceModifiedAt = stat.mtime
      PreferencesUtil.putSync(SOURCE_MTIME, this.sourceModifiedAt, PREFERENCES_NAME)
      return {
        name: source.displayName,
        format,
        size: stat.size,
        modifiedAt: stat.mtime,
        access,
      }
    } catch (error) {
      throw new Error((error as Error).message)
    }
  }

  // 不可读文件也要给出可展示的摘要：错误页需要说明是哪个文件出的问题。
  private unreadableSummary(source: VaultSource, reason: VaultUnreadableReason): VaultFileSummary {
    let size: number = 0
    let modifiedAt: number = 0
    try {
      const stat = FileUtil.statSync(source.uri)
      size = stat.size
      modifiedAt = stat.mtime
    } catch (error) {
      // 文件不存在时无法取体积与时间，保持 0，由页面按未知展示。
      const failure: Error = error as Error
      LogUtil.warn(`读取不可用保险库元信息失败，文件名=${source.displayName}，错误=${failure.message}`)
    }
    return {
      name: source.displayName,
      format: VaultFormat.Unsupported,
      size,
      modifiedAt,
      access: VaultAccess.Unreadable,
      unreadableReason: reason,
    }
  }

  // 写权限必须现场探测：临时授权随进程退出清除，持久授权也须激活后才生效。
  private async resolveAccess(source: VaultSource, format: VaultFormat): Promise<VaultAccess> {
    if (source.type === VaultSourceType.WebDav) {
      return VaultAccess.ReadOnlyFileSystem
    }
    const repository: FileVaultRepository = this.requireRepository()
    const writableSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: false,
    }
    if (format !== VaultFormat.Kdbx31) {
      try {
        repository.isWritable(writableSource)
        await repository.persistAccess(writableSource)
        return VaultAccess.ReadWrite
      } catch (error) {
        const failure: VaultRepositoryError = error as VaultRepositoryError
        if (failure.category !== VaultRepositoryErrorCategory.ReadOnly
          && failure.category !== VaultRepositoryErrorCategory.PermissionDenied) {
          throw failure
        }
        await repository.persistAccess({
          type: source.type,
          uri: source.uri,
          displayName: source.displayName,
          readOnly: true,
        })
        return failure.category === VaultRepositoryErrorCategory.ReadOnly
          ? VaultAccess.ReadOnlyFileSystem
          : VaultAccess.ReadOnlyPermission
      }
    }
    await repository.persistAccess({
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: true,
    })
    return VaultAccess.ReadOnlyFormat
  }

  async chooseLocalVault(): Promise<VaultFileSummary> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    options.fileSuffixFilters = ['KeePass 数据库|.kdbx']
    const uris: string[] = await pickFiles(this.requireContext(), options)
    this.clearKeyFile()
    return this.inspect({
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: FileUtil.getFileName(uris[0]),
      readOnly: false,
    })
  }

  // 重试沿用上次失败的来源，不再拉起选择器。
  async retryFailedSource(): Promise<VaultFileSummary> {
    if (this.lastAttemptedSource === undefined) {
      throw new Error('没有可重试的文件')
    }
    return this.inspect(this.lastAttemptedSource)
  }

  async chooseKeyFile(): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    const uris: string[] = await pickFiles(this.requireContext(), options)
    await this.selectKeyFile({
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: FileUtil.getFileName(uris[0]),
      readOnly: true,
    })
  }

  async selectKeyFile(source: VaultSource): Promise<void> {
    const selected: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: true,
    }
    const repository: FileVaultRepository = this.requireRepository()
    await repository.persistAccess(selected)
    // 指纹与体积来自绑定文件本身；读取失败即绑定失败，不保留半绑定状态。
    const data: ArrayBuffer = await repository.read(selected)
    this.keyFileFingerprint = keyFileFingerprint(new Uint8Array(data))
    this.keyFileSize = data.byteLength
    this.keyFileSource = selected
    if (this.source !== undefined) {
      await this.persistRecentSource()
    }
  }

  // 生成物归用户所有：写入用户选定的位置，读回核对后再绑定；取消保存即视为未生成。
  async generateKeyFile(fileName: string): Promise<void> {
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [fileName]
    options.fileSuffixChoices = ['KeePass 密钥文件|.keyx']
    const uri: string = await pickSaveTarget(this.requireContext(), options)
    const data: Uint8Array = await generateRandomKeyFile()
    const file: fileIo.File = FileUtil.openSync(uri,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, data.buffer as ArrayBuffer)
    } finally {
      FileUtil.closeSync(file)
    }
    await this.selectKeyFile({
      type: VaultSourceType.LocalFile,
      uri: uri,
      displayName: FileUtil.getFileName(uri),
      readOnly: true,
    })
  }

  clearKeyFile(): void {
    this.keyFileSource = undefined
    this.keyFileFingerprint = ''
    this.keyFileSize = 0
  }

  async createVault(name: string, password: string, authMode: VaultAuthMode): Promise<void> {
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`${name}.kdbx`]
    options.fileSuffixChoices = ['KeePass 数据库|.kdbx']
    const uri: string = await pickSaveTarget(this.requireContext(), options)
    const source: VaultSource = {
      type: VaultSourceType.LocalFile,
      uri: uri,
      displayName: FileUtil.getFileName(uri),
      readOnly: false,
    }
    const repository: FileVaultRepository = this.requireRepository()
    const credential: VaultCredential = await this.readCredentialForMode(password, authMode)
    this.engine = new KdbxVaultEngine()
    const document: VaultDocument = await this.engine.create(name, credential)
    const data: ArrayBuffer = await this.engine.write(document)
    await repository.writeSafely(source, data, async (candidate: ArrayBuffer): Promise<void> => {
      await new KdbxVaultEngine().validate(candidate, credential)
    })
    await repository.persistAccess(source)
    this.source = source
    this.sourceModifiedAt = Date.now() / 1000
    this.format = document.format
    this.credential = credential
    this.session.unlock(document)
    // 纯密码库不带密钥文件：残留绑定会被下次解锁混进凭据，导致校验失败。
    if (authMode === VaultAuthMode.PasswordOnly) {
      this.clearKeyFile()
    }
    await this.persistRecentSource()
  }

  async unlock(password: string): Promise<void> {
    const source: VaultSource = this.currentSource
    const repository: VaultRepository = this.repositoryFor(source)
    await this.activateStoredAccess(source)
    const data: ArrayBuffer = await repository.read(source)
    const credential: VaultCredential = await this.readCredential(password)
    this.engine = new KdbxVaultEngine()
    const document: VaultDocument = await this.engine.unlock(data, credential)
    const access: VaultAccess = await this.resolveAccess(source, document.format)
    this.source = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: access !== VaultAccess.ReadWrite,
    }
    await this.persistRecentSource()
    this.credential = credential
    this.format = document.format
    this.session.unlock(document)
  }

  // 进入解锁页前登记远端来源与仓储（不下载、不落盘）。解锁时 unlock() 经 repository.read 按需下载，
  // 与本地来源共用同一条解锁与失败处理路径。
  prepareWebDavTarget(target: WebDavVaultTarget): void {
    this.webDavRepository = new WebDavVaultRepository(
      new WebDavClient(), target.username, target.webDavPassword)
    this.source = {
      type: VaultSourceType.WebDav,
      uri: target.fileUrl,
      displayName: target.fileName,
      readOnly: true,
    }
    this.format = VaultFormat.Unsupported
    this.sourceModifiedAt = target.modifiedAt
    this.clearKeyFile()
  }

  // 激活必须与持久化时的模式一致，否则系统按未持久化拒绝。
  private async activateStoredAccess(source: VaultSource): Promise<void> {
    if (source.type === VaultSourceType.WebDav) {
      return
    }
    const repository: FileVaultRepository = this.requireRepository()
    const writableSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: false,
    }
    if (await repository.hasPersistentAccess(writableSource)) {
      await repository.activateAccess(writableSource)
      return
    }
    await repository.activateAccess({
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: true,
    })
  }

  // 全部条目：不含回收站子树。调用方会排序或筛选，返回副本；平铺结果随文档缓存。
  entries(): VaultEntry[] {
    return this.flatEntries().slice()
  }

  private flatEntries(): VaultEntry[] {
    const document: VaultDocument = this.session.getDocument()
    if (this.entryCacheDocument !== document) {
      this.flatEntriesCache = []
      this.collectEntries(document.groups, this.flatEntriesCache, document.recycleBinUuid)
      this.entryIndexCache.clear()
      for (const entry of this.flatEntriesCache) {
        this.entryIndexCache.set(entry.uuid, entry)
      }
      this.avatarCache.clear()
      this.entryCacheDocument = document
    }
    return this.flatEntriesCache
  }

  // 全库排序是 O(n log n) 且 localeCompare 很贵；统一走按排序字段缓存的 orderedEntries。
  private sortedEntries(): VaultEntry[] {
    return this.orderedEntries(VaultSortField.Title)
  }

  private invalidateOrderCache(): void {
    this.orderCache.clear()
    this.orderCacheDocument = undefined
  }

  hasEntries(): boolean {
    return this.sortedEntries().length > 0
  }

  // 全库条目 uuid（不含回收站）：列表据此清理已删除条目的行模型。
  entryUuids(): Set<string> {
    const uuids: Set<string> = new Set()
    for (const entry of this.sortedEntries()) {
      uuids.add(entry.uuid)
    }
    return uuids
  }

  // 组筛选：传入组为子树根，命中该组及全部后代组内的条目。
  // 标签筛选取并集（任一选中标签命中即可），与分组、搜索叠加。
  browse(query: string, mode: VaultBrowseMode, groupUuids: string[] = [], tags: string[] = [],
    sort: VaultSortField = VaultSortField.Title): VaultEntry[] {
    const acceptedGroups: Set<string> | undefined = this.acceptedGroupUuids(groupUuids)
    const acceptedTags: Set<string> | undefined = tags.length > 0 ? new Set(tags) : undefined
    const normalizedQuery: string = query.trim().toLocaleLowerCase()
    return this.orderedEntries(sort).filter((entry: VaultEntry) => {
      if (mode === VaultBrowseMode.Archived ? !entry.archived : entry.archived) {
        return false
      }
      if (mode === VaultBrowseMode.Favorites && !entry.favorite) {
        return false
      }
      if (acceptedGroups !== undefined && !acceptedGroups.has(entry.groupUuid)) {
        return false
      }
      if (acceptedTags !== undefined && !entry.tags.some((tag: string) => acceptedTags.has(tag))) {
        return false
      }
      return normalizedQuery.length === 0 || this.searchableText(entry).includes(normalizedQuery)
    })
  }

  // 搜索分区：结果仍走同一套筛选，再按命中维度分组；顺序为 标题 / 标签 / 分组 / 内容。
  searchSections(query: string, mode: VaultBrowseMode, groupUuids: string[] = [], tags: string[] = [],
    sort: VaultSortField = VaultSortField.Title): VaultSearchSection[] {
    const normalizedQuery: string = query.trim().toLocaleLowerCase()
    const sections: VaultSearchSection[] = [
      { match: VaultSearchMatch.Title, entries: [], matchedTags: new Map() },
      { match: VaultSearchMatch.Tag, entries: [], matchedTags: new Map() },
      { match: VaultSearchMatch.Group, entries: [], matchedTags: new Map() },
      { match: VaultSearchMatch.Body, entries: [], matchedTags: new Map() },
    ]
    if (normalizedQuery.length === 0) {
      return []
    }
    for (const entry of this.browse(query, mode, groupUuids, tags, sort)) {
      const tag: string = this.matchedTag(entry, normalizedQuery)
      const match: VaultSearchMatch = this.classify(entry, normalizedQuery, tag)
      sections[match].entries.push(entry)
      if (match === VaultSearchMatch.Tag) {
        sections[match].matchedTags.set(entry.uuid, tag)
      }
    }
    return sections.filter((section: VaultSearchSection) => section.entries.length > 0)
  }

  // 标签筛选面板的数据源：全库非归档标签及条目数，按数量降序。
  tagOptions(): VaultTagOption[] {
    const counts: Map<string, number> = new Map()
    for (const entry of this.entries()) {
      if (entry.archived) {
        continue
      }
      for (const tag of entry.tags) {
        counts.set(tag, (counts.get(tag) ?? 0) + 1)
      }
    }
    return Array.from(counts.keys())
      .map((tag: string): VaultTagOption => ({ tag: tag, count: counts.get(tag) ?? 0 }))
      .sort((left: VaultTagOption, right: VaultTagOption) =>
      right.count - left.count || left.tag.localeCompare(right.tag))
  }

  private classify(entry: VaultEntry, normalizedQuery: string, tag: string): VaultSearchMatch {
    if (entry.title.toLocaleLowerCase().includes(normalizedQuery)) {
      return VaultSearchMatch.Title
    }
    if (tag.length > 0) {
      return VaultSearchMatch.Tag
    }
    if (entry.groupPath.toLocaleLowerCase().includes(normalizedQuery) ||
      entry.groupName.toLocaleLowerCase().includes(normalizedQuery)) {
      return VaultSearchMatch.Group
    }
    return VaultSearchMatch.Body
  }

  private matchedTag(entry: VaultEntry, normalizedQuery: string): string {
    return entry.tags.find((tag: string) => tag.toLocaleLowerCase().includes(normalizedQuery)) ?? ''
  }

  // 排序结果按「文档实例 + 排序字段」缓存；新增排序字段只需扩展枚举，不再加一对缓存字段。
  private orderCache: Map<VaultSortField, VaultEntry[]> = new Map()
  private orderCacheDocument: VaultDocument | undefined = undefined

  private orderedEntries(sort: VaultSortField): VaultEntry[] {
    const document: VaultDocument = this.session.getDocument()
    if (this.orderCacheDocument !== document) {
      this.orderCache.clear()
      this.orderCacheDocument = document
    }
    const cached: VaultEntry[] | undefined = this.orderCache.get(sort)
    if (cached !== undefined) {
      return cached
    }
    const ordered: VaultEntry[] = sort === VaultSortField.Title
      ? this.entries().sort((left: VaultEntry, right: VaultEntry) => left.title.localeCompare(right.title))
      : this.entries().sort((left: VaultEntry, right: VaultEntry) =>
      right.lastModifiedAt - left.lastModifiedAt || left.title.localeCompare(right.title))
    this.orderCache.set(sort, ordered)
    return ordered
  }

  // 默认根分组的子树覆盖全库，此时不做分组过滤，省掉一次整棵分组树的遍历。
  private acceptedGroupUuids(groupUuids: string[]): Set<string> | undefined {
    if (groupUuids.length === 0 ||
      (groupUuids.length === 1 && groupUuids[0] === this.defaultGroupUuid())) {
      return undefined
    }
    const acceptedSubtree: string[] = []
    this.collectSubtreeUuids(this.session.getDocument().groups, groupUuids, acceptedSubtree, false)
    return new Set(acceptedSubtree)
  }

  // 全量分组（含根组）：不含回收站子树。
  groups(): VaultGroup[] {
    const document: VaultDocument = this.session.getDocument()
    const groups: VaultGroup[] = []
    this.collectGroups(document.groups, groups, document.recycleBinUuid)
    return groups
  }

  // 顶层分组：根组是容器、非用户归类文件夹，与回收站同样不展示。
  topLevelGroups(): VaultGroup[] {
    const document: VaultDocument = this.session.getDocument()
    if (document.groups.length === 0) {
      return []
    }
    return document.groups[0].groups
      .filter((group: VaultGroup): boolean => !this.isRecycleBin(group, document.recycleBinUuid))
  }

  defaultGroupUuid(): string {
    const document: VaultDocument = this.session.getDocument()
    if (document.groups.length === 0) {
      throw new Error('保险库缺少默认分组')
    }
    return document.groups[0].uuid
  }

  entry(entryUuid: string): VaultEntry {
    this.flatEntries()
    const entry: VaultEntry | undefined = this.entryIndexCache.get(entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    return entry
  }

  field(entry: VaultEntry, name: string): string {
    return entry.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  loadEntryAvatar(entryUuid: string): ArrayBuffer | undefined {
    this.flatEntries()
    if (this.avatarCache.has(entryUuid)) {
      return this.avatarCache.get(entryUuid)
    }
    const data: ArrayBuffer | undefined = this.engine.loadEntryAvatar(this.session.getDocument(), entryUuid)
    this.avatarCache.set(entryUuid, data)
    return data
  }

  // 附件变更与条目写入同一次落盘：先改内存模型，再统一写入并校验。
  async saveEntry(entryUuid: string, input: VaultEntryInput,
    attachmentChanges: VaultAttachmentChange[] = []): Promise<VaultEntry> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能保存条目')
    }
    const document: VaultDocument = this.session.getDocument()
    const saved: VaultEntry = entryUuid.length === 0
      ? this.engine.createEntry(document, input)
      : this.engine.updateEntry(document, entryUuid, input)
    for (const change of attachmentChanges) {
      if (change.data === undefined) {
        this.engine.removeAttachment(document, saved.uuid, change.name)
        continue
      }
      await this.engine.addAttachment(document, saved.uuid, change.name, change.data)
    }
    await this.persistDocument(document)
    return this.entry(saved.uuid)
  }

  // 附件字节按需读取：列表只带名字与体积。
  loadAttachment(entryUuid: string, name: string): ArrayBuffer {
    return this.engine.loadAttachment(this.session.getDocument(), entryUuid, name)
  }

  async deleteEntry(entryUuid: string): Promise<void> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能删除条目')
    }
    const document: VaultDocument = this.session.getDocument()
    this.engine.removeEntry(document, entryUuid)
    await this.persistDocument(document)
  }

  // 批量删除只落盘一次，避免多条操作反复写整库。
  async deleteEntries(entryUuids: string[]): Promise<void> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能删除条目')
    }
    if (entryUuids.length === 0) {
      return
    }
    const document: VaultDocument = this.session.getDocument()
    for (const uuid of entryUuids) {
      this.engine.removeEntry(document, uuid)
    }
    await this.persistDocument(document)
  }

  // 批量归档/恢复同样只落盘一次。
  async setArchivedMany(entryUuids: string[], archived: boolean): Promise<void> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能归档条目')
    }
    if (entryUuids.length === 0) {
      return
    }
    const document: VaultDocument = this.session.getDocument()
    for (const uuid of entryUuids) {
      this.engine.setEntryArchived(document, uuid, archived)
    }
    await this.persistDocument(document)
  }

  async createGroup(parentGroupUuid: string, name: string): Promise<VaultGroup> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能新建分组')
    }
    const document: VaultDocument = this.session.getDocument()
    const created: VaultGroup = this.engine.createGroup(document, parentGroupUuid, name)
    await this.persistDocument(document)
    return created
  }

  // 删除分组：整棵子树按 KDBX 语义移入回收站。
  async deleteGroup(groupUuid: string): Promise<void> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能删除分组')
    }
    const document: VaultDocument = this.session.getDocument()
    this.engine.removeGroup(document, groupUuid)
    await this.persistDocument(document)
  }

  async renameGroup(groupUuid: string, name: string): Promise<VaultGroup> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能重命名分组')
    }
    const document: VaultDocument = this.session.getDocument()
    const renamed: VaultGroup = this.engine.renameGroup(document, groupUuid, name)
    await this.persistDocument(document)
    return renamed
  }

  async setFavorite(entryUuid: string, favorite: boolean): Promise<VaultEntry> {
    const document: VaultDocument = this.session.getDocument()
    const entry: VaultEntry = this.engine.setEntryFavorite(document, entryUuid, favorite)
    await this.persistDocument(document)
    return entry
  }

  async setArchived(entryUuid: string, archived: boolean): Promise<VaultEntry> {
    const document: VaultDocument = this.session.getDocument()
    const entry: VaultEntry = this.engine.setEntryArchived(document, entryUuid, archived)
    await this.persistDocument(document)
    return entry
  }

  async backupAndUpgrade(): Promise<string> {
    const document: VaultDocument = this.session.getDocument()
    if (document.format !== VaultFormat.Kdbx31) {
      throw new Error('当前保险库不需要升级')
    }
    const source: VaultSource = this.currentSource
    const backupName: string = this.backupFileName(source.displayName)
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [backupName]
    options.fileSuffixChoices = ['KeePass 数据库|.kdbx']
    const uri: string = await pickSaveTarget(this.requireContext(), options)
    const backupSource: VaultSource = {
      type: VaultSourceType.LocalFile,
      uri: uri,
      displayName: FileUtil.getFileName(uri),
      readOnly: false,
    }
    const repository: FileVaultRepository = this.requireRepository()
    await repository.persistAccess(backupSource)
    await repository.backup(source, backupSource.uri)

    const credential: VaultCredential = this.requireCredential()
    const upgradeEngine: KdbxVaultEngine = new KdbxVaultEngine()
    const upgradeDocument: VaultDocument = await upgradeEngine.unlock(await repository.read(source), credential)
    const upgradedData: ArrayBuffer = await upgradeEngine.upgrade(upgradeDocument)
    const writableSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: false,
    }
    await repository.persistAccess(writableSource)
    await repository.writeSafely(writableSource, upgradedData,
      async (candidate: ArrayBuffer): Promise<void> => {
        const verified: VaultDocument = await new KdbxVaultEngine().validate(candidate, credential)
        if (verified.format !== VaultFormat.Kdbx4) {
          throw new Error('升级后的保险库不是 KDBX 4')
        }
      })
    this.engine = upgradeEngine
    this.session.unlock(upgradeDocument)
    this.source = writableSource
    this.sourceModifiedAt = Date.now() / 1000
    this.format = upgradeDocument.format
    await this.persistRecentSource()
    this.session.touch()
    return backupSource.displayName
  }

  // 只读文件系统的唯一出路：把当前内容另存到用户新选的位置并切换来源。
  async saveAsLocalVault(): Promise<VaultFileSummary> {
    const source: VaultSource = this.currentSource
    const repository: FileVaultRepository = this.requireRepository()
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [source.displayName]
    options.fileSuffixChoices = ['KeePass 数据库|.kdbx']
    const uri: string = await pickSaveTarget(this.requireContext(), options)
    const relocated: VaultSource = await repository.relocate(source, uri)
    await repository.persistAccess(relocated)
    const format: VaultFormat = this.locked
      ? this.format
      : this.session.getDocument().format
    const access: VaultAccess = await this.resolveAccess(relocated, format)
    this.source = {
      type: relocated.type,
      uri: relocated.uri,
      displayName: relocated.displayName,
      readOnly: access !== VaultAccess.ReadWrite,
    }
    await this.persistRecentSource()
    const stat = FileUtil.statSync(relocated.uri)
    this.sourceModifiedAt = stat.mtime
    PreferencesUtil.putSync(SOURCE_MTIME, this.sourceModifiedAt, PREFERENCES_NAME)
    return {
      name: relocated.displayName,
      format,
      size: stat.size,
      modifiedAt: stat.mtime,
      access,
    }
  }

  touch(): void {
    this.session.touch()
  }

  lock(): void {
    if (this.credential?.keyFile !== undefined) {
      this.credential.keyFile.fill(0)
    }
    if (this.credential !== undefined) {
      this.credential.password = ''
    }
    this.credential = undefined
    this.session.clearSensitiveData()
    this.engine = new KdbxVaultEngine()
    this.invalidateOrderCache()
    this.entryCacheDocument = undefined
    this.flatEntriesCache = []
    this.entryIndexCache.clear()
    this.avatarCache.clear()
  }

  onForeground(): void {
    if (this.session.shouldAutoLock()) {
      this.lock()
    }
  }

  async reauthenticate(password: string): Promise<void> {
    const source: VaultSource = this.currentSource
    const repository: VaultRepository = this.repositoryFor(source)
    const candidate: VaultCredential = await this.readCredential(password)
    try {
      await new KdbxVaultEngine().validate(await repository.read(source), candidate)
      this.session.touch()
    } finally {
      candidate.password = ''
      candidate.keyFile?.fill(0)
    }
  }

  // 创建按所选鉴权方式取材：纯密码不读密钥文件，纯密钥不贡献密码组件。
  private async readCredentialForMode(password: string, authMode: VaultAuthMode): Promise<VaultCredential> {
    if (authMode === VaultAuthMode.PasswordOnly) {
      return { password }
    }
    if (authMode === VaultAuthMode.KeyOnly) {
      return { password: '', keyFile: await this.readBoundKeyFile() }
    }
    // 声明「密码 + 密钥」时必须已绑定密钥文件，避免静默建成纯密码库（与 KeyOnly 对称）。
    return { password, keyFile: await this.readBoundKeyFile() }
  }

  private async readBoundKeyFile(): Promise<Uint8Array> {
    if (this.keyFileSource === undefined) {
      throw new Error('请先绑定密钥文件')
    }
    const data: ArrayBuffer = await this.requireRepository().read(this.keyFileSource)
    return new Uint8Array(data)
  }

  private async readCredential(password: string): Promise<VaultCredential> {
    if (this.keyFileSource === undefined) {
      return { password }
    }
    return { password, keyFile: await this.readBoundKeyFile() }
  }

  private async persistRecentSource(): Promise<void> {
    if (this.context === undefined || this.source === undefined) {
      throw new Error('保险库来源尚未初始化')
    }
    // 远端库凭据不落盘：清理最近来源，避免下次启动按本地 URI 打开。
    if (this.source.type === VaultSourceType.WebDav) {
      PreferencesUtil.putSync(SOURCE_URI, '', PREFERENCES_NAME)
      PreferencesUtil.putSync(SOURCE_NAME, '', PREFERENCES_NAME)
      PreferencesUtil.putSync(SOURCE_FORMAT, VaultFormat.Unsupported, PREFERENCES_NAME)
      PreferencesUtil.putSync(SOURCE_MTIME, 0, PREFERENCES_NAME)
      PreferencesUtil.putSync(KEY_FILE_URI, '', PREFERENCES_NAME)
      PreferencesUtil.putSync(KEY_FILE_NAME, '', PREFERENCES_NAME)
      return
    }
    try {
      PreferencesUtil.putSync(SOURCE_URI, this.source.uri, PREFERENCES_NAME)
      PreferencesUtil.putSync(SOURCE_NAME, this.source.displayName, PREFERENCES_NAME)
      PreferencesUtil.putSync(SOURCE_FORMAT, this.format, PREFERENCES_NAME)
      PreferencesUtil.putSync(SOURCE_MTIME, this.sourceModifiedAt, PREFERENCES_NAME)
      PreferencesUtil.putSync(KEY_FILE_URI, this.keyFileSource?.uri ?? '', PREFERENCES_NAME)
      PreferencesUtil.putSync(KEY_FILE_NAME, this.keyFileSource?.displayName ?? '', PREFERENCES_NAME)
    } catch (error) {
      throw new Error((error as Error).message)
    }
  }

  private requireRepository(): FileVaultRepository {
    if (this.repository === undefined) {
      throw new Error('保险库仓储尚未初始化')
    }
    return this.repository
  }

  private repositoryFor(source: VaultSource): VaultRepository {
    if (source.type === VaultSourceType.WebDav) {
      if (this.webDavRepository === undefined) {
        throw new Error('远端保险库连接已失效，请重新连接')
      }
      return this.webDavRepository
    }
    return this.requireRepository()
  }

  private requireContext(): common.UIAbilityContext {
    if (this.context === undefined) {
      throw new Error('保险库服务尚未初始化')
    }
    return this.context
  }

  private backupFileName(fileName: string): string {
    const stem: string = fileName.toLowerCase().endsWith('.kdbx') ? fileName.slice(0, -5) : fileName
    return `${stem}-backup-${Date.now()}.kdbx`
  }

  private requireCredential(): VaultCredential {
    if (this.credential === undefined) {
      throw new Error('保险库已锁定')
    }
    return this.credential
  }

  // KDBX 回收站由 meta.recycleBinUuid 指向，须按 uuid 而非名字识别。
  private isRecycleBin(group: VaultGroup, recycleBinUuid: string): boolean {
    return group.uuid === recycleBinUuid
  }

  private collectEntries(groups: VaultGroup[], target: VaultEntry[], recycleBinUuid: string): void {
    for (const group of groups) {
      if (this.isRecycleBin(group, recycleBinUuid)) {
        continue
      }
      target.push(...group.entries)
      this.collectEntries(group.groups, target, recycleBinUuid)
    }
  }

  private collectGroups(groups: VaultGroup[], target: VaultGroup[], recycleBinUuid: string): void {
    for (const group of groups) {
      if (this.isRecycleBin(group, recycleBinUuid)) {
        continue
      }
      target.push(group)
      this.collectGroups(group.groups, target, recycleBinUuid)
    }
  }

  private collectSubtreeUuids(groups: VaultGroup[], selected: string[], target: string[],
    inherited: boolean): void {
    for (const group of groups) {
      const matched: boolean = inherited || selected.includes(group.uuid)
      if (matched) {
        target.push(group.uuid)
      }
      this.collectSubtreeUuids(group.groups, selected, target, matched)
    }
  }

  private searchableText(entry: VaultEntry): string {
    const values: string[] = [entry.title, entry.groupPath, entry.tags.join(' ')]
    for (const field of entry.fields) {
      if (!field.protected) {
        values.push(field.value)
      }
    }
    return values.join('\n').toLocaleLowerCase()
  }

  private async persistDocument(document: VaultDocument): Promise<void> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能保存条目')
    }
    const data: ArrayBuffer = await this.engine.write(document)
    const credential: VaultCredential = this.requireCredential()
    try {
      await this.repositoryFor(this.currentSource).writeSafely(this.currentSource, data,
        async (candidate: ArrayBuffer): Promise<void> => {
          await new KdbxVaultEngine().validate(candidate, credential)
        })
    } catch (error) {
      const restoredEngine: KdbxVaultEngine = new KdbxVaultEngine()
      const restoredDocument: VaultDocument = await restoredEngine.unlock(
        await this.repositoryFor(this.currentSource).read(this.currentSource), credential)
      this.engine = restoredEngine
      this.session.unlock(restoredDocument)
      throw error as Error
    }
    this.sourceModifiedAt = Date.now() / 1000
    this.invalidateOrderCache()
    // 写入会原地改文档，缓存的平铺条目与头像必须失效。
    this.entryCacheDocument = undefined
    PreferencesUtil.putSync(SOURCE_MTIME, this.sourceModifiedAt, PREFERENCES_NAME)
    this.session.touch()
  }
}

export const stageOneVaultStore: StageOneVaultStore = new StageOneVaultStore()
