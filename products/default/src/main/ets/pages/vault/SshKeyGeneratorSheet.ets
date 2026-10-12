import {
  SegmentButtonV2ItemOptions,
  SegmentButtonV2Items,
  SymbolGlyphModifier,
  TabSegmentButtonV2,
  uiMaterial,
  UIUtils,
} from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AnimationTokens, SshKeyAlgorithm } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { FormItem, LabelPlacement } from '../../components/FormItem'

const RSA_BITS_MIN: number = 2048
const RSA_BITS_MAX: number = 4096
const RSA_BITS_STEP: number = 1024
const RSA_BITS_DEFAULT: number = 3072
// 提示文案里必须加粗的推荐位长，数字不进资源。
const RSA_RECOMMENDED_BITS: string = '3072'
// 与密码生成器同款切换位移比例：页签宽度的一小段横向滑入。
const TYPE_TRANSITION_OFFSET_RATIO: number = 0.2

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
  // 与密码生成器一致：切换时旧页签淡出并向反方向滑走，新页签从切换方向滑入。
  @Local private tabOpacity: number[] = [1, 0]
  @Local private tabOffsetX: number[] = [0, 0]
  @Local private tabZIndex: number[] = [1, 0]
  private readonly typeItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.ssh_algorithm_ed25519') },
    { text: $r('app.string.ssh_key_algorithm_rsa') },
  ] as SegmentButtonV2ItemOptions[])
  private readonly typeBarMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.REGULAR,
    materialColor: $r('sys.color.comp_background_tertiary'),
    applyShadow: false,
  })
  private readonly tabsController: TabsController = new TabsController()
  private readonly confirmIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.checkmark')).fontColor([$r('sys.color.confirm')])
  private readonly closeIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.xmark')).fontColor([$r('sys.color.icon_primary')])

  // 每次打开都回到默认类型与推荐位长，选择不跨次保留；页签动效状态一并归位。
  aboutToAppear(): void {
    this.currentTabIndex = SshKeyType.Ed25519
    this.segmentIndex = SshKeyType.Ed25519
    this.bits = RSA_BITS_DEFAULT
    this.tabOpacity = [1, 0]
    this.tabOffsetX = [0, 0]
    this.tabZIndex = [1, 0]
  }

  // 单行标题栏实测高度才是内容避让量，titlebar_default_height 含材质余量，直接用会空出一大截。
  @Computed
  private get titleBarOffset(): number {
    const titlebarHeightPx: number = ResUtil.getNumber($r('sys.float.single_line_titlebar_height').id)
    const gapPx: number = ResUtil.getNumber($r('sys.float.padding_level16').id)
    return this.getUIContext().px2vp(titlebarHeightPx + gapPx)
  }

  @Computed
  private get typeTransitionOffset(): number {
    return this.contentWidth * TYPE_TRANSITION_OFFSET_RATIO
  }

  private menuItems(): HdsNavigationMenuItemOptions[] {
    const confirm: HdsNavigationIconOptions = {
      icon: this.confirmIcon,
      type: IconStyleMode.SMALL,
      label: $r('app.string.confirm'),
      action: () => this.onConfirm(algorithmFor(this.segmentIndex, this.bits)),
    }
    const close: HdsNavigationIconOptions = {
      icon: this.closeIcon,
      type: IconStyleMode.SMALL,
      label: $r('app.string.close'),
      action: () => this.onClose(),
    }
    return [{ content: confirm }, { content: close }]
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    if (from === to) {
      return {
        timeout: 0,
        transition: (proxy: TabContentTransitionProxy) => proxy.finishTransition(),
      }
    }

    const direction: number = to > from ? 1 : -1
    const offset: number = this.typeTransitionOffset

    return {
      timeout: AnimationTokens.STATE_TRANSITION_DURATION,
      transition: (proxy: TabContentTransitionProxy) => {
        UIUtils.applySync(() => {
          this.tabOpacity[from] = 1
          this.tabOffsetX[from] = 0
          this.tabOpacity[to] = 0
          this.tabOffsetX[to] = direction * offset
          this.tabZIndex[from] = 0
          this.tabZIndex[to] = 1
        })

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
      },
    }
  }

  @LocalBuilder
  private bitsContent() {
    Row({ space: $r('sys.float.padding_level8') }) {
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
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
  }

  @Builder
  private securityTip(type: number) {
    Row({ space: $r('sys.float.padding_level4') }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize($r('sys.float.Subtitle_L'))
        .fontColor([$r('sys.color.brand')])

      if (type === SshKeyType.Ed25519) {
        Text($r('app.string.ssh_key_tip_ed25519'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.bits === RSA_BITS_MIN) {
        Text() {
          Span($r('app.string.ssh_key_tip_rsa2048_prefix'))
          Span(RSA_RECOMMENDED_BITS)
            .fontWeight(FontWeight.Bold)
          Span($r('app.string.ssh_key_tip_rsa2048_suffix'))
        }
        .layoutWeight(1)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      } else {
        Text($r('app.string.ssh_key_tip_rsa_compat'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
  }

  @LocalBuilder
  private typeTabContent(type: number) {
    TabContent() {
      Column({ space: $r('sys.float.padding_level8') }) {
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
    TabSegmentButtonV2({
      items: this.typeItems,
      selectedIndex: this.segmentIndex,
      backgroundSystemMaterial: this.typeBarMaterial,
      $selectedIndex: (index: number) => this.selectType(index),
    })
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level8') }) {
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
          top: this.titleBarOffset,
          bottom: $r('sys.float.padding_level16'),
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
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
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.ssh_key_generate'),
        },
        menu: {
          value: this.menuItems(),
        },
      },
    })
  }
}
