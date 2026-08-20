import {
  Kdbx, KdbxCredentials, KdbxCustomDataMap, KdbxEntry, KdbxGroup, KdbxError, ProtectedValue,
} from 'kdbxweb'
import {
  VaultCredential,
  VaultDocument,
  VaultEngine,
  VaultEntry,
  VaultEntryInput,
  VaultField,
  VaultFormat,
  VaultGroup,
} from './VaultContracts'

const KDBX_SIGNATURE_1: number = 0x9AA2D903
const KDBX_SIGNATURE_2: number = 0xB54BFB67
const FAVORITE_KEY: string = 'KeePassHomo.Favorite'
const ARCHIVED_KEY: string = 'KeePassHomo.Archived'

export enum VaultEngineErrorCategory {
  InvalidFile = 'invalidFile',
  InvalidCredential = 'invalidCredential',
  UnsupportedFormat = 'unsupportedFormat',
  CorruptFile = 'corruptFile'
}

export class VaultEngineError extends Error {
  readonly category: VaultEngineErrorCategory

  constructor(category: VaultEngineErrorCategory, message: string) {
    super(message)
    this.category = category
  }
}

function mapKdbxError(error: KdbxError): VaultEngineError {
  if (error.code === 'InvalidKey') {
    return new VaultEngineError(VaultEngineErrorCategory.InvalidCredential, '保险库凭据无效')
  }
  if (error.code === 'Unsupported') {
    return new VaultEngineError(VaultEngineErrorCategory.UnsupportedFormat, '保险库格式不受支持')
  }
  if (error.code === 'BadSignature') {
    return new VaultEngineError(VaultEngineErrorCategory.InvalidFile, '文件不是有效的 KDBX')
  }
  return new VaultEngineError(VaultEngineErrorCategory.CorruptFile, '保险库内容损坏')
}

function toFormat(data: ArrayBuffer): VaultFormat {
  if (data.byteLength < 12) {
    return VaultFormat.Unsupported
  }
  const view: DataView = new DataView(data)
  if (view.getUint32(0, true) !== KDBX_SIGNATURE_1 || view.getUint32(4, true) !== KDBX_SIGNATURE_2) {
    return VaultFormat.Unsupported
  }
  const major: number = view.getUint32(8, true) >>> 16
  if (major === 3) {
    return VaultFormat.Kdbx31
  }
  if (major === 4) {
    return VaultFormat.Kdbx4
  }
  return VaultFormat.Unsupported
}

function fieldValue(field: string | ProtectedValue): VaultField {
  if (field instanceof ProtectedValue) {
    return { name: '', protected: true, value: field.getText() }
  }
  return { name: '', protected: false, value: field }
}

function readVisibleField(entry: KdbxEntry, name: string): string {
  const field: string | ProtectedValue | undefined = entry.fields.get(name)
  if (field === undefined || field instanceof ProtectedValue) {
    return ''
  }
  return field
}

function groupPath(group: KdbxGroup | undefined): string {
  const names: string[] = []
  let current: KdbxGroup | undefined = group
  while (current !== undefined) {
    names.unshift(current.name ?? '')
    current = current.parentGroup
  }
  return names.filter((name: string) => name.length > 0).join(' / ')
}

function mapEntry(entry: KdbxEntry): VaultEntry {
  const fields: VaultField[] = []
  entry.fields.forEach((field: string | ProtectedValue, name: string) => {
    const mapped: VaultField = fieldValue(field)
    mapped.name = name
    fields.push(mapped)
  })
  return {
    uuid: entry.uuid.id,
    title: readVisibleField(entry, 'Title'),
    groupUuid: entry.parentGroup?.uuid.id ?? '',
    groupName: entry.parentGroup?.name ?? '',
    groupPath: groupPath(entry.parentGroup),
    fields,
    historyCount: entry.history.length,
    attachmentCount: entry.binaries.size,
    tags: entry.tags,
    favorite: entry.customData?.get(FAVORITE_KEY)?.value === 'true',
    archived: entry.customData?.get(ARCHIVED_KEY)?.value === 'true',
    lastModifiedAt: entry.lastModTime,
  }
}

function mapGroup(group: KdbxGroup, parentPath: string = ''): VaultGroup {
  const name: string = group.name === undefined ? '' : group.name
  const path: string = parentPath.length === 0 ? name : `${parentPath} / ${name}`
  const groups: VaultGroup[] = []
  group.groups.forEach((child: KdbxGroup) => groups.push(mapGroup(child, path)))
  const entries: VaultEntry[] = []
  group.entries.forEach((entry: KdbxEntry) => entries.push(mapEntry(entry)))
  return {
    uuid: group.uuid.id,
    name,
    path,
    groups,
    entries,
  }
}

function mapDocument(kdbx: Kdbx): VaultDocument {
  const groups: VaultGroup[] = []
  kdbx.groups.forEach((group: KdbxGroup) => groups.push(mapGroup(group)))
  return {
    format: kdbx.versionMajor === 3 ? VaultFormat.Kdbx31 : VaultFormat.Kdbx4,
    name: kdbx.meta.name === undefined ? '' : kdbx.meta.name,
    groups,
  }
}

export class KdbxVaultEngine implements VaultEngine {
  private readonly documents: Map<VaultDocument, Kdbx> = new Map()

  identify(data: ArrayBuffer): VaultFormat {
    return toFormat(data)
  }

  async unlock(data: ArrayBuffer, credential: VaultCredential): Promise<VaultDocument> {
    const format: VaultFormat = this.identify(data)
    if (format === VaultFormat.Unsupported) {
      if (!this.hasKdbxSignature(data)) {
        throw new VaultEngineError(VaultEngineErrorCategory.InvalidFile, '文件不是有效的 KDBX')
      }
      throw new VaultEngineError(VaultEngineErrorCategory.UnsupportedFormat, '保险库格式不受支持')
    }
    const credentials: KdbxCredentials = new KdbxCredentials(
      ProtectedValue.fromString(credential.password), credential.keyFile)
    try {
      await credentials.ready
      const kdbx: Kdbx = await Kdbx.load(data, credentials, { preserveXml: true })
      const document: VaultDocument = mapDocument(kdbx)
      this.documents.set(document, kdbx)
      return document
    } catch (error) {
      throw mapKdbxError(error as KdbxError)
    }
  }

  async create(name: string, credential: VaultCredential): Promise<VaultDocument> {
    const credentials: KdbxCredentials = new KdbxCredentials(
      ProtectedValue.fromString(credential.password), credential.keyFile)
    await credentials.ready
    const kdbx: Kdbx = Kdbx.create(credentials, name)
    kdbx.createDefaultGroup()
    const document: VaultDocument = mapDocument(kdbx)
    this.documents.set(document, kdbx)
    return document
  }

  createEntry(document: VaultDocument, input: VaultEntryInput): VaultEntry {
    this.requireWritable(document)
    const kdbx: Kdbx = this.getKdbx(document)
    const group: KdbxGroup | undefined = kdbx.getGroup(input.groupUuid)
    if (group === undefined) {
      throw new Error('保险库分组不存在')
    }
    const entry: KdbxEntry = kdbx.createEntry(group)
    this.writeLoginFields(entry, input)
    const mapped: VaultEntry = mapEntry(entry)
    const mappedGroup: VaultGroup | undefined = this.findMappedGroup(document.groups, group.uuid.id)
    if (mappedGroup === undefined) {
      throw new Error('保险库分组映射不存在')
    }
    mappedGroup.entries.push(mapped)
    return mapped
  }

  updateEntry(document: VaultDocument, entryUuid: string, input: VaultEntryInput): VaultEntry {
    this.requireWritable(document)
    const entry: KdbxEntry | undefined = this.findEntry(this.getKdbx(document).groups, entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    const targetGroup: KdbxGroup | undefined = this.getKdbx(document).getGroup(input.groupUuid)
    if (targetGroup === undefined) {
      throw new Error('保险库分组不存在')
    }
    entry.pushHistory()
    if (entry.parentGroup?.uuid.id !== targetGroup.uuid.id) {
      this.getKdbx(document).move(entry, targetGroup)
    }
    this.writeLoginFields(entry, input)
    const mapped: VaultEntry = mapEntry(entry)
    if (!this.replaceMappedEntry(document.groups, mapped)) {
      throw new Error('保险库条目映射不存在')
    }
    return mapped
  }

  setEntryFavorite(document: VaultDocument, entryUuid: string, favorite: boolean): VaultEntry {
    return this.setEntryFlag(document, entryUuid, FAVORITE_KEY, favorite)
  }

  setEntryArchived(document: VaultDocument, entryUuid: string, archived: boolean): VaultEntry {
    return this.setEntryFlag(document, entryUuid, ARCHIVED_KEY, archived)
  }

  setEntryField(document: VaultDocument, entryUuid: string, name: string, value: string,
    protectedValue: boolean = false): void {
    this.requireWritable(document)
    const entry: KdbxEntry | undefined = this.findEntry(this.getKdbx(document).groups, entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    entry.setField(name, value, protectedValue)
  }

  removeEntryField(document: VaultDocument, entryUuid: string, name: string): void {
    this.requireWritable(document)
    const entry: KdbxEntry | undefined = this.findEntry(this.getKdbx(document).groups, entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    entry.fields.delete(name)
  }

  async write(document: VaultDocument): Promise<ArrayBuffer> {
    this.requireWritable(document)
    return this.getKdbx(document).save()
  }

  async validate(data: ArrayBuffer, credential: VaultCredential): Promise<VaultDocument> {
    return this.unlock(data, credential)
  }

  async upgrade(document: VaultDocument): Promise<ArrayBuffer> {
    const kdbx: Kdbx = this.getKdbx(document)
    kdbx.upgrade()
    const data: ArrayBuffer = await kdbx.save()
    document.format = VaultFormat.Kdbx4
    return data
  }

  async selfTest(password: string): Promise<void> {
    await this.selfTestRoundTrip(password)
    const keyFile: Uint8Array = await KdbxCredentials.createRandomKeyFile()
    try {
      await this.selfTestCombinedCredential(password, keyFile)
    } finally {
      keyFile.fill(0)
    }
  }

  private async selfTestRoundTrip(password: string): Promise<void> {
    const credentials: KdbxCredentials = new KdbxCredentials(ProtectedValue.fromString(password))
    await credentials.ready
    const kdbx: Kdbx = Kdbx.create(credentials, 'KeePassHomo 阶段 0')
    kdbx.createDefaultGroup()
    kdbx.createRecycleBin()
    const entry: KdbxEntry = kdbx.createEntry(kdbx.getDefaultGroup())
    entry.setField('Title', '兼容性验证')
    entry.setField('Password', '初始密码', true)
    entry.pushHistory()
    entry.setField('Password', '更新密码', true)
    const attachment = await kdbx.createBinary(new Uint8Array([75, 68, 66, 88]).buffer)
    entry.binaries.set('validation.bin', attachment)
    const version4Data: ArrayBuffer = await kdbx.save()
    const version4: Kdbx = await Kdbx.load(version4Data, credentials)
    const loadedEntry: KdbxEntry = version4.getDefaultGroup().entries[0]
    if (!(loadedEntry.fields.get('Password') instanceof ProtectedValue)
      || loadedEntry.history.length !== 1 || loadedEntry.binaries.size !== 1
      || !version4.meta.recycleBinEnabled) {
      throw new Error('KDBX 4 兼容性自检失败')
    }
    version4.setVersion(3)
    const version3Data: ArrayBuffer = await version4.save()
    const version3Document: VaultDocument = await this.unlock(version3Data, { password })
    if (version3Document.format !== VaultFormat.Kdbx31) {
      throw new Error('KDBX 3.1 识别自检失败')
    }
    try {
      await this.write(version3Document)
      throw new Error('KDBX 3.1 只读约束自检失败')
    } catch (error) {
      if ((error as Error).message !== 'KDBX 3.1 以只读方式打开，请先升级到 KDBX 4') {
        throw error as Error
      }
    }
    const upgraded: Kdbx = await Kdbx.load(await this.upgrade(version3Document), credentials)
    if (upgraded.versionMajor !== 4) {
      throw new Error('KDBX 3.1 升级自检失败')
    }
    await this.requireInvalidCredential(version4Data)
    const invalidFile: ArrayBuffer = version4Data.slice(0)
    new DataView(invalidFile).setUint32(0, 0, true)
    await this.requireCategory(invalidFile, credentials, VaultEngineErrorCategory.InvalidFile)
    const unsupported: ArrayBuffer = version4Data.slice(0)
    new DataView(unsupported).setUint32(8, 0x00050000, true)
    await this.requireCategory(unsupported, credentials, VaultEngineErrorCategory.UnsupportedFormat)
    const corrupt: ArrayBuffer = version4Data.slice(0)
    const corruptBytes: Uint8Array = new Uint8Array(corrupt)
    const lastIndex: number = corruptBytes.length - 1
    corruptBytes[lastIndex] = corruptBytes[lastIndex] ^ 0x01
    await this.requireCategory(corrupt, credentials, VaultEngineErrorCategory.CorruptFile)
  }

  private async selfTestCombinedCredential(password: string, keyFile: Uint8Array): Promise<void> {
    const credentials: KdbxCredentials = new KdbxCredentials(
      ProtectedValue.fromString(password), keyFile)
    await credentials.ready
    const kdbx: Kdbx = Kdbx.create(credentials, 'KeePassHomo 组合凭据验证')
    const data: ArrayBuffer = await kdbx.save()
    const loaded: Kdbx = await Kdbx.load(data, credentials)
    if (loaded.meta.name !== 'KeePassHomo 组合凭据验证') {
      throw new Error('主密码与密钥文件组合凭据自检失败')
    }
  }

  private getKdbx(document: VaultDocument): Kdbx {
    const kdbx: Kdbx | undefined = this.documents.get(document)
    if (kdbx === undefined) {
      throw new Error('保险库文档不属于当前引擎')
    }
    return kdbx
  }

  private requireWritable(document: VaultDocument): void {
    if (document.format === VaultFormat.Kdbx31) {
      throw new Error('KDBX 3.1 以只读方式打开，请先升级到 KDBX 4')
    }
  }

  private hasKdbxSignature(data: ArrayBuffer): boolean {
    if (data.byteLength < 12) {
      return false
    }
    const view: DataView = new DataView(data)
    return view.getUint32(0, true) === KDBX_SIGNATURE_1
      && view.getUint32(4, true) === KDBX_SIGNATURE_2
  }

  private async requireInvalidCredential(data: ArrayBuffer): Promise<void> {
    const wrongCredentials: KdbxCredentials = new KdbxCredentials(
      ProtectedValue.fromString('KeePassHomo-invalid-credential'))
    await wrongCredentials.ready
    await this.requireCategory(data, wrongCredentials, VaultEngineErrorCategory.InvalidCredential)
  }

  private async requireCategory(data: ArrayBuffer, credentials: KdbxCredentials,
    category: VaultEngineErrorCategory): Promise<void> {
    try {
      const credential: VaultCredential = { password: 'unused' }
      if (category === VaultEngineErrorCategory.InvalidCredential
        || category === VaultEngineErrorCategory.CorruptFile) {
        await Kdbx.load(data, credentials)
      } else {
        await this.unlock(data, credential)
      }
    } catch (error) {
      if (category === VaultEngineErrorCategory.InvalidCredential
        || category === VaultEngineErrorCategory.CorruptFile) {
        const mapped: VaultEngineError = mapKdbxError(error as KdbxError)
        if (mapped.category === category) {
          return
        }
        throw new Error(`KDBX 错误分类自检失败：期望 ${category}，实际 ${mapped.category}`)
      }
      const actual: VaultEngineError = error as VaultEngineError
      if (actual.category === category) {
        return
      }
      throw new Error(`KDBX 错误分类自检失败：期望 ${category}，实际 ${actual.category ?? actual.message}`)
    }
    throw new Error(`KDBX 错误分类自检失败：期望 ${category}，实际未抛出错误`)
  }

  private findEntry(groups: KdbxGroup[], entryUuid: string): KdbxEntry | undefined {
    for (const group of groups) {
      for (const entry of group.entries) {
        if (entry.uuid.id === entryUuid) {
          return entry
        }
      }
      const childEntry: KdbxEntry | undefined = this.findEntry(group.groups, entryUuid)
      if (childEntry !== undefined) {
        return childEntry
      }
    }
    return undefined
  }

  private writeLoginFields(entry: KdbxEntry, input: VaultEntryInput): void {
    entry.setField('Title', input.title)
    entry.setField('UserName', input.username)
    entry.setField('Password', input.password, true)
    entry.setField('URL', input.url)
    entry.setField('Notes', input.notes)
    entry.tags = input.tags
  }

  private setEntryFlag(document: VaultDocument, entryUuid: string, key: string, enabled: boolean): VaultEntry {
    this.requireWritable(document)
    const entry: KdbxEntry | undefined = this.findEntry(this.getKdbx(document).groups, entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    entry.pushHistory()
    if (entry.customData === undefined) {
      entry.customData = new Map() as KdbxCustomDataMap
    }
    entry.customData.set(key, { value: enabled ? 'true' : 'false', lastModified: new Date() })
    entry.times.update()
    const mapped: VaultEntry = mapEntry(entry)
    if (!this.replaceMappedEntry(document.groups, mapped)) {
      throw new Error('保险库条目映射不存在')
    }
    return mapped
  }

  private findMappedGroup(groups: VaultGroup[], groupUuid: string): VaultGroup | undefined {
    for (const group of groups) {
      if (group.uuid === groupUuid) {
        return group
      }
      const child: VaultGroup | undefined = this.findMappedGroup(group.groups, groupUuid)
      if (child !== undefined) {
        return child
      }
    }
    return undefined
  }

  private replaceMappedEntry(groups: VaultGroup[], replacement: VaultEntry): boolean {
    for (const group of groups) {
      const index: number = group.entries.findIndex((entry: VaultEntry) => entry.uuid === replacement.uuid)
      if (index >= 0) {
        group.entries[index] = replacement
        return true
      }
      if (this.replaceMappedEntry(group.groups, replacement)) {
        return true
      }
    }
    return false
  }
}
