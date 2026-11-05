import { ContentSlideTransition, SlideFrame, SshKeyAlgorithm } from '@ohos/common'
import { FormItem, LabelPlacement } from '../../components/FormItem'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsPageHeaderAction } from '../../components/DsPageHeader'
import { DsSegmentedSwitch, DsSegmentedSwitchItem } from '../../components/DsSegmentedSwitch'

const RSA_BITS_MIN: number = 2048
const RSA_BITS_MAX: number = 4096
const RSA_BITS_STEP: number = 1024
const RSA_BITS_DEFAULT: number = 3072
// 提示文案里必须加粗的推荐位长，数字不进资源。
const RSA_RECOMMENDED_BITS: string = '3072'

// 页签下标即密钥类型，用数值枚举避免在页签索引与类型之间来回转换。
enum SshKeyType {
  Ed25519 = 0,
  Rsa = 1,
}

function algorithmFor(type: number, bits: number): SshKeyAlgorithm {
  if (type === SshKeyType.Ed25519) {
    return SshKeyAlgorithm.Ed25519
  }
  if (bits === RSA_BITS_MIN) {
    return SshKeyAlgorithm.Rsa2048
  }
  return bits === RSA_BITS_MAX ? SshKeyAlgorithm.Rsa4096 : SshKeyAlgorithm.Rsa3072
}

// SSH 密钥生成半模态：只收集参数，生成动作与结果反馈由调用方负责，确认后立即收起。
@ComponentV2
export struct SshKeyGeneratorSheet {
  @Event onConfirm: (algorithm: SshKeyAlgorithm) => void = () => {
  }
  @Event onClose: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Local private currentTabIndex: number = SshKeyType.Ed25519
  // 分段按钮选中项与页签下标分开保存：两者写在同一状态时，回调改状态会在动画中途再动一次页签下标。
  @Local private segmentIndex: number = SshKeyType.Ed25519
  @Local private bits: number = RSA_BITS_DEFAULT
  @Local private contentWidth: number = 0
  // 直接持有数组，V2 才能观测逐项写入；SlideFrame 仅作传参视图。
  @Local private tabOpacity: number[] = [1, 0]
  @Local private tabOffsetX: number[] = [0, 0]
  @Local private tabZIndex: number[] = [1, 0]
  private startFrameTimer: number = -1
  private readonly typeItems: DsSegmentedSwitchItem[] = [
    { label: $r('app.string.ssh_algorithm_ed25519'), enabled: true },
    { label: $r('app.string.ssh_key_algorithm_rsa'), enabled: true },
  ]
  private readonly tabsController: TabsController = new TabsController()
  // 每次打开都回到默认类型与推荐位长，选择不跨次保留；页签动效状态一并归位。
  aboutToAppear(): void {
    this.currentTabIndex = SshKeyType.Ed25519
    this.segmentIndex = SshKeyType.Ed25519
    this.bits = RSA_BITS_DEFAULT
    ContentSlideTransition.reset(this.tabFrame(), 0)
  }

  aboutToDisappear(): void {
    clearTimeout(this.startFrameTimer)
  }

  private sheetActions(): DsPageHeaderAction[] {
    return [
      {
        icon: $r('app.string.symbol_check'),
        label: $r('app.string.confirm'),
        onTap: () => this.onConfirm(algorithmFor(this.segmentIndex, this.bits)),
      },
      { icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.onClose() },
    ]
  }

  private tabFrame(): SlideFrame {
    return { opacity: this.tabOpacity, offsetX: this.tabOffsetX, zIndex: this.tabZIndex }
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    return ContentSlideTransition.tabTransition(this.getUIContext(), this.tabFrame(), from, to, this.contentWidth,
      (timer: number) => {
        this.startFrameTimer = timer
      })
  }

  @LocalBuilder
  private bitsContent() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Slider({
        value: this.bits,
        min: RSA_BITS_MIN,
        max: RSA_BITS_MAX,
        step: RSA_BITS_STEP,
        style: SliderStyle.InSet,
      })
        .layoutWeight(1)
        .showSteps(true)
        .onChange((value: number) => this.bits = value)

      Text(`${this.bits}`)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.ds_text_secondary'))
    }
    .width('100%')
  }

  @Builder
  private securityTip(type: number) {
    Row({ space: $r('app.float.ds_space_xs') }) {
      SymbolGlyph($r('app.string.symbol_info'))
        .fontSize($r('sys.float.Subtitle_L'))
        .fontColor([$r('app.color.ds_primary')])

      if (type === SshKeyType.Ed25519) {
        Text($r('app.string.ssh_key_tip_ed25519'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.ds_text_secondary'))
      } else if (this.bits === RSA_BITS_MIN) {
        Text() {
          Span($r('app.string.ssh_key_tip_rsa2048_prefix'))
          Span(RSA_RECOMMENDED_BITS)
            .fontWeight(FontWeight.Bold)
          Span($r('app.string.ssh_key_tip_rsa2048_suffix'))
        }
        .layoutWeight(1)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.ds_text_secondary'))
      } else {
        Text($r('app.string.ssh_key_tip_rsa_compat'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.ds_text_secondary'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding($r('app.float.ds_space_sm'))
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
  }

  @LocalBuilder
  private typeTabContent(type: number) {
    TabContent() {
      Column({ space: $r('app.float.ds_space_sm') }) {
        if (type === SshKeyType.Rsa) {
          FormItem({
            label: $r('app.string.ssh_key_generate_bits'),
            labelPlacement: LabelPlacement.Top,
            showFeedback: false,
            contentBuilder: this.bitsContent,
          })
        }

        this.securityTip(type)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      // 位移必须落在页签内容上：TabContent 只负责整体透明度与层级。
      .translate({ x: this.tabOffsetX[type] })
    }
    .align(Alignment.Top)
    .opacity(this.tabOpacity[type])
    .zIndex(this.tabZIndex[type])
    .clip(true)
  }

  // 只写分段按钮的选中项：页签绑定的下标若在动画中途改写，会再发一次索引变更导致反向抖动，
  // 页签下标统一由 onChange 回写。
  private selectType(index: number): void {
    this.segmentIndex = index
    this.tabsController.changeIndex(index)
  }

  @LocalBuilder
  private typeSelector() {
    DsSegmentedSwitch({
      items: this.typeItems,
      selectedIndex: this.segmentIndex,
      onSelect: (index: number) => this.selectType(index),
    })
  }

  @LocalBuilder
  private bodyContent() {
    Scroll() {
      Column({ space: $r('app.float.ds_space_sm') }) {
        FormItem({
          label: $r('app.string.ssh_key_generate_type'),
          labelPlacement: LabelPlacement.Top,
          showFeedback: false,
          contentBuilder: this.typeSelector,
        })

        Tabs({
          barPosition: BarPosition.Start,
          index: $$this.currentTabIndex,
          controller: this.tabsController,
        }) {
          this.typeTabContent(SshKeyType.Ed25519)
          this.typeTabContent(SshKeyType.Rsa)
        }
        .height('auto')
        .width('100%')
        .scrollable(false)
        .barHeight(0)
        .divider(null)
        .customContentTransition((from: number, to: number) => this.tabContentTransition(from, to))
        .onChange((index: number) => this.currentTabIndex = index)
        .clip(true)
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('app.float.ds_space_lg'),
        bottom: $r('app.float.ds_space_16'),
        left: $r('app.float.ds_space_sm'),
        right: $r('app.float.ds_space_sm'),
      })
      // 位移量取内容列实测宽度，不取 Tabs 自身：页签内容在切换瞬间会超出 Tabs 边界。
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.contentWidth = newValue.width as number
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    .onTouch(() => this.onActivity())
    .clip(false)
  }

  build() {
    DsHalfModalSheet({
      title: $r('app.string.ssh_key_generate'),
      actions: this.sheetActions(),
      bodyBuilder: this.bodyContent,
    })
  }
}
