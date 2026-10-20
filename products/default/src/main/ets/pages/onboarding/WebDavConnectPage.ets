import { HdsNavDestination } from '@kit.UIDesignKit'
import { WebDavProbeErrorCategory } from '@ohos/common'
import { DsButton, DsButtonVariant } from '../../components/DsButton'
import { DsField } from '../../components/DsField'
import { DsInput } from '../../components/DsInput'
import { DsPageHeader } from '../../components/DsPageHeader'
import { appRouter } from '../../navigation/AppRouter'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { WebDavConnectStatus, WebDavConnectViewModel } from '../../viewmodel/WebDavConnectViewModel'

function failureMessage(category: WebDavProbeErrorCategory | undefined): ResourceStr {
  switch (category) {
    case WebDavProbeErrorCategory.InvalidInput:
      return $r('app.string.webdav_error_invalid_input')
    case WebDavProbeErrorCategory.Authentication:
      return $r('app.string.webdav_error_authentication')
    case WebDavProbeErrorCategory.NotFound:
      return $r('app.string.webdav_error_not_found')
    case WebDavProbeErrorCategory.Unsupported:
      return $r('app.string.webdav_error_unsupported')
    case WebDavProbeErrorCategory.Tls:
      return $r('app.string.webdav_error_tls')
    case WebDavProbeErrorCategory.Network:
      return $r('app.string.webdav_error_network')
    case WebDavProbeErrorCategory.Server:
      return $r('app.string.webdav_error_server')
    case WebDavProbeErrorCategory.MissingVersion:
      return $r('app.string.webdav_error_missing_version')
    default:
      return $r('app.string.webdav_error_other')
  }
}

@ComponentV2
export struct WebDavConnectPage {
  @Local private viewModel: WebDavConnectViewModel = new WebDavConnectViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private passwordVisible: boolean = false

  @Computed
  get topInset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx)
  }

  aboutToDisappear(): void {
    this.viewModel.clearSensitive()
  }

  @Builder
  private statusStrip() {
    if (this.viewModel.status === WebDavConnectStatus.Success) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_success')])
        Text($r('app.string.webdav_status_success'))
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_on_success_container'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: $r('app.float.ds_space_sm'), bottom: $r('app.float.ds_space_sm') })
      .padding({ left: $r('app.float.ds_space_md'), right: $r('app.float.ds_space_md') })
      .backgroundColor($r('app.color.ds_success_container'))
    } else if (this.viewModel.status === WebDavConnectStatus.Failure) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_error')])
        Text(failureMessage(this.viewModel.failure))
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_on_error_container'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: $r('app.float.ds_space_sm'), bottom: $r('app.float.ds_space_sm') })
      .padding({ left: $r('app.float.ds_space_md'), right: $r('app.float.ds_space_md') })
      .backgroundColor($r('app.color.ds_error_container'))
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        DsPageHeader({
          title: $r('app.string.webdav_connect_title'),
          subtitle: $r('app.string.webdav_connect_subtitle'),
          showMore: false,
          onBack: () => appRouter.pop(),
        })

        Column({ space: $r('app.float.ds_space_lg') }) {
          DsField({ label: $r('app.string.webdav_server_url'), required: true }) {
            DsInput({
              text: this.viewModel.host,
              placeholder: $r('app.string.text_input_placeholder'),
              prefix: 'https://',
              onChange: (value: string) => this.viewModel.setHost(value),
            })
          }

          DsField({ label: $r('app.string.webdav_username_label'), required: true }) {
            DsInput({
              text: this.viewModel.username,
              placeholder: $r('app.string.text_input_placeholder'),
              onChange: (value: string) => this.viewModel.setUsername(value),
            })
          }

          DsField({ label: $r('app.string.webdav_password_label'), required: true }) {
            DsInput({
              text: this.viewModel.password,
              placeholder: $r('app.string.text_input_placeholder'),
              type: InputType.Password,
              showPassword: this.passwordVisible,
              onChange: (value: string) => this.viewModel.setPassword(value),
            }) {
              SymbolGlyph(this.passwordVisible ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
                .fontSize($r('app.float.ds_icon_sm'))
                .fontColor([$r('app.color.ds_text_tertiary')])
                .onClick(() => this.passwordVisible = !this.passwordVisible)
            }
          }

          DsButton({
            label: this.viewModel.status === WebDavConnectStatus.Testing
              ? $r('app.string.webdav_testing') : $r('app.string.webdav_test_connection'),
            variant: DsButtonVariant.Secondary,
            active: this.viewModel.canTest,
            onTap: () => this.viewModel.test(),
          })

          this.statusStrip()
        }
        .width('100%')
        .padding({
          top: $r('app.float.ds_space_lg'),
          left: $r('app.float.ds_gutter'),
          right: $r('app.float.ds_gutter'),
        })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}

@Builder
export function webDavConnectPageBuilder() {
  WebDavConnectPage()
}
