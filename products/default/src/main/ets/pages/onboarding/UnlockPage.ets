import { HdsNavDestination } from '@kit.UIDesignKit'
import { ResUtil } from '@pura/harmony-utils'
import { AnimationTokens, AppErrorModel, AppToast, DelayedVisibility } from '@ohos/common'
import { ROUTE_UNLOCK } from '../../constants/RouteConstants'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsInput } from '../../components/DsInput'
import { DsLoadingIndicator, DsLoadingIndicatorSize, DsLoadingIndicatorTone } from '../../components/DsLoadingIndicator'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { IconToggleButton } from '../../components/IconToggleButton'

@ComponentV2
export struct UnlockPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private viewModel: AppViewModel = appViewModel
  @Local private password: string = ''
  @Local private passwordVisible: boolean = false
  @Local private bandProgress: number = 0
  @Local private formProgress: number = 0
  @Local private pageHeight: number = 0
  @Local private bandHeight: number = 0
  @Local private entering: boolean = false
  @Local private noticeTone: DsNoticeTone = DsNoticeTone.Error
  @Local private noticeVisible: boolean = false
  @Local private errorBannerOffset: number = AnimationTokens.BANNER_ENTER_OFFSET
  @Local private errorBannerOpacity: number = 0
  @Local private unlockSucceeded: boolean = false
  private exitAnimating: boolean = false
  private enterPending: boolean = false
  // 解锁请求进行中不再叠加 Toast，失败统一由页内提示条呈现。
  private submittingUnlock: boolean = false
  @Local private busyGate: DelayedVisibility = new DelayedVisibility()

  @Monitor('viewModel.busy')
  onBusyChanged(): void {
    this.busyGate.setActive(this.viewModel.busy)
  }

  @Computed
  get bottomSafeAreaHeight(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get topSafeAreaHeight(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx)
  }

  @Computed
  get formHeight(): number {
    return Math.max(this.pageHeight - this.bandHeight, 0)
  }

  @Computed
  get pageOpacity(): number {
    return this.entering ? 1 - this.bandProgress : 1
  }

  @Computed
  get formBottomPadding(): number {
    return this.bottomSafeAreaHeight + this.vpOf($r('app.float.ds_space_lg'))
  }

  @Computed
  get credentialsDisabled(): boolean {
    return this.viewModel.busy || this.unlockSucceeded
  }

  @Computed
  get buttonLabel(): Resource {
    if (this.unlockSucceeded) {
      return $r('app.string.unlock_opening')
    }
    if (this.viewModel.busy) {
      return $r('app.string.unlocking')
    }
    // 缺凭据是本地校验，保留「解锁保险库」；只有鉴权失败才切「重试解锁」。
    if (this.noticeVisible && this.noticeTone === DsNoticeTone.Error) {
      return $r('app.string.unlock_retry')
    }
    return $r('app.string.unlock_vault')
  }

  @Computed
  get buttonTrailingIcon(): Resource {
    if (this.unlockSucceeded) {
      return $r('app.string.symbol_check')
    }
    if (this.noticeVisible && this.noticeTone === DsNoticeTone.Error) {
      return $r('app.string.symbol_refresh')
    }
    return $r('app.string.symbol_lock_open')
  }

  @Computed
  get noticeTitle(): Resource {
    return this.noticeTone === DsNoticeTone.Warning
      ? $r('app.string.unlock_missing_credential_title') : $r('app.string.unlock_failed_title')
  }

  @Computed
  get noticeBody(): Resource {
    return this.noticeTone === DsNoticeTone.Warning
      ? $r('app.string.unlock_missing_credential_body') : $r('app.string.unlock_failed_body')
  }

  @Computed
  get showUpdated(): boolean {
    return this.viewModel.currentModifiedAt() > 0
  }

  private vpOf(value: Resource): number {
    return this.getUIContext().px2vp(ResUtil.getNumber(value.id))
  }

  @Monitor('viewModel.lastError')
  onLastErrorChanged(): void {
    const error: AppErrorModel | undefined = this.viewModel.lastError
    if (error === undefined || this.submittingUnlock) {
      return
    }
    AppToast.show(this.getUIContext(), error.message)
  }

  aboutToAppear(): void {
    if (appRouter.consumeLockEnter()) {
      this.bandProgress = 1
      this.formProgress = 1
      this.entering = true
      this.enterPending = true
    }
  }

  aboutToDisappear(): void {
    this.busyGate.dispose()
  }

  private startEnterIfReady(): void {
    if (!this.enterPending || this.pageHeight <= 0 || this.bandHeight <= 0) {
      return
    }
    this.enterPending = false
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.EASE_ENTER,
      onFinish: () => this.entering = false,
    }, () => {
      this.bandProgress = 0
      this.formProgress = 0
    })
  }

  private async handleSubmit(): Promise<void> {
    if (this.exitAnimating || this.viewModel.busy || this.viewModel.unlockBlocked || this.unlockSucceeded) {
      return
    }
    // 密码与密钥文件都为空时本地拦截：不发解锁请求，只给页内警示。
    if (this.password.length === 0 && this.viewModel.currentKeyFileName().length === 0) {
      this.showNotice(DsNoticeTone.Warning)
      return
    }
    this.dismissNotice()
    this.submittingUnlock = true
    let unlocked: boolean = false
    try {
      unlocked = await this.viewModel.unlockVault(this.password)
    } finally {
      this.submittingUnlock = false
    }
    if (unlocked) {
      // 成功转场优先，不再为最短显示时长保留加载态。
      this.busyGate.hideImmediately()
      this.playExitAnimation()
      return
    }
    if (this.viewModel.lastError !== undefined) {
      this.showNotice(DsNoticeTone.Error)
    }
  }

  private playExitAnimation(): void {
    this.exitAnimating = true
    this.unlockSucceeded = true
    this.getUIContext().getFocusController().clearFocus()
    // 设计稿：成功态停留约 120ms 后再沿灰白交界外移，150ms 为最近动效 Token。
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: AnimationTokens.DURATION_STRUCTURAL,
        curve: AnimationTokens.EASE_ENTER,
      }, () => {
        this.bandProgress = 1
      })
      this.getUIContext().animateTo({
        duration: AnimationTokens.DURATION_STRUCTURAL,
        curve: AnimationTokens.EASE_EXIT,
        onFinish: () => appRouter.restoreAfterUnlock(),
      }, () => {
        this.formProgress = 1
      })
    }, AnimationTokens.DURATION_FAST)
  }

  private chooseKeyFile(): void {
    if (this.credentialsDisabled) {
      return
    }
    this.dismissNotice()
    this.viewModel.chooseKeyFile()
  }

  private clearKeyFile(): void {
    if (this.credentialsDisabled) {
      return
    }
    this.dismissNotice()
    this.viewModel.clearKeyFile()
  }

  private showNotice(tone: DsNoticeTone): void {
    const alreadyVisible: boolean = this.noticeVisible && this.errorBannerOpacity === 1
    this.noticeTone = tone
    this.noticeVisible = true
    if (alreadyVisible) {
      return
    }
    // 提示条常驻但透明，先归位再动画，保证首次出现与退出中途重现都有起始帧。
    this.errorBannerOffset = AnimationTokens.BANNER_ENTER_OFFSET
    this.getUIContext().animateTo({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    }, () => {
      this.errorBannerOffset = 0
      this.errorBannerOpacity = 1
    })
  }

  private dismissNotice(): void {
    this.noticeVisible = false
    if (this.errorBannerOpacity === 0) {
      return
    }
    this.getUIContext().animateTo({
      duration: AnimationTokens.DURATION_FAST,
      curve: AnimationTokens.EASE_EXIT,
    }, () => {
      this.errorBannerOffset = AnimationTokens.BANNER_EXIT_OFFSET
      this.errorBannerOpacity = 0
    })
  }

  @LocalBuilder
  private vaultSwitchButton() {
    DsButton({
      variant: DsButtonVariant.Text,
      buttonSize: DsButtonSize.Medium,
      iconOnly: true,
      leadingIcon: $r('app.string.symbol_swap_horiz'),
      iconSizeOverride: $r('app.float.ds_icon_md'),
      iconColorOverride: $r('app.color.ds_on_surface_variant'),
      accessibilityLabelResource: $r('app.string.choose_another_vault'),
      onTap: () => {
        if (this.credentialsDisabled) {
          return
        }
        this.viewModel.chooseAnotherVault()
      },
    })
  }

  @Builder
  private vaultBand() {
    Column() {
      Row()
        .width('100%')
        .height(this.topSafeAreaHeight)

      Column({ space: $r('app.float.ds_space_lg') }) {
        Row({ space: $r('app.float.ds_space_10') }) {
          Image($r('app.media.launch_icon'))
            .width($r('app.float.ds_logo_size_sm'))
            .height($r('app.float.ds_logo_size_sm'))
            .draggable(false)

          Text($r('app.string.app_brand_name'))
            .fontSize($r('app.float.ds_font_title'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_primary'))

          Blank()

          this.vaultSwitchButton()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: $r('app.float.ds_space_sm') }) {
          Text(this.viewModel.currentSource().displayName)
            .fontSize($r('app.float.ds_font_display'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.showUpdated) {
            Text($r('app.string.unlock_last_updated',
              this.viewModel.formatMinute(this.viewModel.currentModifiedAt())))
              .fontSize($r('app.float.ds_font_label_sm'))
              .fontFamily(PASSWORD_FONT_FAMILY)
              .fontColor($r('app.color.ds_text_tertiary'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        top: $r('app.float.ds_space_28'),
        bottom: $r('app.float.ds_space_26'),
        left: $r('app.float.ds_space_lg'),
        right: $r('app.float.ds_space_lg'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.ds_surface_container'))
    .translate({ y: -this.bandHeight * this.bandProgress })
    .onAreaChange((_old: Area, newArea: Area) => {
      this.bandHeight = newArea.height as number
      this.startEnterIfReady()
    })
  }

  @LocalBuilder
  private passwordLeadingIcon() {
    Row() {
      SymbolGlyph($r('app.string.symbol_lock'))
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([this.unlockSucceeded
          ? $r('app.color.ds_text_disabled') : $r('app.color.ds_text_tertiary')])
        .foregroundColor(this.unlockSucceeded
          ? $r('app.color.ds_text_disabled') : $r('app.color.ds_text_tertiary'))
    }
    .width($r('app.float.ds_input_icon_box_md'))
    .height($r('app.float.ds_input_icon_box_md'))
    .justifyContent(FlexAlign.Center)
  }

  @LocalBuilder
  private passwordTrailing() {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: this.passwordVisible,
      symbolColor: this.unlockSucceeded
        ? $r('app.color.ds_text_disabled') : $r('app.color.ds_on_surface_variant'),
      clickable: !this.credentialsDisabled,
      accessibilityLabel: this.passwordVisible ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.passwordVisible = !this.passwordVisible,
    })
  }

  @LocalBuilder
  private keyFileText() {
    if (this.viewModel.currentKeyFileName().length > 0) {
      Text(this.viewModel.currentKeyFileName())
        .fontSize($r('app.float.ds_font_body'))
        .fontFamily(PASSWORD_FONT_FAMILY)
        .fontWeight(600)
        .fontColor(this.credentialsDisabled
          ? $r('app.color.ds_text_disabled') : $r('app.color.ds_on_surface_variant'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text($r('app.string.unlock_key_file_add'))
        .fontSize($r('app.float.ds_font_body'))
        .fontColor(this.credentialsDisabled
          ? $r('app.color.ds_text_disabled') : $r('app.color.ds_on_surface_variant'))
        .layoutWeight(1)
        .maxLines(1)
    }
  }

  @LocalBuilder
  private keyFileContent() {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph($r('app.string.symbol_key'))
        .fontSize($r('app.float.ds_icon_xs'))
        .fontColor([$r('app.color.ds_on_surface_variant')])
        .foregroundColor($r('app.color.ds_on_surface_variant'))

      this.keyFileText()

      if (this.viewModel.currentKeyFileName().length > 0) {
        Row() {
          SymbolGlyph($r('app.string.symbol_close'))
            .fontSize($r('app.float.ds_icon_sm'))
            .fontColor([$r('app.color.ds_on_surface_variant')])
            .foregroundColor($r('app.color.ds_on_surface_variant'))
        }
        .width($r('app.float.ds_button_small_height'))
        .height($r('app.float.ds_button_small_height'))
        .justifyContent(FlexAlign.Center)
        .accessibilityText($r('app.string.unlock_key_file_remove'))
        .monopolizeEvents(true)
        .onClick(() => this.clearKeyFile())
      } else {
        SymbolGlyph($r('app.string.symbol_add'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_on_surface_variant')])
          .foregroundColor($r('app.color.ds_on_surface_variant'))
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private keyFileRow() {
    DsButton({
      variant: DsButtonVariant.Filled,
      tone: DsButtonTone.Tonal,
      buttonSize: DsButtonSize.Medium,
      fullWidth: true,
      backgroundColorOverride: $r('app.color.ds_surface_inset'),
      controlHeightOverride: $r('app.float.ds_input_height_md'),
      horizontalPaddingOverride: $r('app.float.ds_space_14'),
      disabled: this.credentialsDisabled,
      contentBuilder: this.keyFileContent,
      onTap: () => this.chooseKeyFile(),
    })
  }

  @Builder
  private credentialStack() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      DsInput({
        text: this.password,
        placeholder: $r('app.string.unlock_password_placeholder'),
        type: InputType.Password,
        showPassword: this.passwordVisible,
        disabled: this.credentialsDisabled,
        leadingBuilder: this.passwordLeadingIcon,
        trailingBuilder: this.passwordTrailing,
        onChange: (value: string) => {
          this.password = value
          this.dismissNotice()
        },
      })

      this.keyFileRow()
    }
    .width('100%')
  }

  @LocalBuilder
  private unlockButtonContent() {
    if (this.busyGate.visible) {
      Row({ space: $r('app.float.ds_space_10') }) {
        Text($r('app.string.unlocking'))
          .fontSize($r('app.float.ds_font_title'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_on_primary'))
        DsLoadingIndicator({
          indicatorSize: DsLoadingIndicatorSize.Small,
          tone: DsLoadingIndicatorTone.Inverse,
        })
      }
    } else {
      Text(this.buttonLabel)
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_on_primary'))
        .maxLines(1)
    }
  }

  @Builder
  private unlockButton() {
    DsButton({
      buttonSize: DsButtonSize.Large,
      fullWidth: true,
      trailingIcon: this.busyGate.visible ? undefined : this.buttonTrailingIcon,
      accessibilityLabelResource: this.buttonLabel,
      contentBuilder: this.unlockButtonContent,
      onTap: () => this.handleSubmit(),
    })
  }

  @Builder
  private unlockNotice() {
    DsNotice({
      tone: this.noticeTone,
      title: this.noticeTitle,
      body: this.noticeBody,
    })
  }

  @Builder
  private formZone() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: $r('app.float.ds_space_16') }) {
        Column()
          .width('100%')
          .layoutWeight(1)

        this.credentialStack()
        this.unlockButton()

        Column()
          .width('100%')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({
        top: $r('app.float.ds_space_24'),
        bottom: this.formBottomPadding,
        left: $r('app.float.ds_space_lg'),
        right: $r('app.float.ds_space_lg'),
      })

      Column() {
        this.unlockNotice()
      }
      .width('100%')
      .padding({
        left: $r('app.float.ds_space_lg'),
        right: $r('app.float.ds_space_lg'),
      })
      .margin({ bottom: this.formBottomPadding })
      .translate({ y: this.errorBannerOffset })
      .opacity(this.errorBannerOpacity)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel(this.errorBannerOpacity > 0 ? 'yes' : 'no')
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .translate({ y: this.formHeight * this.formProgress })
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Column() {
          this.vaultBand()
          this.formZone()
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .opacity(this.pageOpacity)
      .onAreaChange((_old: Area, newArea: Area) => {
        this.pageHeight = newArea.height as number
        this.startEnterIfReady()
      })
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_UNLOCK)
      return true
    })
  }
}

@Builder
export function unlockPageBuilder() {
  UnlockPage()
}
