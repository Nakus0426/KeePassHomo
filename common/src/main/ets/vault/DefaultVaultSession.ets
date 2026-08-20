import { VaultDocument, VaultSession } from './VaultContracts'

export class DefaultVaultSession implements VaultSession {
  private document: VaultDocument | undefined
  private lastActivityAt: number = 0
  readonly autoLockAfterMs: number = 5 * 60 * 1000

  get locked(): boolean {
    return this.document === undefined
  }

  unlock(document: VaultDocument): void {
    this.document = document
    this.lastActivityAt = Date.now()
  }

  lock(): void {
    this.document = undefined
    this.lastActivityAt = 0
  }

  touch(): void {
    this.lastActivityAt = Date.now()
  }

  shouldAutoLock(now: number = Date.now()): boolean {
    return !this.locked && now - this.lastActivityAt >= this.autoLockAfterMs
  }

  async reauthenticate(authenticate: () => Promise<void>): Promise<void> {
    await authenticate()
    this.touch()
  }

  clearSensitiveData(): void {
    this.lock()
  }

  getDocument(): VaultDocument {
    if (this.document === undefined) {
      throw new Error('保险库已锁定')
    }
    return this.document
  }
}
