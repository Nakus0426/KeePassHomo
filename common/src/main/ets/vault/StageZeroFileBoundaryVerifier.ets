import {
  classifyVaultRepositoryErrorCode,
  FileVaultRepository,
  VaultRepositoryError,
  VaultRepositoryErrorCategory,
} from './FileVaultRepository'
import { VaultSource } from './VaultContracts'
import { LogUtil } from '@pura/harmony-utils'

export class StageZeroFileBoundaryVerifier {
  private readonly repository: FileVaultRepository

  constructor(repository: FileVaultRepository) {
    this.repository = repository
  }

  async verify(source: VaultSource): Promise<void> {
    LogUtil.info('阶段 0 文件边界验证开始')
    await this.repository.persistAccess(source)
    LogUtil.info('阶段 0 文件边界：持久授权写入完成')
    await this.repository.activateAccess(source)
    LogUtil.info('阶段 0 文件边界：持久授权激活完成')
    const persistentState: boolean = await this.repository.hasPersistentAccess(source)
    if (!persistentState) {
      LogUtil.warn('阶段 0 文件边界：API 26 持久授权状态检查返回 false，以激活和实际文件访问结果为准')
    }
    await this.repository.read(source)
    LogUtil.info('阶段 0 文件边界：持久授权实际读取成功')
    if (!this.repository.isWritable(source)) {
      throw new Error('所选测试文件不可写')
    }
    await this.verifyReadOnlyBoundary(source)
    LogUtil.info('阶段 0 文件边界：只读写入拒绝验证成功')
    this.verifyStorageErrorContract()
    LogUtil.info('阶段 0 文件边界：空间、只读和授权失效错误码分类成功')
    LogUtil.info('阶段 0 文件边界验证完成')
  }

  private async verifyReadOnlyBoundary(source: VaultSource): Promise<void> {
    const readOnlySource: VaultSource = {
      type: source.type,
      uri: source.uri,
      displayName: source.displayName,
      readOnly: true,
    }
    if (this.repository.isWritable(readOnlySource)) {
      throw new Error('只读来源状态验证失败')
    }
    try {
      await this.repository.writeSafely(readOnlySource, new ArrayBuffer(0), async (): Promise<void> => {
      })
    } catch (error) {
      this.requireCategory(error, VaultRepositoryErrorCategory.ReadOnly)
      return
    }
    throw new Error('只读来源写入边界验证失败')
  }

  private verifyStorageErrorContract(): void {
    const codes: number[] = [13900025, 13900041, 13900027, 13900001, 13900012, 201]
    const categories: VaultRepositoryErrorCategory[] = [
      VaultRepositoryErrorCategory.NoSpace,
      VaultRepositoryErrorCategory.NoSpace,
      VaultRepositoryErrorCategory.ReadOnly,
      VaultRepositoryErrorCategory.PermissionDenied,
      VaultRepositoryErrorCategory.PermissionDenied,
      VaultRepositoryErrorCategory.PermissionDenied,
    ]
    for (let index = 0; index < codes.length; index++) {
      if (classifyVaultRepositoryErrorCode(codes[index]) !== categories[index]) {
        throw new Error(`文件系统错误码 ${codes[index]} 分类验证失败`)
      }
    }
  }

  private requireCategory(error: Error, expected: VaultRepositoryErrorCategory): void {
    const repositoryError: VaultRepositoryError = error as VaultRepositoryError
    if (repositoryError.category !== expected) {
      throw new Error(`文件错误分类失败：期望 ${expected}，实际 ${repositoryError.category ?? error.message}`)
    }
  }
}
