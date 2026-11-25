import { promptAction } from '@kit.ArkUI'
import { ReauthenticationPurpose } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { DsDialog } from '../../components/DsDialog'
import { DsInput } from '../../components/DsInput'
import { DsToastHost } from '../../components/DsToast'
import { IconToggleButton } from '../../components/IconToggleButton'

// 附件明文离开保险库（导出、预览）前的统一门禁：认证通过后由调用方执行具体动作。
@ComponentV2
export struct AttachmentReauthDialog {
  @Param controller: promptAction.DialogController = new promptAction.DialogController()
  @Require @Param message: ResourceStr
  @Require @Param confirmLabel: ResourceStr
  @Event onAuthenticated: () => void = () => {
  }
  @Local private password: string = ''
  @Local private passwordVisible: boolean = false
  @Local private busy: boolean = false
  private readonly app: AppViewModel = appViewModel

  // 认证成功先收起弹窗，再由调用方打开导出/预览，避免系统选择器压在弹窗下面。
  private submit(): void {
    if (this.password.length === 0 || this.busy) {
      return
    }
    this.busy = true
    const password: string = this.password
    this.app.session.reauthenticate(ReauthenticationPurpose.ExportData, password, async () => {
      this.busy = false
      this.controller.close()
      this.onAuthenticated()
    }).catch((error: Error) => {
      this.busy = false
      LogUtil.error(`附件再认证失败，错误信息=${error.message}`)
      DsToastHost.show(this.getUIContext(), $r('app.string.reauthenticate_failed'))
    })
  }

  @LocalBuilder
  private passwordTrailing() {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: this.passwordVisible,
      symbolColor: $r('app.color.ds_text_secondary'),
      accessibilityLabel: this.passwordVisible ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.passwordVisible = !this.passwordVisible,
    })
  }

  @LocalBuilder
  private passwordInput() {
    DsInput({
      text: this.password,
      placeholder: $r('app.string.reauth_password_placeholder'),
      type: InputType.Password,
      showPassword: this.passwordVisible,
      trailingBuilder: this.passwordTrailing,
      onChange: (value: string) => this.password = value,
      onSubmit: () => this.submit(),
    })
  }

  build() {
    DsDialog({
      title: $r('app.string.reauthenticate_title'),
      message: this.message,
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: this.confirmLabel,
      confirmEnabled: this.password.length > 0,
      busy: this.busy,
      contentBuilder: this.passwordInput,
      onCancel: () => this.controller.close(),
      onConfirm: () => this.submit(),
    })
  }
}
