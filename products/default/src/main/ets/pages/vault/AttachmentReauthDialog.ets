import { promptAction } from '@kit.ArkUI'
import { AppToast, ReauthenticationPurpose } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'

// 附件明文离开保险库（导出、预览）前的统一门禁：认证通过后由调用方执行具体动作。
@ComponentV2
export struct AttachmentReauthDialog {
  @Param controller: promptAction.DialogController = new promptAction.DialogController()
  @Require @Param message: ResourceStr
  @Require @Param confirmLabel: ResourceStr
  @Event onAuthenticated: () => void = () => {
  }
  @Local private password: string = ''
  private readonly app: AppViewModel = appViewModel

  private submit(): void {
    if (this.password.length === 0) {
      return
    }
    const password: string = this.password
    this.controller.close()
    this.app.session.reauthenticate(ReauthenticationPurpose.ExportData, password, async () => {
      this.onAuthenticated()
    }).catch((error: Error) => {
      LogUtil.error(`附件再认证失败，错误信息=${error.message}`)
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.reauthenticate_failed'))
    })
  }

  build() {
    Column() {
      Text($r('app.string.reauthenticate_title'))
        .fontSize($r('sys.float.ohos_id_text_size_dialog_tittle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: $r('sys.float.padding_level12'), right: $r('sys.float.padding_level12') })

      Text(this.message)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: $r('sys.float.padding_level4') })
        .padding({ left: $r('sys.float.padding_level12'), right: $r('sys.float.padding_level12') })

      TextInput({ placeholder: $r('app.string.password'), text: this.password })
        .type(InputType.Password)
        .fontSize($r('sys.float.Body_L'))
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .showUnderline(true)
        .underlineColor({ normal: $r('sys.color.comp_divider'), typing: $r('sys.color.brand') })
        .margin({
          top: $r('sys.float.padding_level6'),
          left: $r('sys.float.padding_level12'),
          right: $r('sys.float.padding_level12'),
        })
        .onChange((value: string) => this.password = value)

      Row({ space: $r('sys.float.padding_level2') }) {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
          .onClick(() => this.controller.close())

        Divider()
          .vertical(true)
          .strokeWidth(1)
          .color($r('sys.color.comp_divider'))
          .height($r('sys.float.ohos_id_dialog_divider_height'))

        Button(this.confirmLabel)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
          .onClick(() => this.submit())
      }
      .width('100%')
      .margin({ top: $r('sys.float.padding_level2') })
      .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    }
    .width('100%')
    .padding({ top: $r('sys.float.padding_level6'), bottom: $r('sys.float.padding_level8') })
  }
}
