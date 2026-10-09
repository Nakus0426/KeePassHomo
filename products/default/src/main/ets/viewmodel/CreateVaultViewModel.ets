import { custom, required, stringSchema, ValidationSchema, ValidationValue } from '@ohos/common'
import { FormItemController } from '../components/FormItem'

const DEFAULT_VAULT_NAME: string = '个人保险库'

@ObservedV2
export class CreateVaultViewModel {
  @Trace vaultName: string = DEFAULT_VAULT_NAME
  @Trace masterPassword: string = ''
  @Trace confirmPassword: string = ''
  readonly vaultNameController: FormItemController = new FormItemController()
  readonly masterPasswordController: FormItemController = new FormItemController()
  readonly confirmPasswordController: FormItemController = new FormItemController()
  readonly vaultNameSchema: ValidationSchema = stringSchema([required($r('app.string.vault_name_required'))])
  readonly masterPasswordSchema: ValidationSchema =
    stringSchema([required($r('app.string.master_password_required'))])
  readonly confirmPasswordSchema: ValidationSchema = stringSchema([
    required($r('app.string.confirm_password_required')),
    custom((value: ValidationValue): ResourceStr | undefined =>
      value === this.masterPassword ? undefined : $r('app.string.password_mismatch'), 'confirmMatch'),
  ])

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

  validate(): string | undefined {
    if (!this.vaultNameController.validate(this.vaultName)) {
      return 'vaultName'
    }
    if (!this.masterPasswordController.validate(this.masterPassword)) {
      return 'masterPassword'
    }
    if (!this.confirmPasswordController.validate(this.confirmPassword)) {
      return 'confirmPassword'
    }
    return undefined
  }
}
