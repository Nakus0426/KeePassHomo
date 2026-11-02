import { common } from '@kit.AbilityKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { FileUtil, LogUtil, PreferencesUtil } from '@pura/harmony-utils'
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

// 用户取消选择而非真实失败：调用方应静默中止流程。
export class UserCancelledError extends Error {
  constructor() {
    super('用户取消了保存位置选择')
  }
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
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).select(options)
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
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).select(options)
    if (uris === undefined || uris.length === 0) {
      return
    }
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
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).save(options)
    if (uris === undefined || uris.length === 0) {
      throw new UserCancelledError()
    }
    const data: Uint8Array = await generateRandomKeyFile()
    const file: fileIo.File = FileUtil.openSync(uris[0],
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, data.buffer as ArrayBuffer)
    } finally {
      FileUtil.closeSync(file)
    }
    await this.selectKeyFile({
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: FileUtil.getFileName(uris[0]),
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
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).save(options)
    if (uris === undefined || uris.length === 0) {
      throw new UserCancelledError()
    }
    const source: VaultSource = {
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: FileUtil.getFileName(uris[0]),
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

  // 远端库一次性打开：下载、解锁、登记来源；凭据只留在内存，不写最近来源。
  async openWebDavVault(target: WebDavVaultTarget, password: string): Promise<void> {
    const client: WebDavClient = new WebDavClient()
    const data: ArrayBuffer = await client.download(target.fileUrl, target.username, target.webDavPassword)
    const credential: VaultCredential = await this.readCredential(password)
    const engine: KdbxVaultEngine = new KdbxVaultEngine()
    const document: VaultDocument = await engine.unlock(data, credential)
    this.webDavRepository = new WebDavVaultRepository(client, target.username, target.webDavPassword)
    this.source = {
      type: VaultSourceType.WebDav,
      uri: target.fileUrl,
      displayName: target.fileName,
      readOnly: true,
    }
    this.format = document.format
    this.sourceModifiedAt = target.modifiedAt
    this.credential = credential
    this.engine = engine
    this.session.unlock(document)
    // 远端来源不落盘：清掉上一次本地最近来源，避免下次启动误开旧库。
    await this.persistRecentSource()
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

  // 全部条目：不含回收站子树。
  entries(): VaultEntry[] {
    const document: VaultDocument = this.session.getDocument()
    const entries: VaultEntry[] = []
    this.collectEntries(document.groups, entries, document.recycleBinUuid)
    return entries
  }

  // 组筛选：传入组为子树根，命中该组及全部后代组内的条目。
  browse(query: string, mode: VaultBrowseMode, groupUuids: string[] = []): VaultEntry[] {
    const acceptedGroupUuids: string[] = []
    if (groupUuids.length > 0) {
      this.collectSubtreeUuids(this.session.getDocument().groups, groupUuids, acceptedGroupUuids, false)
    }
    const normalizedQuery: string = query.trim().toLocaleLowerCase()
    return this.entries().filter((entry: VaultEntry) => {
      if (mode === VaultBrowseMode.Archived ? !entry.archived : entry.archived) {
        return false
      }
      if (mode === VaultBrowseMode.Favorites && !entry.favorite) {
        return false
      }
      if (acceptedGroupUuids.length > 0 && !acceptedGroupUuids.includes(entry.groupUuid)) {
        return false
      }
      return normalizedQuery.length === 0 || this.searchableText(entry).includes(normalizedQuery)
    }).sort((left: VaultEntry, right: VaultEntry) => left.title.localeCompare(right.title))
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
    const entry: VaultEntry | undefined = this.entries().find((item: VaultEntry) => item.uuid === entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    return entry
  }

  field(entry: VaultEntry, name: string): string {
    return entry.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  loadEntryAvatar(entryUuid: string): ArrayBuffer | undefined {
    return this.engine.loadEntryAvatar(this.session.getDocument(), entryUuid)
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
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).save(options)
    const backupSource: VaultSource = {
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: FileUtil.getFileName(uris[0]),
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
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).save(options)
    if (uris === undefined || uris.length === 0) {
      throw new UserCancelledError()
    }
    const relocated: VaultSource = await repository.relocate(source, uris[0])
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
    PreferencesUtil.putSync(SOURCE_MTIME, this.sourceModifiedAt, PREFERENCES_NAME)
    this.session.touch()
  }
}

export const stageOneVaultStore: StageOneVaultStore = new StageOneVaultStore()
