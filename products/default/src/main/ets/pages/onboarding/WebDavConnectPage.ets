import { HdsNavDestination } from '@kit.UIDesignKit'
import { WebDavProbeErrorCategory } from '@ohos/common'
import { DsButton, DsButtonTone } from '../../components/DsButton'
import { DsField } from '../../components/DsField'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { DsPageHeader } from '../../components/DsPageHeader'
import { IconToggleButton } from '../../components/IconToggleButton'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { dsNavPageTitleBarOptions } from '../../components/DsPageTitleBar'
import { appRouter } from '../../navigation/AppRouter'
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
  @Local private passwordVisible: boolean = false

  @Computed
  private get serverFieldTone(): DsInputTone {
    if (this.viewModel.status !== WebDavConnectStatus.Failure) {
      return DsInputTone.Default
    }
    switch (this.viewModel.failure) {
      // 认证失败与证书问题标在密码/证书，不把服务器地址标红
      case WebDavProbeErrorCategory.Authentication:
      case WebDavProbeErrorCategory.Tls:
        return DsInputTone.Default
      default:
        return DsInputTone.Error
    }
  }

  aboutToDisappear(): void {
    this.viewModel.clearSensitive()
  }

  @Builder
  private pageHeaderBuilder() {
    DsPageHeader({
      title: $r('app.string.webdav_connect_title'),
      showBack: true,
      onBack: () => appRouter.pop(),
    })
  }

  @Builder
  private statusStrip() {
    if (this.viewModel.status === WebDavConnectStatus.Success) {
      DsNotice({
        tone: DsNoticeTone.Success,
        title: $r('app.string.webdav_status_success'),
        body: $r('app.string.webdav_status_success_body'),
      })
    } else if (this.viewModel.status === WebDavConnectStatus.Failure) {
      DsNotice({
        tone: DsNoticeTone.Error,
        title: $r('app.string.webdav_status_failure_title'),
        body: failureMessage(this.viewModel.failure),
      })
    }
  }

  @Builder
  private serverUrlContent() {
    DsInput({
      text: this.viewModel.host,
      placeholder: $r('app.string.text_input_placeholder'),
      prefix: 'https://',
      tone: this.serverFieldTone,
      onChange: (value: string) => this.viewModel.setHost(value),
    })
  }

  @Builder
  private usernameContent() {
    DsInput({
      text: this.viewModel.username,
      placeholder: $r('app.string.text_input_placeholder'),
      onChange: (value: string) => this.viewModel.setUsername(value),
    })
  }

  @LocalBuilder
  private passwordToggle() {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: this.passwordVisible,
      symbolColor: $r('app.color.ds_on_surface_variant'),
      boxSize: $r('app.float.ds_input_icon_box_md'),
      iconSizeOverride: $r('app.float.ds_input_icon_size_md'),
      accessibilityLabel: this.passwordVisible ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.passwordVisible = !this.passwordVisible,
    })
  }

  @Builder
  private passwordContent() {
    DsInput({
      text: this.viewModel.password,
      placeholder: $r('app.string.text_input_placeholder'),
      type: InputType.Password,
      showPassword: this.passwordVisible,
      trailingBuilder: this.passwordToggle,
      onChange: (value: string) => this.viewModel.setPassword(value),
    })
  }

  build() {
    HdsNavDestination() {
      Column({ space: $r('app.float.ds_space_lg') }) {
        DsField({
          label: $r('app.string.webdav_server_url'),
          required: true,
          contentBuilder: () => {
            this.serverUrlContent()
          },
        })

        DsField({
          label: $r('app.string.webdav_username_label'),
          required: true,
          contentBuilder: () => {
            this.usernameContent()
          },
        })

        DsField({
          label: $r('app.string.webdav_password_label'),
          required: true,
          contentBuilder: () => {
            this.passwordContent()
          },
        })

        DsButton({
          label: this.viewModel.status === WebDavConnectStatus.Testing
            ? $r('app.string.webdav_testing') : $r('app.string.webdav_test_connection'),
          tone: DsButtonTone.Default,
          fullWidth: true,
          disabled: !this.viewModel.canTest,
          onTap: () => this.viewModel.test(),
        })

        this.statusStrip()
      }
      .width('100%')
      .height('100%')
      .padding({
        top: $r('app.float.ds_space_lg'),
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .titleBar(dsNavPageTitleBarOptions((): void => this.pageHeaderBuilder()))
    .hideBackButton(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}

@Builder
export function webDavConnectPageBuilder() {
  WebDavConnectPage()
}


