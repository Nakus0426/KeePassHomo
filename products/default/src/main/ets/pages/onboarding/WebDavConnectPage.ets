import { HdsNavDestination } from '@kit.UIDesignKit'
import {
  AnimationTokens,
  ContentSlideTransition,
  DelayedVisibility,
  SlideFrame,
  WebDavEntry,
  WebDavProbeErrorCategory,
} from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsBreadcrumb, DsBreadcrumbItemData, DsBreadcrumbSize } from '../../components/DsBreadcrumb'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsField } from '../../components/DsField'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { DsLoadingIndicator, DsLoadingIndicatorSize, DsLoadingIndicatorTone } from '../../components/DsLoadingIndicator'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsPageHeader } from '../../components/DsPageHeader'
import { DsRadio, DsRadioSize } from '../../components/DsRadio'
import { dsNavPageTitleBarOptions } from '../../components/DsPageTitleBar'
import { DsStepper } from '../../components/DsStepper'
import { IconToggleButton } from '../../components/IconToggleButton'
import { DsInfoTile } from '../../components/DsInfoTile'
import { DsTag, DsTagSize, DsTagTone } from '../../components/DsTag'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import {
  WebDavConnectStatus,
  WebDavConnectViewModel,
  WebDavListStatus,
  WebDavStep,
} from '../../viewmodel/WebDavConnectViewModel'

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

// 「下一步」连接成功后，按钮短暂停留「连接成功」的时长。
const SUCCESS_FLASH_MS: number = 800

// 文件行：hover/press 状态下沉到行内，避免整页随悬停重建。
@ComponentV2
struct WebDavFileRow {
  @Require @Param entry: WebDavEntry
  @Param selected: boolean = false
  @Param metaText: string = ''
  @Event onActivate: () => void = () => {
  }
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  private isKdbx(): boolean {
    return !this.entry.isCollection && this.entry.name.toLowerCase().endsWith('.kdbx')
  }

  private clickable(): boolean {
    return this.entry.isCollection || this.isKdbx()
  }

  private rowFill(): ResourceColor {
    if (!this.clickable()) {
      return $r('app.color.ds_surface_low')
    }
    if (this.pressed) {
      return $r('app.color.ds_surface_highest')
    }
    if (this.hovered) {
      return $r('app.color.ds_surface_container')
    }
    return this.selected ? $r('app.color.ds_surface_high') : $r('app.color.ds_surface_low')
  }

  private rowIcon(): Resource {
    if (this.entry.isCollection) {
      return $r('app.string.symbol_folder')
    }
    return this.isKdbx() ? $r('app.string.symbol_description') : $r('app.string.symbol_key')
  }

  private rowIconColor(): ResourceColor {
    if (this.entry.isCollection) {
      return $r('app.color.ds_on_surface_variant')
    }
    return this.isKdbx() ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_tertiary')
  }

  private rowTextColor(): ResourceColor {
    return this.entry.isCollection || this.isKdbx()
      ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_tertiary')
  }

  build() {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph(this.rowIcon())
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([this.rowIconColor()])
        .foregroundColor(this.rowIconColor())
      Column({ space: $r('app.float.ds_space_2') }) {
        Text(this.entry.name)
          .width('100%')
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(600)
          .fontColor(this.rowTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.entry.isCollection ? $r('app.string.webdav_folder') : this.metaText)
          .width('100%')
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor($r('app.color.ds_text_tertiary'))
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.entry.isCollection) {
        SymbolGlyph($r('app.string.symbol_chevron_right'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_on_surface_variant')])
          .foregroundColor($r('app.color.ds_on_surface_variant'))
      } else if (this.isKdbx()) {
        DsRadio({
          checked: this.selected,
          hovered: this.hovered,
          pressed: this.pressed,
          radioSize: DsRadioSize.Medium,
        })
      }
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_space_16'),
      right: $r('app.float.ds_space_16'),
    })
    .backgroundColor(this.rowFill())
    .borderRadius($r('app.float.ds_radius_none'))
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
    .onHover((isHover: boolean) => {
      if (!this.clickable()) {
        return
      }
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (!this.clickable()) {
        return
      }
      if (event.type === TouchType.Down) {
        this.pressed = true
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => this.onActivate())
  }
}

@ComponentV2
export struct WebDavConnectPage {
  @Local private viewModel: WebDavConnectViewModel = new WebDavConnectViewModel()
  private readonly app: AppViewModel = appViewModel
  @Local private passwordVisible: boolean = false
  @Local private bottomBarHeight: number = 0
  @Local private contentWidth: number = 0
  @Local private stepOpacity: number[] = [1, 0, 0]
  @Local private stepOffsetX: number[] = [0, 0, 0]
  @Local private stepZIndex: number[] = [1, 0, 0]
  private readonly stepTabsController: TabsController = new TabsController()
  private startFrameTimer: number = -1
  // 目录层级转场：旧列表与新列表两层交替，方向由「进入下级 / 返回上级」决定。
  @Local private listOpacity: number[] = [1, 0]
  @Local private listOffsetX: number[] = [0, 0]
  @Local private listZIndex: number[] = [1, 0]
  @Local private layerA: WebDavEntry[] = []
  @Local private layerB: WebDavEntry[] = []
  private activeLayer: number = 0
  // 转场期间由 navigateDirectory 接管图层写入，避免 entries 监视回调提前覆盖起始帧。
  private listTransitioning: boolean = false
  private listFrameTimer: number = -1
  @Local private testGate: DelayedVisibility = new DelayedVisibility()
  @Local private nextGate: DelayedVisibility = new DelayedVisibility()
  @Local private listGate: DelayedVisibility = new DelayedVisibility()
  // 「下一步」连接成功后的短暂反馈，先提示成功再进入下一步；时序属视图层。
  @Local private successFlash: boolean = false
  private successTimer: number = -1

  @Monitor('viewModel.connectStatus')
  onConnectStatusChanged(): void {
    this.testGate.setActive(this.viewModel.connectStatus === WebDavConnectStatus.Testing)
  }

  @Monitor('viewModel.advancing')
  onAdvancingChanged(): void {
    this.nextGate.setActive(this.viewModel.advancing)
  }

  @Monitor('viewModel.listStatus')
  onListStatusChanged(): void {
    this.listGate.setActive(this.viewModel.listStatus === WebDavListStatus.Loading)
  }

  @Monitor('viewModel.step')
  onStepChanged(): void {
    // 页签下标只由 step 驱动；Tabs 不绑定 index，避免重渲染打断转场。
    this.stepTabsController.changeIndex(this.viewModel.step)
    this.cancelSuccessFlash()
  }

  @Computed
  get pageTitle(): Resource {
    switch (this.viewModel.step) {
      case WebDavStep.File:
        return $r('app.string.webdav_step_file')
      case WebDavStep.Confirm:
        return $r('app.string.webdav_step_confirm')
      default:
        return $r('app.string.webdav_connect_title')
    }
  }

  @Computed
  get stepLabels(): ResourceStr[] {
    return [
      $r('app.string.webdav_connect_title'),
      $r('app.string.webdav_step_file'),
      $r('app.string.webdav_step_confirm'),
    ]
  }

  @Computed
  get stepIcons(): Resource[] {
    return [
      $r('app.string.symbol_cloud_sync'),
      $r('app.string.symbol_folder'),
      $r('app.string.symbol_fact_check'),
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
  get vaultSizeText(): ResourceStr {
    const size: number = this.viewModel.selected?.size ?? 0
    return size > 0 ? this.app.formatSize(size) : $r('app.string.file_value_unknown')
  }

  @Computed
  get vaultModifiedText(): ResourceStr {
    const modifiedAt: number = this.viewModel.selected?.modifiedAt ?? 0
    return modifiedAt > 0 ? this.app.formatTime(modifiedAt * 1000) : $r('app.string.file_value_unknown')
  }

  @Computed
  get vaultDirectoryText(): string {
    const root: string = ResUtil.getStringSync($r('app.string.webdav_root_directory'))
    return this.viewModel.pathNames.length > 0 ? [root].concat(this.viewModel.pathNames).join(' / ') : root
  }

  // 面包屑项：根目录恒在首位，其后按当前层级名称排列，末项即当前层。
  @Computed
  get breadcrumbItems(): DsBreadcrumbItemData[] {
    const items: DsBreadcrumbItemData[] = [{
      key: 'root',
      label: $r('app.string.webdav_root_directory'),
      icon: $r('app.string.symbol_folder'),
    }]
    this.viewModel.pathNames.forEach((name: string, index: number) => {
      items.push({ key: `level_${index}`, label: name })
    })
    return items
  }

  aboutToDisappear(): void {
    clearTimeout(this.startFrameTimer)
    clearTimeout(this.listFrameTimer)
    clearTimeout(this.successTimer)
    this.testGate.dispose()
    this.nextGate.dispose()
    this.listGate.dispose()
    this.viewModel.clearSensitive()
  }

  private cancelSuccessFlash(): void {
    clearTimeout(this.successTimer)
    this.successTimer = -1
    this.successFlash = false
  }

  // 连接成功先播 800ms 成功态再进入选文件步；失败由 VM 就地报错。
  private async nextFromServer(): Promise<void> {
    if (!await this.viewModel.probeServer()) {
      return
    }
    this.successFlash = true
    this.successTimer = setTimeout(() => {
      this.successTimer = -1
      this.successFlash = false
      this.viewModel.enterFiles()
    }, SUCCESS_FLASH_MS)
  }

  @Monitor('viewModel.entries')
  onEntriesChanged(): void {
    if (!this.listTransitioning) {
      this.syncActiveLayer()
    }
  }

  // Tabs 转场状态：直接持有数组，V2 才能观测到逐项写入；SlideFrame 仅作传参视图。
  private stepFrame(): SlideFrame {
    return { opacity: this.stepOpacity, offsetX: this.stepOffsetX, zIndex: this.stepZIndex }
  }

  private listFrame(): SlideFrame {
    return { opacity: this.listOpacity, offsetX: this.listOffsetX, zIndex: this.listZIndex }
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    return ContentSlideTransition.tabTransition(this.getUIContext(), this.stepFrame(), from, to, this.contentWidth,
      (timer: number) => {
        this.startFrameTimer = timer
      })
  }

  private activeLayerEntries(): WebDavEntry[] {
    return this.activeLayer === 0 ? this.layerA : this.layerB
  }

  private setLayerEntries(index: number, entries: WebDavEntry[]): void {
    if (index === 0) {
      this.layerA = entries
    } else {
      this.layerB = entries
    }
  }

  private syncActiveLayer(): void {
    this.setLayerEntries(this.activeLayer, this.viewModel.entries)
    ContentSlideTransition.reset(this.listFrame(), this.activeLayer)
  }

  // 目录切换：成功后把新列表放进另一层，旧层滑出、新层滑入，与页签转场同向同效。
  // 目录切换：成功后把新列表放进另一层，旧层滑出、新层滑入，与页签转场同向同效。
  private async navigateDirectory(direction: number, action: () => Promise<void>): Promise<void> {
    if (this.viewModel.listStatus === WebDavListStatus.Loading || this.listTransitioning) {
      return
    }
    this.listTransitioning = true
    await action()
    if (direction === 0 || this.viewModel.listStatus !== WebDavListStatus.Ready
      || this.viewModel.entries.length === 0) {
      this.listTransitioning = false
      this.syncActiveLayer()
      return
    }
    const from: number = this.activeLayer
    const to: number = 1 - from
    this.setLayerEntries(to, this.viewModel.entries)
    this.listFrameTimer = ContentSlideTransition.play(this.getUIContext(), this.listFrame(), from, to, direction,
      this.contentWidth, () => {
        this.setLayerEntries(from, [])
        this.activeLayer = to
        this.listTransitioning = false
        ContentSlideTransition.reset(this.listFrame(), to)
      })
  }

  // 行点击：文件夹进入下级，.kdbx 选中；其余文件 selectFile 内部会忽略。
  private activateEntry(entry: WebDavEntry): void {
    if (entry.isCollection) {
      this.navigateDirectory(1, () => this.viewModel.enterFolder(entry))
    } else {
      this.viewModel.selectFile(entry)
    }
  }

  @Builder
  private pageHeaderBuilder() {
    DsPageHeader({
      title: this.pageTitle,
      showBack: true,
      onBack: () => {
        if (!this.viewModel.backStep()) {
          appRouter.pop()
        }
      },
    })
  }

  @Builder
  private stepBarBuilder() {
    Column({ space: $r('app.float.ds_space_10') }) {
      DsStepper({
        steps: this.stepLabels,
        icons: this.stepIcons,
        currentIndex: this.viewModel.step,
        onSelect: (index: number) => this.viewModel.goToStep(index),
      })
      // 面包屑行恒定占位：仅在选择保险库步填内容，避免步骤条随步骤上下跳动。
      Row() {
        if (this.viewModel.step === WebDavStep.File) {
          this.directoryBar()
        }
      }
      .width('100%')
      .height($r('app.float.ds_button_height'))
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_sm'),
      bottom: $r('app.float.ds_space_sm'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .alignItems(HorizontalAlign.Start)
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
      disabled: this.viewModel.advancing,
      onChange: (value: string) => this.viewModel.setHost(value),
    })
  }

  @Builder
  private usernameInput() {
    DsInput({
      text: this.viewModel.username,
      placeholder: $r('app.string.text_input_placeholder'),
      disabled: this.viewModel.advancing,
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
      disabled: this.viewModel.advancing,
      trailingBuilder: this.passwordToggle,
      onChange: (value: string) => this.viewModel.setPassword(value),
    })
  }

  @LocalBuilder
  private testButtonContent() {
    if (this.testGate.visible) {
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
        .fontColor(this.viewModel.canTest
          ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_disabled'))
    }
  }

  @LocalBuilder
  private nextButtonContent() {
    if (this.successFlash) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        Text($r('app.string.webdav_status_success'))
          .fontSize($r('app.float.ds_font_title'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_success'))
        SymbolGlyph($r('app.string.symbol_check'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_success')])
          .foregroundColor($r('app.color.ds_success'))
      }
    } else if (this.nextGate.visible) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        Text($r('app.string.webdav_testing'))
          .fontSize($r('app.float.ds_font_title'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
        DsLoadingIndicator({
          indicatorSize: DsLoadingIndicatorSize.Small,
          tone: DsLoadingIndicatorTone.Surface,
        })
      }
    } else {
      Text($r('app.string.webdav_next'))
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor(this.viewModel.canGoNextFromServer
          ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_disabled'))
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
        leadingIcon: $r('app.string.symbol_arrow_upward'),
        iconSizeOverride: $r('app.float.ds_icon_sm'),
        iconColorOverride: $r('app.color.ds_on_surface_variant'),
        disabled: !this.viewModel.canGoUp || this.viewModel.listStatus === WebDavListStatus.Loading,
        accessibilityLabelResource: $r('app.string.webdav_up'),
        onTap: () => {
          this.navigateDirectory(-1, () => this.viewModel.goUp())
        },
      })
      Row() {
        DsBreadcrumb({
          items: this.breadcrumbItems,
          breadcrumbSize: DsBreadcrumbSize.Medium,
          disabled: this.viewModel.listStatus === WebDavListStatus.Loading,
          onSelect: (index: number) => {
            const direction: number = index < this.viewModel.pathNames.length ? -1 : 1
            this.navigateDirectory(direction, () => this.viewModel.goToDepth(index))
          },
        })
      }
      .layoutWeight(1)
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
          this.navigateDirectory(0, () => this.viewModel.refresh())
        },
      })
    }
    .width('100%')
    .height($r('app.float.ds_button_height'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private fileStep() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      if (this.viewModel.listStatus === WebDavListStatus.Loading && this.activeLayerEntries().length === 0) {
        Column() {
          if (this.listGate.visible) {
            DsLoadingIndicator({
              indicatorSize: DsLoadingIndicatorSize.Medium,
              tone: DsLoadingIndicatorTone.Surface,
            })
          }
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else if (this.activeLayerEntries().length === 0) {
        Text($r('app.string.webdav_empty_directory'))
          .width('100%')
          .fontSize($r('app.float.ds_font_body'))
          .fontColor($r('app.color.ds_text_tertiary'))
          .padding({ top: $r('app.float.ds_space_xl') })
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Column({ space: $r('app.float.ds_space_sm') }) {
            ForEach(this.layerA, (entry: WebDavEntry) => {
              WebDavFileRow({
                entry: entry,
                selected: this.isSelected(entry),
                metaText: this.viewModel.fileMeta(entry),
                onActivate: () => this.activateEntry(entry),
              })
            }, (entry: WebDavEntry) => entry.url)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .translate({ x: this.listOffsetX[0] })
          .opacity(this.listOpacity[0])
          .zIndex(this.listZIndex[0])

          Column({ space: $r('app.float.ds_space_sm') }) {
            ForEach(this.layerB, (entry: WebDavEntry) => {
              WebDavFileRow({
                entry: entry,
                selected: this.isSelected(entry),
                metaText: this.viewModel.fileMeta(entry),
                onActivate: () => this.activateEntry(entry),
              })
            }, (entry: WebDavEntry) => entry.url)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .translate({ x: this.listOffsetX[1] })
          .opacity(this.listOpacity[1])
          .zIndex(this.listZIndex[1])
        }
        .width('100%')
        .clip(true)
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

  @Builder
  private vaultFileCard() {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph($r('app.string.symbol_description'))
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([$r('app.color.ds_text_tertiary')])
        .foregroundColor($r('app.color.ds_text_tertiary'))
      Text(this.viewModel.selected?.name ?? '')
        .layoutWeight(1)
        .fontSize($r('app.float.ds_font_title_md'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_tight'))
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .ellipsisMode(EllipsisMode.CENTER)
    }
    .width('100%')
    .padding($r('app.float.ds_space_16'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(VerticalAlign.Center)
  }

  @LocalBuilder
  private accessTagContent() {
    Row() {
      DsTag({ tone: DsTagTone.Warning, tagSize: DsTagSize.Small, text: $r('app.string.read_only') })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  // 远端保险库一律只读，状态格用 Warning 语义标签表示访问权限。
  @Builder
  private accessTile() {
    DsInfoTile({
      icon: $r('app.string.symbol_lock'),
      label: $r('app.string.webdav_access_label'),
      valueBuilder: this.accessTagContent,
    })
  }

  @Builder
  private vaultInfo() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Text($r('app.string.webdav_vault_section'))
        .width('100%')
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_2xl'))
        .fontColor($r('app.color.ds_text_tertiary'))
      this.vaultFileCard()
      Row({ space: $r('app.float.ds_space_sm') }) {
        DsInfoTile({
          icon: $r('app.string.symbol_database'),
          label: $r('app.string.file_size'),
          value: this.vaultSizeText,
          monospace: true,
        })
        DsInfoTile({
          icon: $r('app.string.symbol_schedule'),
          label: $r('app.string.last_modified'),
          value: this.vaultModifiedText,
          monospace: true,
        })
      }
      .width('100%')

      Row({ space: $r('app.float.ds_space_sm') }) {
        DsInfoTile({
          icon: $r('app.string.symbol_folder'),
          label: $r('app.string.webdav_dir_label'),
          value: this.vaultDirectoryText,
        })
        this.accessTile()
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private bottomActionContent() {
    if (this.viewModel.step === WebDavStep.Server) {
      DsButton({
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        trailingIcon: this.nextGate.visible || this.successFlash
          ? undefined : $r('app.string.symbol_arrow_forward'),
        disabled: !this.viewModel.canGoNextFromServer || this.successFlash,
        contentBuilder: this.nextButtonContent,
        onTap: () => {
          this.nextFromServer()
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
        trailingIcon: $r('app.string.symbol_arrow_forward'),
        label: $r('app.string.webdav_next'),
        onTap: () => {
          this.viewModel.goToUnlock()
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
      this.vaultInfo()
    }
  }

  @Builder
  private stepTabContent(step: number) {
    TabContent() {
      Column() {
        this.stepPanel(step)
      }
      .width('100%')
      .translate({ x: this.stepOffsetX[step] })
    }
    .align(Alignment.Top)
    .opacity(this.stepOpacity[step])
    .zIndex(this.stepZIndex[step])
    .clip(true)
  }

  @Builder
  private stepTabs() {
    Tabs({ barPosition: BarPosition.Start, controller: this.stepTabsController }) {
      this.stepTabContent(WebDavStep.Server)
      this.stepTabContent(WebDavStep.File)
      this.stepTabContent(WebDavStep.Confirm)
    }
    .width('100%')
    .height('auto')
    .scrollable(false)
    .barHeight(0)
    .divider(null)
    .customContentTransition((from: number, to: number) => this.tabContentTransition(from, to))
    .clip(true)
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
            top: $r('app.float.ds_space_24'),
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
      (): void => this.stepBarBuilder()))
    .hideBackButton(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}

@Builder
export function webDavConnectPageBuilder() {
  WebDavConnectPage()
}
