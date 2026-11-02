import { WebDavClient } from '../sync/WebDavClient'
import { VaultRepository, VaultSource } from './VaultContracts'
import { VaultRepositoryError, VaultRepositoryErrorCategory } from './FileVaultRepository'

// 远端保险库本轮只读：读取走 WebDAV GET，任何写入直接失败，不做静默降级。
export class WebDavVaultRepository implements VaultRepository {
  private readonly client: WebDavClient
  private readonly username: string
  private readonly password: string

  constructor(client: WebDavClient, username: string, password: string) {
    this.client = client
    this.username = username
    this.password = password
  }

  async read(source: VaultSource): Promise<ArrayBuffer> {
    return this.client.download(source.uri, this.username, this.password)
  }

  async persistAccess(_source: VaultSource): Promise<void> {
  }

  async hasPersistentAccess(_source: VaultSource): Promise<boolean> {
    return true
  }

  async activateAccess(_source: VaultSource): Promise<void> {
  }

  async revokeAccess(_source: VaultSource): Promise<void> {
  }

  async writeSafely(_source: VaultSource, _data: ArrayBuffer,
    _validate: (candidate: ArrayBuffer) => Promise<void>): Promise<void> {
    throw new VaultRepositoryError(VaultRepositoryErrorCategory.ReadOnly, 0, '远端保险库为只读')
  }

  async backup(_source: VaultSource, _destinationUri: string): Promise<void> {
    throw new VaultRepositoryError(VaultRepositoryErrorCategory.ReadOnly, 0, '远端保险库为只读')
  }

  async relocate(_source: VaultSource, _destinationUri: string): Promise<VaultSource> {
    throw new VaultRepositoryError(VaultRepositoryErrorCategory.ReadOnly, 0, '远端保险库为只读')
  }

  isWritable(_source: VaultSource): boolean {
    throw new VaultRepositoryError(VaultRepositoryErrorCategory.ReadOnly, 0, '远端保险库为只读')
  }
}
