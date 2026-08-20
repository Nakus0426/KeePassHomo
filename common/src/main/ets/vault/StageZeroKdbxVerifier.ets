import {
  VaultCredential,
  VaultDocument,
  VaultEntry,
  VaultFormat,
  VaultGroup,
  VaultSource,
} from './VaultContracts'
import { FileVaultRepository } from './FileVaultRepository'
import { KdbxVaultEngine } from './KdbxVaultEngine'

const VALIDATION_FIELD: string = 'KeePassHomo.Validation'

export interface KdbxVerificationResult {
  format: VaultFormat;
  vaultName: string;
  groupCount: number;
  entryCount: number;
  protectedFieldCount: number;
  attachmentCount: number;
  historyCount: number;
}

export class StageZeroKdbxVerifier {
  private readonly engine: KdbxVaultEngine = new KdbxVaultEngine()
  private readonly repository: FileVaultRepository

  constructor(stagingDirectory: string) {
    this.repository = new FileVaultRepository(stagingDirectory)
  }

  async verify(source: VaultSource, password: string,
    keyFileSource?: VaultSource): Promise<KdbxVerificationResult> {
    let keyFileData: ArrayBuffer | undefined
    if (keyFileSource !== undefined) {
      try {
        keyFileData = await this.repository.read(keyFileSource)
      } catch (error) {
        throw new Error(`读取密钥文件失败：${(error as Error).message}`)
      }
    }
    const credential: VaultCredential = {
      password,
      keyFile: keyFileData === undefined ? undefined : new Uint8Array(keyFileData),
    }
    try {
      return await this.verifyWithCredential(source, credential)
    } finally {
      credential.keyFile?.fill(0)
    }
  }

  private async verifyWithCredential(source: VaultSource,
    credential: VaultCredential): Promise<KdbxVerificationResult> {
    let stage: string = '读取 KDBX'
    try {
      const original: ArrayBuffer = await this.repository.read(source)
      stage = '解锁 KDBX'
      const document: VaultDocument = await this.engine.unlock(original, credential)
      const entryUuid: string = this.firstEntryUuid(document.groups)
      const marker: string = Date.now().toString()
      this.engine.setEntryField(document, entryUuid, VALIDATION_FIELD, marker)
      const modified: ArrayBuffer = await this.engine.write(document)
      stage = '写入并校验修改'
      await this.repository.writeSafely(source, modified, async (candidate: ArrayBuffer) => {
        const verified: VaultDocument = await this.engine.validate(candidate, credential)
        this.requireMarker(verified.groups, entryUuid, marker)
      })

      stage = '重新打开修改结果'
      const written: VaultDocument = await this.engine.unlock(await this.repository.read(source), credential)
      this.engine.removeEntryField(written, entryUuid, VALIDATION_FIELD)
      const cleaned: ArrayBuffer = await this.engine.write(written)
      stage = '清理并校验验证标记'
      await this.repository.writeSafely(source, cleaned, async (candidate: ArrayBuffer) => {
        const verified: VaultDocument = await this.engine.validate(candidate, credential)
        this.requireMarkerAbsent(verified.groups, entryUuid)
      })
      stage = '最终重新解锁'
      const finalDocument: VaultDocument = await this.engine.unlock(await this.repository.read(source), credential)
      return this.summarize(finalDocument)
    } catch (error) {
      throw new Error(`${stage}失败：${(error as Error).message}`)
    }
  }

  private firstEntryUuid(groups: VaultGroup[]): string {
    for (const group of groups) {
      if (group.entries.length > 0) {
        return group.entries[0].uuid
      }
      const childUuid: string = this.firstEntryUuid(group.groups)
      if (childUuid.length > 0) {
        return childUuid
      }
    }
    throw new Error('保险库没有可用于修改验证的条目')
  }

  private requireMarker(groups: VaultGroup[], entryUuid: string, marker: string): void {
    const entry: VaultEntry | undefined = this.findEntry(groups, entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    const field = entry.fields.find((item) => item.name === VALIDATION_FIELD)
    if (field === undefined || field.value !== marker) {
      throw new Error('保险库写回校验失败')
    }
  }

  private requireMarkerAbsent(groups: VaultGroup[], entryUuid: string): void {
    const entry: VaultEntry | undefined = this.findEntry(groups, entryUuid)
    if (entry === undefined) {
      throw new Error('保险库条目不存在')
    }
    if (entry.fields.some((item) => item.name === VALIDATION_FIELD)) {
      throw new Error('保险库验证标记清理失败')
    }
  }

  private findEntry(groups: VaultGroup[], entryUuid: string): VaultEntry | undefined {
    for (const group of groups) {
      const entry: VaultEntry | undefined = group.entries.find((item) => item.uuid === entryUuid)
      if (entry !== undefined) {
        return entry
      }
      const childEntry: VaultEntry | undefined = this.findEntry(group.groups, entryUuid)
      if (childEntry !== undefined) {
        return childEntry
      }
    }
    return undefined
  }

  private summarize(document: VaultDocument): KdbxVerificationResult {
    const result: KdbxVerificationResult = {
      format: document.format,
      vaultName: document.name,
      groupCount: 0,
      entryCount: 0,
      protectedFieldCount: 0,
      attachmentCount: 0,
      historyCount: 0,
    }
    this.summarizeGroups(document.groups, result)
    return result
  }

  private summarizeGroups(groups: VaultGroup[], result: KdbxVerificationResult): void {
    for (const group of groups) {
      result.groupCount++
      result.entryCount += group.entries.length
      for (const entry of group.entries) {
        result.protectedFieldCount += entry.fields.filter((field) => field.protected).length
        result.attachmentCount += entry.attachmentCount
        result.historyCount += entry.historyCount
      }
      this.summarizeGroups(group.groups, result)
    }
  }
}
