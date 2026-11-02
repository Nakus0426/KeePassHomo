import { UIUtils } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { AnimationTokens, WebDavEntry, WebDavProbeErrorCategory } from '@ohos/common'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsField } from '../../components/DsField'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { DsLoadingIndicator, DsLoadingIndicatorSize, DsLoadingIndicatorTone } from '../../components/DsLoadingIndicator'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsPageHeader } from '../../components/DsPageHeader'
import { dsNavPageTitleBarOptions } from '../../components/DsPageTitleBar'
import { DsTabs, DsTabsItem } from '../../components/DsTabs'
import { IconToggleButton } from '../../components/IconToggleButton'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import {
  WebDavConnectStatus,
  WebDavConnectViewModel,
  WebDavListStatus,
  WebDavStep,
  WebDavUnlockFailure,
} from '../../viewmodel/WebDavConnectViewModel'

// 起始帧必须独立渲染一帧才能成为动画起点：与 animateTo 写在同一帧时起点会被同步刷新吃掉。
const TAB_TRANSITION_START_FRAME_DELAY: number = 16
// 页签内容横移取外层稳定容器宽度的比例，不读 Tabs 自身宽度，避免转场时宽度被污染。
const TAB_TRANSITION_OFFSET_RATIO: number = 0.2

// 提示条在表单内就地出现/消失：轻微位移 + 淡入淡出，避免高度插入显得生硬。
const NOTICE_TRANSITION: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: AnimationTokens.BANNER_ENTER_OFFSET }))
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }),
  TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: AnimationTokens.BANNER_EXIT_OFFSET }))
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }),
)

@ComponentV2
export struct WebDavConnectPage {
  @Local private viewModel: WebDavConnectViewModel = new WebDavConnectViewModel()
  private readonly app: AppViewModel = appViewModel
  @Local private passwordVisible: boolean = false
  @Local private bottomBarHeight: number = 0
  @Local private contentWidth: number = 0
  @Local private tabOpacity: number[] = [1, 0, 0]
  @Local private tabOffsetX: number[] = [0, 0, 0]
  @Local private tabZIndex: number[] = [1, 0, 0]
  private readonly stepTabsController: TabsController = new TabsController()
  private startFrameTimer: number = -1

  @Monitor('viewModel.step')
  onStepChanged(): void {
    // 页签下标只由 step 驱动；Tabs 不绑定 index，避免重渲染打断转场。
    this.stepTabsController.changeIndex(this.viewModel.step)
  }

  @Computed
  get pageTitle(): Resource {
    switch (this.viewModel.step) {
      case WebDavStep.File:
        return $r('app.string.webdav_step_file')
      case WebDavStep.Unlock:
        return $r('app.string.webdav_step_unlock')
      default:
        return $r('app.string.webdav_connect_title')
    }
  }

  @Computed
  get tabsItems(): DsTabsItem[] {
    return [
      { label: $r('app.string.webdav_connect_title') },
      { label: $r('app.string.webdav_step_file') },
      { label: $r('app.string.webdav_step_unlock') },
    ]
  }

  @Computed
  get serverFieldTone(): DsInputTone {
    if (this.viewModel.connectStatus !== WebDavConnectStatus.Failed) {
      return DsInputTone.Default
    }
    switch (this.viewModel.connectFailure) {
      case WebDavProbeErrorCategory.Authentication:
      case WebDavProbeErrorCategory.Tls:
        return DsInputTone.Default
      default:
        return DsInputTone.Error
    }
  }

  @Computed
  get passwordFieldTone(): DsInputTone {
    return this.viewModel.connectStatus === WebDavConnectStatus.Failed
      && this.viewModel.connectFailure === WebDavProbeErrorCategory.Authentication
      ? DsInputTone.Error : DsInputTone.Default
  }

  @Computed
  get connectNoticeTone(): DsNoticeTone {
    return this.viewModel.connectFailure === WebDavProbeErrorCategory.Tls
      ? DsNoticeTone.Warning : DsNoticeTone.Error
  }

  @Computed
  get connectNoticeTitle(): Resource {
    return this.viewModel.connectFailure === WebDavProbeErrorCategory.Tls
      ? $r('app.string.webdav_cert_error_title') : $r('app.string.webdav_server_error_title')
  }

  @Computed
  get connectNoticeBody(): Resource {
    return this.viewModel.connectFailure === WebDavProbeErrorCategory.Tls
      ? $r('app.string.webdav_cert_error_body') : $r('app.string.webdav_server_error_body')
  }

  @Computed
  get unlockNoticeTitle(): Resource {
    return this.viewModel.unlockFailure === WebDavUnlockFailure.Network
      ? $r('app.string.webdav_server_error_title') : $r('app.string.webdav_unlock_error_title')
  }

  @Computed
  get unlockNoticeBody(): Resource {
    return this.viewModel.unlockFailure === WebDavUnlockFailure.Network
      ? $r('app.string.webdav_server_error_body') : $r('app.string.webdav_unlock_error_body')
  }

  @Computed
  get hasCredential(): boolean {
    return this.viewModel.masterPassword.length > 0 || this.app.currentKeyFileName().length > 0
  }

  aboutToDisappear(): void {
    clearTimeout(this.startFrameTimer)
    this.viewModel.clearSensitive()
  }

  private get tabTransitionOffset(): number {
    return this.contentWidth * TAB_TRANSITION_OFFSET_RATIO
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    if (from === to) {
      return {
        timeout: 0,
        transition: (proxy: TabContentTransitionProxy) => proxy.finishTransition(),
      }
    }
    const direction: number = to > from ? 1 : -1
    const offset: number = this.tabTransitionOffset
    return {
      timeout: TAB_TRANSITION_START_FRAME_DELAY + AnimationTokens.STATE_TRANSITION_DURATION + 100,
      transition: (proxy: TabContentTransitionProxy) => {
        UIUtils.applySync(() => {
          this.tabOpacity[from] = 1
          this.tabOffsetX[from] = 0
          this.tabOpacity[to] = 0
          this.tabOffsetX[to] = direction * offset
          this.tabZIndex[from] = 0
          this.tabZIndex[to] = 1
        })
        this.startFrameTimer = setTimeout(() => {
          this.getUIContext().animateTo({
            duration: AnimationTokens.STATE_TRANSITION_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
            onFinish: () => proxy.finishTransition(),
          }, () => {
            this.tabOpacity[from] = 0
            this.tabOffsetX[from] = -direction * offset
            this.tabOpacity[to] = 1
            this.tabOffsetX[to] = 0
          })
        }, TAB_TRANSITION_START_FRAME_DELAY)
      },
    }
  }

  @Builder
  private pageHeaderBuilder() {
    DsPageHeader({
      title: this.pageTitle,
      showBack: true,
      onBack: () => {
        if (this.viewModel.opening) {
          return
        }
        if (!this.viewModel.backStep()) {
          appRouter.pop()
        }
      },
    })
  }

  @Builder
  private tabsBuilder() {
    DsTabs({
      items: this.tabsItems,
      selectedIndex: this.viewModel.step,
      disabled: true,
      onSelect: (index: number) => this.viewModel.goToStep(index),
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
  private serverUrlInput() {
    DsInput({
      text: this.viewModel.host,
      placeholder: $r('app.string.webdav_server_placeholder'),
      prefix: 'https://',
      tone: this.serverFieldTone,
      onChange: (value: string) => this.viewModel.setHost(value),
    })
  }

  @Builder
  private usernameInput() {
    DsInput({
      text: this.viewModel.username,
      placeholder: $r('app.string.text_input_placeholder'),
      onChange: (value: string) => this.viewModel.setUsername(value),
    })
  }

  @Builder
  private passwordInput() {
    DsInput({
      text: this.viewModel.password,
      placeholder: $r('app.string.text_input_placeholder'),
      type: InputType.Password,
      showPassword: this.passwordVisible,
      tone: this.passwordFieldTone,
      trailingBuilder: this.passwordToggle,
      onChange: (value: string) => this.viewModel.setPassword(value),
    })
  }

  @LocalBuilder
  private testButtonContent() {
    if (this.viewModel.isTesting) {
      Row({ space: $r('app.float.ds_space_xs') }) {
        DsLoadingIndicator({
          indicatorSize: DsLoadingIndicatorSize.Small,
          tone: DsLoadingIndicatorTone.Surface,
        })
        Text($r('app.string.webdav_testing'))
          .fontSize($r('app.float.ds_font_title'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
      }
    } else {
      Text($r('app.string.webdav_test_connection'))
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
    }
  }

  @Builder
  private connectionNotice() {
    if (this.viewModel.connectStatus === WebDavConnectStatus.Ready) {
      Column() {
        DsNotice({
          tone: DsNoticeTone.Success,
          title: $r('app.string.webdav_status_success'),
          body: $r('app.string.webdav_status_success_body'),
        })
      }
      .width('100%')
      .transition(NOTICE_TRANSITION)
    } else if (this.viewModel.connectStatus === WebDavConnectStatus.Failed) {
      Column() {
        DsNotice({
          tone: this.connectNoticeTone,
          title: this.connectNoticeTitle,
          body: this.connectNoticeBody,
        })
      }
      .width('100%')
      .transition(NOTICE_TRANSITION)
    }
  }

  @Builder
  private serverStep() {
    Column({ space: $r('app.float.ds_space_lg') }) {
      DsField({
        label: $r('app.string.webdav_server_url'),
        required: true,
        contentBuilder: () => {
          this.serverUrlInput()
        },
      })
      DsField({
        label: $r('app.string.webdav_username_label'),
        required: true,
        contentBuilder: () => {
          this.usernameInput()
        },
      })
      DsField({
        label: $r('app.string.webdav_password_label'),
        required: true,
        contentBuilder: () => {
          this.passwordInput()
        },
      })
      DsButton({
        tone: DsButtonTone.Default,
        buttonSize: DsButtonSize.Medium,
        fullWidth: true,
        disabled: !this.viewModel.canTest,
        contentBuilder: this.testButtonContent,
        onTap: () => {
          this.viewModel.testConnection()
        },
      })
      this.connectionNotice()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private directoryBar() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      DsButton({
        variant: DsButtonVariant.Text,
        buttonSize: DsButtonSize.Small,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_chevron_up'),
        iconSizeOverride: $r('app.float.ds_icon_sm'),
        iconColorOverride: $r('app.color.ds_on_surface_variant'),
        disabled: !this.viewModel.canGoUp || this.viewModel.listStatus === WebDavListStatus.Loading,
        accessibilityLabelResource: $r('app.string.webdav_up'),
        onTap: () => {
          this.viewModel.goUp()
        },
      })
      Text(this.viewModel.displayPath)
        .layoutWeight(1)
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_on_surface_variant'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      DsButton({
        variant: DsButtonVariant.Text,
        buttonSize: DsButtonSize.Small,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_refresh'),
        iconSizeOverride: $r('app.float.ds_icon_sm'),
        iconColorOverride: $r('app.color.ds_on_surface_variant'),
        disabled: this.viewModel.listStatus === WebDavListStatus.Loading,
        accessibilityLabelResource: $r('app.string.webdav_refresh'),
        onTap: () => {
          this.viewModel.refresh()
        },
      })
    }
    .width('100%')
    .height($r('app.float.ds_button_height'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private fileRow(entry: WebDavEntry) {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph(this.fileIcon(entry))
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([this.fileIconColor(entry)])
        .foregroundColor(this.fileIconColor(entry))
      Column({ space: $r('app.float.ds_space_2') }) {
        Text(entry.name)
          .width('100%')
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(600)
          .fontColor(this.fileTextColor(entry))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(entry.isCollection ? $r('app.string.webdav_folder') : this.viewModel.fileMeta(entry))
          .width('100%')
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor($r('app.color.ds_text_tertiary'))
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (entry.isCollection) {
        SymbolGlyph($r('app.string.symbol_chevron_right'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_on_surface_variant')])
          .foregroundColor($r('app.color.ds_on_surface_variant'))
      } else if (this.isKdbx(entry)) {
        SymbolGlyph(this.isSelected(entry)
          ? $r('app.string.symbol_radio_selected') : $r('app.string.symbol_radio_unselected'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([this.isSelected(entry) ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_tertiary')])
          .foregroundColor(this.isSelected(entry)
            ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_tertiary'))
      }
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_space_16'),
      right: $r('app.float.ds_space_16'),
    })
    .backgroundColor(this.isSelected(entry) ? $r('app.color.ds_surface_high') : $r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .onClick(() => {
      if (entry.isCollection) {
        this.viewModel.enterFolder(entry)
      } else if (this.isKdbx(entry)) {
        this.viewModel.selectFile(entry)
      }
    })
  }

  @Builder
  private fileStep() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      this.directoryBar()
      if (this.viewModel.listStatus === WebDavListStatus.Loading) {
        Column() {
          DsLoadingIndicator({
            indicatorSize: DsLoadingIndicatorSize.Medium,
            tone: DsLoadingIndicatorTone.Surface,
          })
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.entries.length === 0) {
        Text($r('app.string.webdav_empty_directory'))
          .width('100%')
          .fontSize($r('app.float.ds_font_body'))
          .fontColor($r('app.color.ds_text_tertiary'))
          .padding({ top: $r('app.float.ds_space_xl') })
      } else {
        ForEach(this.viewModel.entries, (entry: WebDavEntry) => {
          this.fileRow(entry)
        }, (entry: WebDavEntry) => entry.url)
      }
      if (this.viewModel.listStatus === WebDavListStatus.Failed) {
        Column() {
          DsNotice({
            tone: this.viewModel.listFailure === WebDavProbeErrorCategory.Tls
              ? DsNoticeTone.Warning : DsNoticeTone.Error,
            title: this.viewModel.listFailure === WebDavProbeErrorCategory.Tls
              ? $r('app.string.webdav_cert_error_title') : $r('app.string.webdav_server_error_title'),
            body: this.viewModel.listFailure === WebDavProbeErrorCategory.Tls
              ? $r('app.string.webdav_cert_error_body') : $r('app.string.webdav_server_error_body'),
          })
        }
        .width('100%')
        .transition(NOTICE_TRANSITION)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private masterPasswordToggle() {
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
  private masterPasswordInput() {
    DsInput({
      text: this.viewModel.masterPassword,
      placeholder: $r('app.string.unlock_password_placeholder'),
      type: InputType.Password,
      showPassword: this.passwordVisible,
      trailingBuilder: this.masterPasswordToggle,
      onChange: (value: string) => this.viewModel.setMasterPassword(value),
    })
  }

  @Builder
  private vaultSummary() {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph($r('app.string.symbol_description'))
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([$r('app.color.ds_text_tertiary')])
        .foregroundColor($r('app.color.ds_text_tertiary'))
      Text(this.viewModel.selected?.name ?? '')
        .layoutWeight(1)
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.viewModel.vaultFileSize())
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
    }
    .width('100%')
    .padding($r('app.float.ds_space_16'))
    .backgroundColor($r('app.color.ds_surface_container'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private keyFileRow() {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph($r('app.string.symbol_key'))
        .fontSize($r('app.float.ds_icon_xs'))
        .fontColor([$r('app.color.ds_on_surface_variant')])
        .foregroundColor($r('app.color.ds_on_surface_variant'))
      Column({ space: $r('app.float.ds_space_2') }) {
        Text($r('app.string.webdav_key_file_label'))
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
        Text(this.app.currentKeyFileName().length > 0
          ? this.app.currentKeyFileName() : $r('app.string.webdav_key_file_none'))
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor($r('app.color.ds_text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.app.currentKeyFileName().length > 0) {
        DsButton({
          variant: DsButtonVariant.Text,
          tone: DsButtonTone.Error,
          buttonSize: DsButtonSize.Small,
          label: $r('app.string.webdav_key_file_remove'),
          onTap: () => {
            this.app.clearKeyFile()
          },
        })
      }
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Tonal,
        buttonSize: DsButtonSize.Small,
        label: this.app.currentKeyFileName().length > 0
          ? $r('app.string.webdav_key_file_change') : $r('app.string.webdav_key_file_add'),
        onTap: () => {
          this.app.chooseKeyFile()
        },
      })
    }
    .width('100%')
    .padding($r('app.float.ds_space_16'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private unlockNotice() {
    if (this.viewModel.unlockFailure !== WebDavUnlockFailure.None) {
      Column() {
        DsNotice({
          tone: DsNoticeTone.Error,
          title: this.unlockNoticeTitle,
          body: this.unlockNoticeBody,
        })
      }
      .width('100%')
      .transition(NOTICE_TRANSITION)
    }
  }

  @Builder
  private unlockStep() {
    Column({ space: $r('app.float.ds_space_lg') }) {
      this.vaultSummary()
      DsField({
        label: $r('app.string.master_password'),
        contentBuilder: () => {
          this.masterPasswordInput()
        },
      })
      this.keyFileRow()
      Text($r('app.string.webdav_credential_hint'))
        .width('100%')
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
      Text($r('app.string.webdav_read_only_hint'))
        .width('100%')
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
      this.unlockNotice()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private openButtonContent() {
    if (this.viewModel.opening) {
      Row({ space: $r('app.float.ds_space_xs') }) {
        DsLoadingIndicator({
          indicatorSize: DsLoadingIndicatorSize.Small,
          tone: DsLoadingIndicatorTone.Inverse,
        })
        Text($r('app.string.unlocking'))
          .fontSize($r('app.float.ds_font_title'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_on_primary'))
      }
    } else {
      Text($r('app.string.webdav_open_vault'))
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_on_primary'))
    }
  }

  @Builder
  private bottomActionContent() {
    if (this.viewModel.step === WebDavStep.Server) {
      DsButton({
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        trailingIcon: $r('app.string.symbol_arrow_forward'),
        label: $r('app.string.webdav_next'),
        disabled: !this.viewModel.canGoNextFromServer,
        onTap: () => {
          this.viewModel.nextFromServer()
        },
      })
    } else if (this.viewModel.step === WebDavStep.File) {
      DsButton({
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        trailingIcon: $r('app.string.symbol_arrow_forward'),
        label: $r('app.string.webdav_next'),
        disabled: !this.viewModel.canGoNextFromFile || this.viewModel.listStatus === WebDavListStatus.Loading,
        onTap: () => {
          this.viewModel.nextFromFile()
        },
      })
    } else {
      DsButton({
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        disabled: this.viewModel.opening || !this.hasCredential,
        contentBuilder: this.openButtonContent,
        onTap: () => {
          this.viewModel.openVault()
        },
      })
    }
  }

  @Builder
  private bottomPanel() {
    DsBottomActionBar({
      onHeightChange: (height: number) => {
        this.bottomBarHeight = height
      },
      contentBuilder: () => {
        this.bottomActionContent()
      },
    })
  }

  @Builder
  private stepPanel(step: number) {
    if (step === WebDavStep.Server) {
      this.serverStep()
    } else if (step === WebDavStep.File) {
      this.fileStep()
    } else {
      this.unlockStep()
    }
  }

  @Builder
  private stepTabContent(step: number) {
    TabContent() {
      Column() {
        this.stepPanel(step)
      }
      .width('100%')
      .translate({ x: this.tabOffsetX[step] })
    }
    .align(Alignment.Top)
    .opacity(this.tabOpacity[step])
    .zIndex(this.tabZIndex[step])
    .clip(true)
  }

  @Builder
  private stepTabs() {
    Tabs({ barPosition: BarPosition.Start, controller: this.stepTabsController }) {
      this.stepTabContent(WebDavStep.Server)
      this.stepTabContent(WebDavStep.File)
      this.stepTabContent(WebDavStep.Unlock)
    }
    .width('100%')
    .height('auto')
    .scrollable(false)
    .barHeight(0)
    .divider(null)
    .customContentTransition((from: number, to: number) => this.tabContentTransition(from, to))
    .clip(true)
  }

  private fileIcon(entry: WebDavEntry): Resource {
    if (entry.isCollection) {
      return $r('app.string.symbol_folder')
    }
    if (this.isKdbx(entry)) {
      return $r('app.string.symbol_description')
    }
    return $r('app.string.symbol_key')
  }

  private fileIconColor(entry: WebDavEntry): ResourceColor {
    if (entry.isCollection) {
      return $r('app.color.ds_on_surface_variant')
    }
    return this.isKdbx(entry) ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_tertiary')
  }

  private fileTextColor(entry: WebDavEntry): ResourceColor {
    return entry.isCollection || this.isKdbx(entry)
      ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_tertiary')
  }

  private isKdbx(entry: WebDavEntry): boolean {
    return !entry.isCollection && entry.name.toLowerCase().endsWith('.kdbx')
  }

  private isSelected(entry: WebDavEntry): boolean {
    return this.viewModel.selected !== undefined && this.viewModel.selected.url === entry.url
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column() {
            this.stepTabs()
          }
          .width('100%')
          .padding({
            top: $r('app.float.ds_space_lg'),
            bottom: this.bottomBarHeight,
            left: $r('app.float.ds_gutter'),
            right: $r('app.float.ds_gutter'),
          })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(false)
        .align(Alignment.Top)
        .onAreaChange((_old: Area, newArea: Area) => {
          this.contentWidth = newArea.width as number
        })

        this.bottomPanel()
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(dsNavPageTitleBarOptions(
      (): void => this.pageHeaderBuilder(),
      (): void => this.tabsBuilder()))
    .hideBackButton(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}

@Builder
export function webDavConnectPageBuilder() {
  WebDavConnectPage()
}
