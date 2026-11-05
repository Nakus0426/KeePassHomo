import { LengthMetrics } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { AnimationTokens, ContentSlideTransition, SlideFrame, VaultAuthMode } from '@ohos/common'
import { DateUtil, ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { CreateVaultViewModel } from '../../viewmodel/CreateVaultViewModel'
import { GeneratorContent, GeneratorContentController } from '../generator/GeneratorComponents'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsField } from '../../components/DsField'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { DsPageHeader, DsPageHeaderAction } from '../../components/DsPageHeader'
import { IconToggleButton } from '../../components/IconToggleButton'
import { dsNavPageTitleBarOptions } from '../../components/DsPageTitleBar'
import { DsSegmentedSwitch, DsSegmentedSwitchItem, DsSegmentedSwitchSlot } from '../../components/DsSegmentedSwitch'
import { DsStrengthMeter } from '../../components/DsStrengthMeter'
import { Status } from '../../components/FormItem'
import { appRouter } from '../../navigation/AppRouter'

const AUTH_MODES: DsSegmentedSwitchItem[] = [
  { label: $r('app.string.auth_mode_password_and_key'), enabled: true },
  { label: $r('app.string.auth_mode_password_only'), enabled: true },
  { label: $r('app.string.auth_mode_key_only'), enabled: true },
]

// 分段项下标与鉴权模式一一对应，顺序变更需同步 AUTH_MODES。
const AUTH_MODE_SEQUENCE: VaultAuthMode[] = [
  VaultAuthMode.PasswordAndKey,
  VaultAuthMode.PasswordOnly,
  VaultAuthMode.KeyOnly,
]

const KEY_FILE_SUFFIX: string = '.keyx'
// 设计稿 12fp 正文行高 1.4。
const KEY_FILE_DESCRIPTION_LINE_HEIGHT: number = 17
// 页签内容按自己的下标决定显示哪些凭据字段，不能读当前鉴权方式：Tabs 会预渲染离屏页签。
const PASSWORD_ONLY_INDEX: number = AUTH_MODE_SEQUENCE.indexOf(VaultAuthMode.PasswordOnly)
const KEY_ONLY_INDEX: number = AUTH_MODE_SEQUENCE.indexOf(VaultAuthMode.KeyOnly)

// 未绑定与已绑定是就地换内容：不做位移与缩放，暗示方向或进出场都会失真。
const KEY_FILE_STATE_TRANSITION: TransitionEffect = TransitionEffect.OPACITY
  .animation({
    duration: AnimationTokens.STATE_TRANSITION_DURATION,
    curve: AnimationTokens.STATE_TRANSITION_CURVE,
  })

@ComponentV2
export struct CreateVaultPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private form: CreateVaultViewModel = new CreateVaultViewModel()
  @Local private submitted: boolean = false
  @Local private masterPasswordVisible: boolean = false
  @Local private confirmPasswordVisible: boolean = false
  // 悬浮操作区随底部安全区变化，实测高度用于滚动内容避让。
  @Local private bottomPanelHeight: number = 0
  // 页签由 tabsController.changeIndex 驱动，不绑定 Tabs.index：绑定后重渲染会按旧值再跳一次，
  // 而自定义切换动画不支持打断，转场会被取消且此后不再触发。
  @Local private tabContentWidth: number = 0
  // 直接持有数组，V2 才能观测逐项写入；SlideFrame 仅作传参视图。
  @Local private stepOpacity: number[] = [1, 0, 0]
  @Local private stepOffsetX: number[] = [0, 0, 0]
  @Local private stepZIndex: number[] = [1, 0, 0]
  private readonly tabsController: TabsController = new TabsController()
  @Local private generatorSheetVisible: boolean = false
  @Local private generatorBottomBarHeight: number = 0
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
  private readonly generatorScroller: Scroller = new Scroller()

  @Computed
  get keyFileBound(): boolean {
    return this.viewModel.currentKeyFileUri().length > 0
  }

  @Computed
  get keyFileName(): string {
    return this.viewModel.currentKeyFileName()
  }

  @Computed
  get keyFileInvalid(): boolean {
    return this.submitted && this.form.needsKeyFile && !this.keyFileBound
  }

  @Computed
  get authModeIndex(): number {
    return AUTH_MODE_SEQUENCE.indexOf(this.form.authMode)
  }

  private openGenerator(): void {
    this.viewModel.prepareGenerator()
    this.generatorSheetVisible = true
  }

  private closeGenerator(): void {
    this.generatorSheetVisible = false
    this.viewModel.generator.clearSensitiveState()
  }

  // 主密码与二次确认同源，二者一起回填，避免用户再手抄一遍。
  private fillPasswordFromGenerator(): void {
    const password: string = this.generatorController.getCurrentPassword()
    if (password.length === 0) {
      return
    }
    this.form.setMasterPassword(password)
    this.form.setConfirmPassword(password)
    this.form.masterPasswordController.validate(password)
    this.form.confirmPasswordController.validate(password)
    this.closeGenerator()
  }

  private stepFrame(): SlideFrame {
    return { opacity: this.stepOpacity, offsetX: this.stepOffsetX, zIndex: this.stepZIndex }
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    return ContentSlideTransition.tabTransition(this.getUIContext(), this.stepFrame(), from, to, this.tabContentWidth)
  }

  // 只写鉴权方式：页签切换由 changeIndex 在同一处发起，不额外维护页签下标。
  private selectAuthMode(index: number): void {
    // 切换即清掉上一方式的校验反馈；输入与密钥文件绑定保留。
    this.submitted = false
    this.form.setAuthMode(AUTH_MODE_SEQUENCE[index])
    this.tabsController.changeIndex(index)
  }

  @Computed
  get keyFileFingerprintText(): string {
    return ResUtil.getStringSync($r('app.string.key_file_fingerprint'))
      .replace('%s', this.viewModel.currentKeyFileFingerprint())
  }

  @Computed
  get keyFileSizeText(): string {
    return ResUtil.getStringSync($r('app.string.key_file_size'))
      .replace('%s', this.viewModel.formatSize(this.viewModel.currentKeyFileSize()))
  }

  private errorOf(controllerMessage: ResourceStr, invalid: boolean): ResourceStr | undefined {
    return this.submitted && invalid ? controllerMessage : undefined
  }

  private masterPasswordFeedback(): ResourceStr | undefined {
    if (!this.form.needsPassword) {
      return undefined
    }
    if (this.form.masterPasswordController.status === Status.Invalid) {
      return this.errorOf(this.form.masterPasswordController.message, true)
    }
    return this.errorOf(this.form.confirmPasswordController.message,
      this.form.confirmPasswordController.status === Status.Invalid)
  }
  private handleSubmit(): void {
    this.submitted = true
    if (this.form.validate(this.keyFileBound)) {
      this.viewModel.createVault(this.form.vaultName, this.form.masterPassword, this.form.authMode)
    }
  }

  @Builder
  private vaultNameContent() {
    DsInput({
      text: this.form.vaultName,
      placeholder: $r('app.string.text_input_placeholder'),
      suffix: $r('app.string.kdbx_suffix'),
      tone: this.submitted && this.form.vaultNameController.status === Status.Invalid
        ? DsInputTone.Error : DsInputTone.Default,
      onChange: (value: string) => {
        this.form.setVaultName(value)
        if (this.submitted) {
          this.form.vaultNameController.validate(value)
        }
      },
    })
  }

  @Builder
  private vaultNameField() {
    DsField({
      label: $r('app.string.vault_name'),
      required: true,
      feedback: this.errorOf(this.form.vaultNameController.message,
        this.form.vaultNameController.status === Status.Invalid),
      reserveFeedbackSpace: true,
      contentBuilder: () => {
        this.vaultNameContent()
      },
    })
  }

  // 跨组件传给 @BuilderParam 用箭头函数包裹，this 仍指向本页。
  @Builder
  private authModeSlot(slot: DsSegmentedSwitchSlot) {
    Text(AUTH_MODES[slot.index].label)
      .fontSize($r('app.float.ds_seg_font_size'))
      .fontWeight(600)
      .fontColor(slot.covered ? $r('app.color.ds_on_primary') : $r('app.color.ds_on_surface_variant'))
      .maxLines(1)
  }

  @Builder
  private authModeContent() {
    DsSegmentedSwitch({
      items: AUTH_MODES,
      selectedIndex: this.authModeIndex,
      slotBuilder: (slot: DsSegmentedSwitchSlot) => {
        this.authModeSlot(slot)
      },
      onSelect: (index: number) => this.selectAuthMode(index),
    })
  }

  @Builder
  private authModeField() {
    DsField({
      label: $r('app.string.vault_auth_mode'),
      required: true,
      contentBuilder: () => {
        this.authModeContent()
      },
    })
  }

  @LocalBuilder
  private authTabContent(index: number) {
    TabContent() {
      Column({ space: $r('app.float.ds_space_xl') }) {
        if (index !== KEY_ONLY_INDEX) {
          this.masterPasswordField()
        }
        if (index !== PASSWORD_ONLY_INDEX) {
          this.keyFileField()
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      // 位移必须落在页签内容上：TabContent 只承担透明度与层级。
      .translate({ x: this.stepOffsetX[index] })
    }
    .align(Alignment.Top)
    .opacity(this.stepOpacity[index])
    .zIndex(this.stepZIndex[index])
    .clip(true)
  }

  @LocalBuilder
  private masterPasswordToggle() {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: this.masterPasswordVisible,
      symbolColor: $r('app.color.ds_on_surface_variant'),
      boxSize: $r('app.float.ds_input_icon_box_md'),
      iconSizeOverride: $r('app.float.ds_input_icon_size_md'),
      accessibilityLabel: this.masterPasswordVisible ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.masterPasswordVisible = !this.masterPasswordVisible,
    })
  }

  @LocalBuilder
  private masterPasswordTrailing() {
    Row({ space: $r('app.float.ds_space_xs') }) {
      this.masterPasswordToggle()

      DsButton({
        variant: DsButtonVariant.Text,
        tone: DsButtonTone.Default,
        iconOnly: true,
        controlHeightOverride: $r('app.float.ds_input_icon_box_md'),
        leadingIcon: $r('app.string.symbol_generate'),
        iconSizeOverride: $r('app.float.ds_input_icon_size_md'),
        accessibilityLabelResource: $r('app.string.generate_password'),
        onTap: () => this.openGenerator(),
      })
    }
  }

  @LocalBuilder
  private confirmPasswordToggle() {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: this.confirmPasswordVisible,
      symbolColor: $r('app.color.ds_on_surface_variant'),
      boxSize: $r('app.float.ds_input_icon_box_md'),
      iconSizeOverride: $r('app.float.ds_input_icon_size_md'),
      accessibilityLabel: this.confirmPasswordVisible ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.confirmPasswordVisible = !this.confirmPasswordVisible,
    })
  }

  @Builder
  private masterPasswordContent() {
    Column({ space: $r('app.float.ds_space_md') }) {
      DsInput({
        text: this.form.masterPassword,
        placeholder: $r('app.string.text_input_placeholder'),
        type: InputType.Password,
        showPassword: this.masterPasswordVisible,
        tone: this.submitted && this.form.masterPasswordController.status === Status.Invalid
          ? DsInputTone.Error : DsInputTone.Default,
        trailingBuilder: this.masterPasswordTrailing,
        onChange: (value: string) => {
          this.form.setMasterPassword(value)
          if (this.submitted) {
            this.form.masterPasswordController.validate(value)
          }
        },
      })

      DsInput({
        text: this.form.confirmPassword,
        placeholder: $r('app.string.confirm_password'),
        type: InputType.Password,
        showPassword: this.confirmPasswordVisible,
        tone: this.submitted && this.form.confirmPasswordController.status === Status.Invalid
          ? DsInputTone.Error : DsInputTone.Default,
        trailingBuilder: this.confirmPasswordToggle,
        onChange: (value: string) => {
          this.form.setConfirmPassword(value)
          if (this.submitted) {
            this.form.confirmPasswordController.validate(value)
          }
        },
      })

      DsStrengthMeter({ password: this.form.masterPassword })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private masterPasswordField() {
    DsField({
      label: $r('app.string.master_password'),
      required: true,
      feedback: this.masterPasswordFeedback(),
      reserveFeedbackSpace: true,
      contentBuilder: () => {
        this.masterPasswordContent()
      },
    })
  }

  private keyFileDefaultName(): string {
    const date: string = DateUtil.getFormatDateStr(Date.now(), 'yyyyMMdd')
    return `${ResUtil.getStringSync($r('app.string.key_file_default_name')).replace('%s', date)}${KEY_FILE_SUFFIX}`
  }

  @LocalBuilder
  private boundKeyFileInfo() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        SymbolGlyph($r('app.string.symbol_key'))
          .fontSize($r('app.float.ds_icon_md'))
          .fontColor([$r('app.color.ds_primary')])
          .foregroundColor($r('app.color.ds_primary'))
        Text(this.keyFileName)
          .layoutWeight(1)
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: $r('app.float.ds_space_xs') }) {
        Text(this.keyFileFingerprintText)
          .width('100%')
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor($r('app.color.ds_on_surface_variant'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.CENTER)
          .wordBreak(WordBreak.BREAK_ALL)
        Text(this.keyFileSizeText)
          .width('100%')
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor($r('app.color.ds_on_surface_variant'))
      }
      .width('100%')
      .padding({ left: $r('app.float.ds_space_28') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private boundKeyFileActions() {
    Column({ space: $r('app.float.ds_space_md') }) {
      Divider()
        .strokeWidth(1)
        .color($r('app.color.ds_surface_high'))

      Row() {
        Row({ space: $r('app.float.ds_space_sm') }) {
          DsButton({
            variant: DsButtonVariant.Filled,
            tone: DsButtonTone.Default,
            buttonSize: DsButtonSize.Small,
            leadingIcon: $r('app.string.symbol_refresh'),
            label: $r('app.string.key_file_regenerate'),
            onTap: () => this.viewModel.generateKeyFile(this.keyFileDefaultName()),
          })

          DsButton({
            variant: DsButtonVariant.Filled,
            tone: DsButtonTone.Default,
            buttonSize: DsButtonSize.Small,
            leadingIcon: $r('app.string.symbol_upload_file'),
            label: $r('app.string.key_file_replace'),
            onTap: () => this.viewModel.chooseKeyFile(),
          })
        }

        DsButton({
          variant: DsButtonVariant.Text,
          tone: DsButtonTone.Error,
          buttonSize: DsButtonSize.Small,
          horizontalPaddingOverride: $r('app.float.ds_space_md'),
          leadingIcon: $r('app.string.symbol_close'),
          label: $r('app.string.key_file_remove'),
          onTap: () => this.viewModel.clearKeyFile(),
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @LocalBuilder
  private unboundKeyFileContent() {
    Column({ space: $r('app.float.ds_space_md') }) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        SymbolGlyph($r('app.string.symbol_key'))
          .fontSize($r('app.float.ds_icon_md'))
          .fontColor([$r('app.color.ds_text_primary')])
          .foregroundColor($r('app.color.ds_text_primary'))
        Column({ space: $r('app.float.ds_space_2') }) {
          Text($r('app.string.key_file_unbound_title'))
            .width('100%')
            .fontSize($r('app.float.ds_font_body'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_primary'))
          Text($r('app.string.key_file_unbound_description'))
            .width('100%')
            .fontSize($r('app.float.ds_font_body_sm'))
            .lineHeight(KEY_FILE_DESCRIPTION_LINE_HEIGHT)
            .fontColor($r('app.color.ds_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: $r('app.float.ds_space_sm') }) {
        Row() {
          DsButton({
            variant: DsButtonVariant.Filled,
            tone: DsButtonTone.Default,
            fullWidth: true,
            leadingIcon: $r('app.string.symbol_upload_file'),
            label: $r('app.string.key_file_import'),
            onTap: () => this.viewModel.chooseKeyFile(),
          })
        }
        .layoutWeight(1)

        Row() {
          DsButton({
            fullWidth: true,
            leadingIcon: $r('app.string.symbol_add'),
            label: $r('app.string.key_file_generate'),
            onTap: () => this.viewModel.generateKeyFile(this.keyFileDefaultName()),
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .transition(KEY_FILE_STATE_TRANSITION)
  }

  @Builder
  private keyFileContent() {
    // 两个状态在转场期间同时存在，Stack 叠放才不会让卡片高度瞬间翻倍。
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.keyFileBound) {
        Column({ space: $r('app.float.ds_space_md') }) {
          this.boundKeyFileInfo()
          this.boundKeyFileActions()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .transition(KEY_FILE_STATE_TRANSITION)
      } else {
        this.unboundKeyFileContent()
      }
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .border({
      width: $r('app.float.ds_border_width'),
      color: this.keyFileInvalid ? $r('app.color.ds_error') : Color.Transparent,
    })
  }

  @Builder
  private keyFileField() {
    DsField({
      label: $r('app.string.key_file_label'),
      required: true,
      feedback: this.keyFileInvalid ? $r('app.string.key_file_required') : undefined,
      reserveFeedbackSpace: true,
      contentBuilder: () => {
        this.keyFileContent()
      },
    })
  }

  @Builder
  private bottomActionContent() {
    DsButton({
      label: this.viewModel.busy ? $r('app.string.creating') : $r('app.string.create_open_vault'),
      trailingIcon: $r('app.string.symbol_chevron_right'),
      disabled: this.viewModel.busy,
      fullWidth: true,
      onTap: () => this.handleSubmit(),
    })
  }

  @Builder
  private bottomPanel() {
    DsBottomActionBar({
      onHeightChange: (height: number) => {
        this.bottomPanelHeight = height
      },
      contentBuilder: () => {
        this.bottomActionContent()
      },
    })
  }

  @Builder
  private pageHeaderBuilder() {
    DsPageHeader({
      title: $r('app.string.create_vault'),
      showBack: true,
      onBack: () => appRouter.pop(),
    })
  }

  @Builder
  private generatorBottomActions() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        DsButton({
          label: $r('app.string.regenerate_password'),
          tone: DsButtonTone.Default,
          leadingIcon: $r('app.string.symbol_refresh'),
          fullWidth: true,
          onTap: () => this.viewModel.generator.regenerate(),
        })
      }
      .layoutWeight(1)

      Row() {
        DsButton({
          label: $r('app.string.fill_current_entry'),
          leadingIcon: $r('app.string.symbol_check'),
          fullWidth: true,
          onTap: () => this.fillPasswordFromGenerator(),
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  // 预览底色上探到标题栏底部：内容绘制到标题栏下方，标题栏悬浮其上。
  @Computed
  get sheetTitleBarHeightVp(): number {
    const titleBarPx: number = ResUtil.getNumber($r('app.float.ds_page_header_height_sm').id)
    return this.getUIContext().px2vp(titleBarPx)
  }

  @LocalBuilder
  private generatorBody() {
    Stack() {
      GeneratorContent({
        viewModel: this.viewModel.generator,
        controller: this.generatorController,
        scroller: this.generatorScroller,
        topOffset: this.sheetTitleBarHeightVp,
        bottomOffset: this.generatorBottomBarHeight,
        onSheet: true,
      })
    }
    .width('100%')
    .height('100%')
  }

  @LocalBuilder
  private generatorBottomBar() {
    DsBottomActionBar({
      surfaceColor: $r('app.color.ds_surface_lowest'),
      fadeColor: $r('app.color.ds_surface_lowest_transparent'),
      onHeightChange: (height: number) => {
        this.generatorBottomBarHeight = height
      },
      contentBuilder: () => {
        this.generatorBottomActions()
      },
    })
  }

  @LocalBuilder
  private generatorSheet() {
    DsHalfModalSheet({
      title: $r('app.string.generate_password'),
      actions: this.generatorActions(),
      bodyBuilder: this.generatorBody,
      bottomBarBuilder: this.generatorBottomBar,
      contentBehindTitleBar: true,
    })
  }

  private generatorActions(): DsPageHeaderAction[] {
    return [{ icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.closeGenerator() }]
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column({ space: $r('app.float.ds_space_xl') }) {
            this.vaultNameField()
            this.authModeField()

            // 不绑定 index：页签只由 changeIndex 驱动。绑定后任何重渲染都会按旧 index 再跳一次，
            // 而自定义切换动画不支持打断，正在播的转场会被取消且此后不再触发。
            Tabs({ controller: this.tabsController }) {
              this.authTabContent(0)
              this.authTabContent(1)
              this.authTabContent(2)
            }
            .height('auto')
            .width('100%')
            .scrollable(false)
            .barHeight(0)
            .divider(null)
            .customContentTransition((from: number, to: number) => this.tabContentTransition(from, to))
            .clip(true)
          }
          .width('100%')
          // 位移量取上层稳定容器宽度：切换瞬间页签内容会超出 Tabs 边界，取 Tabs 自身实测会被污染。
          // 只在宽度真的变化时写入；三个页签高度不同，动画期间本容器高度会变，写入会打断转场。
          .onAreaChange((oldValue: Area, newValue: Area) => {
            if (newValue.width !== oldValue.width) {
              this.tabContentWidth = newValue.width as number
            }
          })
          .padding({
            top: $r('app.float.ds_space_lg'),
            bottom: this.bottomPanelHeight,
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

        this.bottomPanel()
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(dsNavPageTitleBarOptions((): void => this.pageHeaderBuilder()))
    .hideBackButton(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .bindSheet($$this.generatorSheetVisible, this.generatorSheet(), {
      backgroundColor: $r('app.color.ds_surface_lowest'),
      showClose: false,
      dragBar: false,
      // 设计稿半模态为直角面板，只有顶部一条描边。
      radius: LengthMetrics.vp(0),
      borderWidth: { top: LengthMetrics.vp(1) },
      borderColor: { top: $r('app.color.ds_outline_variant') },
      onDisappear: () => this.closeGenerator(),
    })
  }
}

@Builder
export function createVaultPageBuilder() {
  CreateVaultPage()
}
