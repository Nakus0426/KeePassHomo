import { common } from '@kit.AbilityKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { preferences } from '@kit.ArkData'
import {
  DefaultVaultSession,
  FileVaultRepository,
  KdbxVaultEngine,
  VaultCredential,
  VaultDocument,
  VaultEntry,
  VaultEntryInput,
  VaultField,
  VaultFormat,
  VaultGroup,
  VaultRepositoryError,
  VaultRepositoryErrorCategory,
  VaultSource,
  VaultSourceType,
} from '@ohos/common'

const PREFERENCES_NAME: string = 'vault_source'
const SOURCE_URI: string = 'source_uri'
const SOURCE_NAME: string = 'source_name'
const SOURCE_READ_ONLY: string = 'source_read_only'
const KEY_FILE_URI: string = 'key_file_uri'
const KEY_FILE_NAME: string = 'key_file_name'

export interface VaultFileSummary {
  name: string;
  format: VaultFormat;
  size: number;
  modifiedAt: number;
  readOnly: boolean;
}

export enum VaultBrowseMode {
  All,
  Favorites,
  Archived,
}

export class StageOneVaultStore {
  private context: common.UIAbilityContext | undefined
  private repository: FileVaultRepository | undefined
  private source: VaultSource | undefined
  private pendingCreateSource: VaultSource | undefined
  private keyFileSource: VaultSource | undefined
  private credential: VaultCredential | undefined
  private engine: KdbxVaultEngine = new KdbxVaultEngine()
  private readonly session: DefaultVaultSession = new DefaultVaultSession()

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

  get currentFormat(): VaultFormat {
    return this.session.getDocument().format
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    this.repository = new FileVaultRepository(context.filesDir)
    const data: preferences.Preferences = await preferences.getPreferences(context, PREFERENCES_NAME)
    const uri: string = data.getSync(SOURCE_URI, '') as string
    if (uri.length === 0) {
      return
    }
    this.source = {
      type: VaultSourceType.LocalFile,
      uri,
      displayName: data.getSync(SOURCE_NAME, '') as string,
      readOnly: data.getSync(SOURCE_READ_ONLY, false) as boolean,
    }
    const keyFileUri: string = data.getSync(KEY_FILE_URI, '') as string
    if (keyFileUri.length > 0) {
      this.keyFileSource = {
        type: VaultSourceType.LocalFile,
        uri: keyFileUri,
        displayName: data.getSync(KEY_FILE_NAME, '') as string,
        readOnly: true,
      }
    }
  }

  async inspect(source: VaultSource): Promise<VaultFileSummary> {
    const repository: FileVaultRepository = this.requireRepository()
    const readableSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: true,
    }
    await repository.persistAccess(readableSource)
    const data: ArrayBuffer = await repository.read(readableSource)
    const format: VaultFormat = this.engine.identify(data)
    if (format === VaultFormat.Unsupported) {
      throw new Error('文件不是受支持的 KDBX 3.1 或 KDBX 4.x')
    }
    let readOnly: boolean = format === VaultFormat.Kdbx31
    if (!readOnly) {
      try {
        repository.isWritable(source)
        await repository.persistAccess(source)
      } catch (error) {
        const failure: VaultRepositoryError = error as VaultRepositoryError
        if (failure.category !== VaultRepositoryErrorCategory.ReadOnly
          && failure.category !== VaultRepositoryErrorCategory.PermissionDenied) {
          throw failure
        }
        readOnly = true
      }
    }
    const selectedSource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly,
    }
    this.source = selectedSource
    await this.persistRecentSource()
    const stat: fileIo.Stat = fileIo.statSync(source.uri)
    return {
      name: source.displayName,
      format,
      size: stat.size,
      modifiedAt: stat.mtime,
      readOnly,
    }
  }

  async chooseLocalVault(): Promise<VaultFileSummary> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    options.fileSuffixFilters = ['KeePass 数据库|.kdbx']
    this.clearKeyFile()
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).select(options)
    return this.inspect({
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: this.fileName(uris[0]),
      readOnly: false,
    })
  }

  async chooseCreateLocation(vaultName: string): Promise<string> {
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`${vaultName}.kdbx`]
    options.fileSuffixChoices = ['KeePass 数据库|.kdbx']
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).save(options)
    this.pendingCreateSource = {
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: this.fileName(uris[0]),
      readOnly: false,
    }
    return this.pendingCreateSource.displayName
  }

  async chooseKeyFile(): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    const uris: string[] = await new picker.DocumentViewPicker(this.requireContext()).select(options)
    await this.selectKeyFile({
      type: VaultSourceType.LocalFile,
      uri: uris[0],
      displayName: this.fileName(uris[0]),
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
    await this.requireRepository().persistAccess(selected)
    this.keyFileSource = selected
    if (this.source !== undefined) {
      await this.persistRecentSource()
    }
  }

  clearKeyFile(): void {
    this.keyFileSource = undefined
  }

  async createVault(name: string, password: string): Promise<void> {
    if (this.pendingCreateSource === undefined) {
      throw new Error('尚未选择保险库保存位置')
    }
    const source: VaultSource = this.pendingCreateSource
    const repository: FileVaultRepository = this.requireRepository()
    await repository.persistAccess(source)
    const credential: VaultCredential = await this.readCredential(password)
    this.engine = new KdbxVaultEngine()
    const document: VaultDocument = await this.engine.create(name, credential)
    const data: ArrayBuffer = await this.engine.write(document)
    await repository.writeSafely(source, data, async (candidate: ArrayBuffer): Promise<void> => {
      await new KdbxVaultEngine().validate(candidate, credential)
    })
    this.source = source
    this.pendingCreateSource = undefined
    this.credential = credential
    this.session.unlock(document)
    await this.persistRecentSource()
  }

  async unlock(password: string): Promise<void> {
    const repository: FileVaultRepository = this.requireRepository()
    const source: VaultSource = this.currentSource
    await repository.activateAccess(source)
    const data: ArrayBuffer = await repository.read(source)
    const credential: VaultCredential = await this.readCredential(password)
    this.engine = new KdbxVaultEngine()
    const document: VaultDocument = await this.engine.unlock(data, credential)
    this.credential = credential
    this.session.unlock(document)
  }

  entries(): VaultEntry[] {
    const entries: VaultEntry[] = []
    this.collectEntries(this.session.getDocument().groups, entries)
    return entries
  }

  browse(query: string, mode: VaultBrowseMode, groupUuid: string = ''): VaultEntry[] {
    const normalizedQuery: string = query.trim().toLocaleLowerCase()
    return this.entries().filter((entry: VaultEntry) => {
      if (mode === VaultBrowseMode.Archived ? !entry.archived : entry.archived) {
        return false
      }
      if (mode === VaultBrowseMode.Favorites && !entry.favorite) {
        return false
      }
      if (groupUuid.length > 0 && entry.groupUuid !== groupUuid) {
        return false
      }
      return normalizedQuery.length === 0 || this.searchableText(entry).includes(normalizedQuery)
    }).sort((left: VaultEntry, right: VaultEntry) => left.title.localeCompare(right.title))
  }

  groups(): VaultGroup[] {
    const groups: VaultGroup[] = []
    this.collectGroups(this.session.getDocument().groups, groups)
    return groups
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

  async saveEntry(entryUuid: string, input: VaultEntryInput): Promise<VaultEntry> {
    if (this.currentSource.readOnly) {
      throw new Error('只读保险库不能保存条目')
    }
    const document: VaultDocument = this.session.getDocument()
    const saved: VaultEntry = entryUuid.length === 0
      ? this.engine.createEntry(document, input)
      : this.engine.updateEntry(document, entryUuid, input)
    await this.persistDocument(document)
    return saved
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
      displayName: this.fileName(uris[0]),
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
    await this.persistRecentSource()
    this.session.touch()
    return backupSource.displayName
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
    const repository: FileVaultRepository = this.requireRepository()
    const candidate: VaultCredential = await this.readCredential(password)
    try {
      await new KdbxVaultEngine().validate(await repository.read(source), candidate)
      this.session.touch()
    } finally {
      candidate.password = ''
      candidate.keyFile?.fill(0)
    }
  }

  private async readCredential(password: string): Promise<VaultCredential> {
    if (this.keyFileSource === undefined) {
      return { password }
    }
    const data: ArrayBuffer = await this.requireRepository().read(this.keyFileSource)
    return { password, keyFile: new Uint8Array(data) }
  }

  private async persistRecentSource(): Promise<void> {
    if (this.context === undefined || this.source === undefined) {
      throw new Error('保险库来源尚未初始化')
    }
    const data: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME)
    data.putSync(SOURCE_URI, this.source.uri)
    data.putSync(SOURCE_NAME, this.source.displayName)
    data.putSync(SOURCE_READ_ONLY, this.source.readOnly)
    data.putSync(KEY_FILE_URI, this.keyFileSource?.uri ?? '')
    data.putSync(KEY_FILE_NAME, this.keyFileSource?.displayName ?? '')
    await data.flush()
  }

  private requireRepository(): FileVaultRepository {
    if (this.repository === undefined) {
      throw new Error('保险库仓储尚未初始化')
    }
    return this.repository
  }

  private requireContext(): common.UIAbilityContext {
    if (this.context === undefined) {
      throw new Error('保险库服务尚未初始化')
    }
    return this.context
  }

  private fileName(uri: string): string {
    return decodeURIComponent(uri.split('/').pop() as string)
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

  private collectEntries(groups: VaultGroup[], target: VaultEntry[]): void {
    for (const group of groups) {
      target.push(...group.entries)
      this.collectEntries(group.groups, target)
    }
  }

  private collectGroups(groups: VaultGroup[], target: VaultGroup[]): void {
    for (const group of groups) {
      target.push(group)
      this.collectGroups(group.groups, target)
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
      await this.requireRepository().writeSafely(this.currentSource, data,
        async (candidate: ArrayBuffer): Promise<void> => {
          await new KdbxVaultEngine().validate(candidate, credential)
        })
    } catch (error) {
      const restoredEngine: KdbxVaultEngine = new KdbxVaultEngine()
      const restoredDocument: VaultDocument = await restoredEngine.unlock(
        await this.requireRepository().read(this.currentSource), credential)
      this.engine = restoredEngine
      this.session.unlock(restoredDocument)
      throw error as Error
    }
    this.session.touch()
  }
}

export const stageOneVaultStore: StageOneVaultStore = new StageOneVaultStore()
