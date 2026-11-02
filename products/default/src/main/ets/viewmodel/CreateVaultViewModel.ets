import { custom, minLength, required, stringSchema, ValidationSchema, ValidationValue, VaultAuthMode } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { FormItemController } from '../components/FormItem'

@ObservedV2
export class CreateVaultViewModel {
  @Trace authMode: VaultAuthMode = VaultAuthMode.PasswordAndKey
  // 默认名在实例构造时取资源，此时页面已构建、AppUtil 已初始化。
  @Trace vaultName: string = ResUtil.getStringSync($r('app.string.default_vault_name'))
  @Trace masterPassword: string = ''
  @Trace confirmPassword: string = ''
  readonly vaultNameController: FormItemController = new FormItemController()
  readonly masterPasswordController: FormItemController = new FormItemController()
  readonly confirmPasswordController: FormItemController = new FormItemController()
  readonly vaultNameSchema: ValidationSchema = stringSchema([required($r('app.string.vault_name_required'))])
  readonly masterPasswordSchema: ValidationSchema = stringSchema([
    required($r('app.string.master_password_required')),
    minLength(8, $r('app.string.master_password_min_length')),
  ])
  readonly confirmPasswordSchema: ValidationSchema = stringSchema([
    required($r('app.string.confirm_password_required')),
    custom((value: ValidationValue): ResourceStr | undefined =>
      value === this.masterPassword ? undefined : $r('app.string.password_mismatch'), 'confirmMatch'),
  ])

  constructor() {
    this.vaultNameController.setSchema(this.vaultNameSchema)
    this.masterPasswordController.setSchema(this.masterPasswordSchema)
    this.confirmPasswordController.setSchema(this.confirmPasswordSchema)
  }

  @Computed
  get needsPassword(): boolean {
    return this.authMode !== VaultAuthMode.KeyOnly
  }

  @Computed
  get needsKeyFile(): boolean {
    return this.authMode !== VaultAuthMode.PasswordOnly
  }

  setAuthMode(mode: VaultAuthMode): void {
    this.authMode = mode
  }

  setVaultName(value: string): void {
    this.vaultName = value
  }

  setMasterPassword(value: string): void {
    this.masterPassword = value
    if (this.confirmPassword.length > 0) {
      this.confirmPasswordController.validate(this.confirmPassword)
    }
  }

  setConfirmPassword(value: string): void {
    this.confirmPassword = value
  }

  // 未启用的凭据不参与校验：纯密钥不看密码，纯密码不看密钥文件绑定。
  validate(keyFileBound: boolean): boolean {
    if (!this.vaultNameController.validate(this.vaultName)) {
      return false
    }
    if (this.needsPassword) {
      if (!this.masterPasswordController.validate(this.masterPassword)) {
        return false
      }
      if (!this.confirmPasswordController.validate(this.confirmPassword)) {
        return false
      }
    }
    return !this.needsKeyFile || keyFileBound
  }
}
