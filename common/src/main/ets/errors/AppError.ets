import { VaultRepositoryError, VaultRepositoryErrorCategory } from '../vault/FileVaultRepository'
import { VaultEngineError, VaultEngineErrorCategory } from '../vault/KdbxVaultEngine'
import { WebDavProbeError, WebDavProbeErrorCategory } from '../sync/WebDavProbe'

export enum AppErrorCategory {
  File = 'file',
  Storage = 'storage',
  Authentication = 'authentication',
  Permission = 'permission',
  Network = 'network',
  Data = 'data',
  Unknown = 'unknown',
}

export enum AppRecoveryAction {
  None = 'none',
  Retry = 'retry',
  Relocate = 'relocate',
  FreeSpace = 'freeSpace',
  Reauthenticate = 'reauthenticate',
  CheckNetwork = 'checkNetwork',
  EditConfiguration = 'editConfiguration',
  ReviewCertificate = 'reviewCertificate',
  RestoreBackup = 'restoreBackup',
}

export interface AppErrorModel {
  category: AppErrorCategory;
  message: string;
  recoveryAction: AppRecoveryAction;
  logCode: string;
}

export class AppErrorFactory {
  static from(error: Object, fallbackMessage: string): AppErrorModel {
    if (error instanceof VaultRepositoryError) {
      return AppErrorFactory.fromRepository(error)
    }
    if (error instanceof VaultEngineError) {
      return AppErrorFactory.fromEngine(error)
    }
    if (error instanceof WebDavProbeError) {
      return AppErrorFactory.fromWebDav(error)
    }
    const businessError: BusinessError = error as BusinessError
    return {
      category: AppErrorCategory.Unknown,
      message: fallbackMessage,
      recoveryAction: AppRecoveryAction.Retry,
      logCode: businessError.code === undefined ? 'unknown' : businessError.code.toString(),
    }
  }

  private static fromRepository(error: VaultRepositoryError): AppErrorModel {
    if (error.category === VaultRepositoryErrorCategory.NotFound) {
      return AppErrorFactory.model(AppErrorCategory.File, '保险库文件不存在，请重新定位',
        AppRecoveryAction.Relocate, error.code)
    }
    if (error.category === VaultRepositoryErrorCategory.PermissionDenied) {
      return AppErrorFactory.model(AppErrorCategory.Permission, '保险库文件授权已失效，请重新定位',
        AppRecoveryAction.Relocate, error.code)
    }
    if (error.category === VaultRepositoryErrorCategory.NoSpace) {
      return AppErrorFactory.model(AppErrorCategory.Storage, '存储空间不足，请释放空间后重试',
        AppRecoveryAction.FreeSpace, error.code)
    }
    if (error.category === VaultRepositoryErrorCategory.ReadOnly) {
      return AppErrorFactory.model(AppErrorCategory.File, '当前保险库为只读来源，请选择可写副本',
        AppRecoveryAction.Relocate, error.code)
    }
    return AppErrorFactory.model(AppErrorCategory.File, '保险库文件操作失败，请重试',
      AppRecoveryAction.Retry, error.code)
  }

  private static fromEngine(error: VaultEngineError): AppErrorModel {
    if (error.category === VaultEngineErrorCategory.InvalidCredential) {
      return AppErrorFactory.model(AppErrorCategory.Authentication, '凭据不正确或文件无法解密',
        AppRecoveryAction.Reauthenticate)
    }
    if (error.category === VaultEngineErrorCategory.UnsupportedFormat) {
      return AppErrorFactory.model(AppErrorCategory.Data, '保险库格式不受支持，请选择 KDBX 3.1 或 KDBX 4 文件',
        AppRecoveryAction.Relocate)
    }
    if (error.category === VaultEngineErrorCategory.InvalidFile) {
      return AppErrorFactory.model(AppErrorCategory.Data, '文件不是有效的 KDBX，请重新选择',
        AppRecoveryAction.Relocate)
    }
    return AppErrorFactory.model(AppErrorCategory.Data, '保险库内容损坏，请从备份恢复',
      AppRecoveryAction.RestoreBackup)
  }

  private static fromWebDav(error: WebDavProbeError): AppErrorModel {
    if (error.category === WebDavProbeErrorCategory.Authentication) {
      return AppErrorFactory.model(AppErrorCategory.Authentication, 'WebDAV 凭据无效，请重新认证',
        AppRecoveryAction.Reauthenticate)
    }
    if (error.category === WebDavProbeErrorCategory.Tls) {
      return AppErrorFactory.model(AppErrorCategory.Network, 'WebDAV 证书校验失败，请检查证书',
        AppRecoveryAction.ReviewCertificate)
    }
    if (error.category === WebDavProbeErrorCategory.Network) {
      return AppErrorFactory.model(AppErrorCategory.Network, '网络连接失败，请检查网络后重试',
        AppRecoveryAction.CheckNetwork)
    }
    if (error.category === WebDavProbeErrorCategory.InvalidInput ||
      error.category === WebDavProbeErrorCategory.NotFound ||
      error.category === WebDavProbeErrorCategory.Unsupported ||
      error.category === WebDavProbeErrorCategory.MissingVersion) {
      return AppErrorFactory.model(AppErrorCategory.Network, 'WebDAV 配置不可用，请检查服务器设置',
        AppRecoveryAction.EditConfiguration)
    }
    return AppErrorFactory.model(AppErrorCategory.Network, 'WebDAV 服务暂时不可用，请重试',
      AppRecoveryAction.Retry)
  }

  private static model(category: AppErrorCategory, message: string, recoveryAction: AppRecoveryAction,
    code: number = 0): AppErrorModel {
    return {
      category,
      message,
      recoveryAction,
      logCode: code === 0 ? 'unknown' : code.toString(),
    }
  }
}
