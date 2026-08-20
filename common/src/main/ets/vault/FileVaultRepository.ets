import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, fileShare } from '@kit.CoreFileKit'
import { Logger } from '../utils/Logger'
import { VaultRepository, VaultSource } from './VaultContracts'

export enum VaultRepositoryErrorCategory {
  NotFound = 'not_found',
  PermissionDenied = 'permission_denied',
  NoSpace = 'no_space',
  ReadOnly = 'read_only',
  Other = 'other'
}

export class VaultRepositoryError extends Error {
  readonly category: VaultRepositoryErrorCategory
  readonly code: number

  constructor(category: VaultRepositoryErrorCategory, code: number, message: string) {
    super(message)
    this.name = 'VaultRepositoryError'
    this.category = category
    this.code = code
  }
}

export function classifyVaultRepositoryErrorCode(code: number): VaultRepositoryErrorCategory {
  if (code === 13900002) {
    return VaultRepositoryErrorCategory.NotFound
  }
  if (code === 13900001 || code === 13900012 || code === 201) {
    return VaultRepositoryErrorCategory.PermissionDenied
  }
  if (code === 13900025 || code === 13900041) {
    return VaultRepositoryErrorCategory.NoSpace
  }
  if (code === 13900027) {
    return VaultRepositoryErrorCategory.ReadOnly
  }
  return VaultRepositoryErrorCategory.Other
}

export class FileVaultRepository implements VaultRepository {
  private readonly stagingDirectory: string
  private readonly logger: Logger = new Logger()

  constructor(stagingDirectory: string) {
    this.stagingDirectory = stagingDirectory
  }

  async read(source: VaultSource): Promise<ArrayBuffer> {
    this.logger.info(`文件读取开始，来源类型=${source.type}`)
    try {
      const stat: fileIo.Stat = fileIo.statSync(source.uri)
      const file: fileIo.File = fileIo.openSync(source.uri, fileIo.OpenMode.READ_ONLY)
      const data: ArrayBuffer = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, data, { offset: 0, length: stat.size })
      fileIo.closeSync(file)
      this.logger.info(`文件读取成功，字节数=${stat.size}`)
      return data
    } catch (error) {
      this.logBoundaryError('文件读取', error)
      throw this.classifyFileError(error as BusinessError)
    }
  }

  async persistAccess(source: VaultSource): Promise<void> {
    this.logger.info(`持久授权开始，模式=${this.modeName(source)}`)
    try {
      const combined: fileShare.PolicyInfo = this.combinedPolicy(source)
      const combinedState: boolean = (await fileShare.checkPersistentPermission([combined]))[0]
      this.logger.info(`持久授权组合策略检查结果=${combinedState}`)
      if (combinedState) {
        this.logger.info('持久授权已存在，跳过迁移')
        return
      }
      for (const policy of this.policies(source)) {
        const policyState: boolean = (await fileShare.checkPersistentPermission([policy]))[0]
        this.logger.info(`持久授权单项策略检查，模式=${policy.operationMode}，结果=${policyState}`)
        if (policyState) {
          this.logger.info(`撤销旧持久授权开始，模式=${policy.operationMode}`)
          await fileShare.revokePermission([policy])
          this.logger.info(`撤销旧持久授权成功，模式=${policy.operationMode}`)
        }
      }
      await fileShare.persistPermission([combined])
      this.logger.info('持久授权组合策略写入成功')
    } catch (error) {
      this.logBoundaryError('持久授权', error)
      throw this.classifyFileError(error as BusinessError)
    }
  }

  async hasPersistentAccess(source: VaultSource): Promise<boolean> {
    this.logger.info(`持久授权状态检查开始，模式=${this.modeName(source)}`)
    try {
      const result: boolean[] = await fileShare.checkPersistentPermission([this.combinedPolicy(source)])
      this.logger.info(`持久授权状态检查结果=${result[0]}`)
      return result[0]
    } catch (error) {
      this.logBoundaryError('持久授权状态检查', error)
      throw this.classifyFileError(error as BusinessError)
    }
  }

  async activateAccess(source: VaultSource): Promise<void> {
    this.logger.info(`持久授权激活开始，模式=${this.modeName(source)}`)
    try {
      await fileShare.activatePermission([this.combinedPolicy(source)])
      this.logger.info('持久授权激活成功')
    } catch (error) {
      this.logBoundaryError('持久授权激活', error)
      throw this.classifyFileError(error as BusinessError)
    }
  }

  async revokeAccess(source: VaultSource): Promise<void> {
    this.logger.info(`持久授权撤销开始，模式=${this.modeName(source)}`)
    try {
      const policy: fileShare.PolicyInfo = this.combinedPolicy(source)
      await fileShare.deactivatePermission([policy])
      this.logger.info('持久授权取消使能成功')
      await fileShare.revokePermission([policy])
      this.logger.info('持久授权撤销成功')
    } catch (error) {
      this.logBoundaryError('持久授权撤销', error)
      throw this.classifyFileError(error as BusinessError)
    }
  }

  async writeSafely(source: VaultSource, data: ArrayBuffer,
    validate: (candidate: ArrayBuffer) => Promise<void>): Promise<void> {
    if (source.readOnly) {
      throw new VaultRepositoryError(VaultRepositoryErrorCategory.ReadOnly, 0, '保险库为只读来源')
    }
    const nonce: string = Date.now().toString()
    const temporaryUri: string = `${this.stagingDirectory}/vault-${nonce}.tmp`
    const backupUri: string = `${this.stagingDirectory}/vault-${nonce}.bak`
    let backupCreated: boolean = false
    let removeBackup: boolean = false
    try {
      this.writeFile(temporaryUri, data, true)
      const candidate: ArrayBuffer = await this.read({
        type: source.type,
        uri: temporaryUri,
        displayName: source.displayName,
        readOnly: false,
      })
      await validate(candidate)
      const backup: ArrayBuffer = await this.read(source)
      this.writeFile(backupUri, backup, true)
      backupCreated = true
      this.overwrite(source.uri, candidate)
      await validate(await this.read(source))
      removeBackup = true
    } catch (error) {
      const failure: Error = error as Error
      if (backupCreated) {
        try {
          const backup: ArrayBuffer = await this.read({
            type: source.type,
            uri: backupUri,
            displayName: source.displayName,
            readOnly: false,
          })
          this.overwrite(source.uri, backup)
          await validate(await this.read(source))
          removeBackup = true
        } catch (restoreError) {
          throw new Error(`保险库恢复失败，恢复副本已保留：${(restoreError as Error).message}`)
        }
      }
      throw failure
    } finally {
      this.removeIfExists(temporaryUri)
      if (removeBackup) {
        this.removeIfExists(backupUri)
      }
    }
  }

  async backup(source: VaultSource, destinationUri: string): Promise<void> {
    const data: ArrayBuffer = await this.read(source)
    this.writeFile(destinationUri, data, true)
  }

  async relocate(source: VaultSource, destinationUri: string): Promise<VaultSource> {
    await this.backup(source, destinationUri)
    return {
      type: source.type,
      uri: destinationUri,
      displayName: source.displayName,
      readOnly: false,
    }
  }

  isWritable(source: VaultSource): boolean {
    if (source.readOnly) {
      this.logger.info('可写检查跳过，来源声明为只读')
      return false
    }
    this.logger.info('文件可写检查开始')
    try {
      const file: fileIo.File = fileIo.openSync(source.uri, fileIo.OpenMode.READ_WRITE)
      fileIo.closeSync(file)
      this.logger.info('文件可写检查成功')
      return true
    } catch (error) {
      this.logBoundaryError('文件可写检查', error)
      throw this.classifyFileError(error as BusinessError)
    }
  }

  private overwrite(uri: string, data: ArrayBuffer): void {
    this.writeFile(uri, data, false)
  }

  private writeFile(uri: string, data: ArrayBuffer, create: boolean): void {
    const mode: number = create
      ? fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      : fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC
    let file: fileIo.File | undefined
    try {
      file = fileIo.openSync(uri, mode)
      fileIo.writeSync(file.fd, data)
      fileIo.fsyncSync(file.fd)
    } catch (error) {
      throw this.classifyFileError(error as BusinessError)
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file)
        } catch (error) {
          throw this.classifyFileError(error as BusinessError)
        }
      }
    }
  }

  private removeIfExists(uri: string): void {
    try {
      if (fileIo.accessSync(uri)) {
        fileIo.unlinkSync(uri)
      }
    } catch (error) {
      throw this.classifyFileError(error as BusinessError)
    }
  }

  private policies(source: VaultSource): fileShare.PolicyInfo[] {
    const policies: fileShare.PolicyInfo[] = [{
      uri: source.uri,
      operationMode: fileShare.OperationMode.READ_MODE,
    }]
    if (!source.readOnly) {
      policies.push({
        uri: source.uri,
        operationMode: fileShare.OperationMode.WRITE_MODE,
      })
    }
    return policies
  }

  private combinedPolicy(source: VaultSource): fileShare.PolicyInfo {
    return {
      uri: source.uri,
      operationMode: source.readOnly
        ? fileShare.OperationMode.READ_MODE
        : fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
    }
  }

  private modeName(source: VaultSource): string {
    return source.readOnly ? 'read' : 'read-write'
  }

  private logBoundaryError(operation: string, boundaryError: BusinessError): void {
    const code: string = boundaryError.code === undefined ? 'unknown' : boundaryError.code.toString()
    const message: string = boundaryError.message === undefined ? 'unknown' : boundaryError.message
    this.logger.error(`${operation}失败，错误码=${code}，错误消息=${message}`)
  }

  private classifyFileError(error: BusinessError): VaultRepositoryError {
    const category: VaultRepositoryErrorCategory = classifyVaultRepositoryErrorCode(error.code)
    if (category === VaultRepositoryErrorCategory.NotFound) {
      return new VaultRepositoryError(category, error.code, '保险库文件不存在')
    }
    if (category === VaultRepositoryErrorCategory.PermissionDenied) {
      return new VaultRepositoryError(category, error.code, '保险库文件授权已失效')
    }
    if (category === VaultRepositoryErrorCategory.NoSpace) {
      return new VaultRepositoryError(category, error.code, '存储空间不足')
    }
    if (category === VaultRepositoryErrorCategory.ReadOnly) {
      return new VaultRepositoryError(category, error.code, '保险库文件系统为只读')
    }
    return new VaultRepositoryError(category, error.code, `保险库文件操作失败，错误码：${error.code}`)
  }
}
