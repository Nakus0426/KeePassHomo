import { ContentSlideTransition, SlideFrame, SshKeyAlgorithm } from '@ohos/common'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsControlSize } from '../../components/DsControlSize'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsSegmentedSwitch, DsSegmentedSwitchItem } from '../../components/DsSegmentedSwitch'
import { DsSlider } from '../../components/DsSlider'

const RSA_BITS_MIN: number = 2048
const RSA_BITS_MAX: number = 4096
const RSA_BITS_STEP: number = 1024
const RSA_BITS_DEFAULT: number = 3072
// 提示文案里必须加粗的推荐位长，数字不进资源。
const RSA_RECOMMENDED_BITS: string = '3072'
// 内容与底部操作栏之间留出的间距，与设计稿 body 的 24 一致。
const BOTTOM_BAR_CONTENT_GAP: number = 24
// 与 DsNotice 正文同一行高，bodyBuilder 自绘时保持一致。
const TIP_BODY_LINE_HEIGHT: number = 18

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
  @Local private bottomBarHeight: number = 0
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

  private tabFrame(): SlideFrame {
    return { opacity: this.tabOpacity, offsetX: this.tabOffsetX, zIndex: this.tabZIndex }
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    return ContentSlideTransition.tabTransition(this.getUIContext(), this.tabFrame(), from, to, this.contentWidth,
      (timer: number) => {
        this.startFrameTimer = timer
      })
  }

  // 推荐标题随类型切换；RSA 侧提醒兼容性优先。
  private tipTitle(): Resource {
    return this.segmentIndex === SshKeyType.Ed25519
      ? $r('app.string.ssh_key_recommend_ed25519')
      : $r('app.string.ssh_key_recommend_rsa')
  }

  // 只有 RSA2048 的推荐位长需要加粗，整段走 Span 才不会复制 DsNotice 的正文样式。
  @LocalBuilder
  private tipBody() {
    Text() {
      if (this.segmentIndex === SshKeyType.Ed25519) {
        Span($r('app.string.ssh_key_tip_ed25519'))
      } else if (this.bits === RSA_BITS_MIN) {
        Span($r('app.string.ssh_key_tip_rsa2048_prefix'))
        Span(RSA_RECOMMENDED_BITS)
          .fontWeight(FontWeight.Bold)
        Span($r('app.string.ssh_key_tip_rsa2048_suffix'))
      } else {
        Span($r('app.string.ssh_key_tip_rsa_compat'))
      }
    }
    .width('100%')
    .fontSize($r('app.float.ds_font_body_sm'))
    .lineHeight(TIP_BODY_LINE_HEIGHT)
    .fontColor($r('app.color.ds_on_surface_variant'))
  }

  // 生成器的字段标签比表单页更轻：12 / Medium / 次级色，与设计稿一致。
  @LocalBuilder
  private fieldLabel(label: Resource) {
    Text(label)
      .width('100%')
      .fontSize($r('app.float.ds_font_label_md'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.ds_text_secondary'))
  }

  @LocalBuilder
  private bitsContent() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Column() {
        DsSlider({
          value: this.bits,
          min: RSA_BITS_MIN,
          max: RSA_BITS_MAX,
          step: RSA_BITS_STEP,
          sliderSize: DsControlSize.Medium,
          onChange: (value: number) => this.bits = value,
        })
      }
      .layoutWeight(1)

      Text(`${this.bits}`)
        .fontSize($r('app.float.ds_font_body'))
        .fontColor($r('app.color.ds_text_secondary'))
    }
    .width('100%')
  }

  @LocalBuilder
  private typeTabContent(type: number) {
    TabContent() {
      Column({ space: $r('app.float.ds_space_16') }) {
        if (type === SshKeyType.Rsa) {
          this.fieldLabel($r('app.string.ssh_key_generate_bits'))
          this.bitsContent()
        }

        DsNotice({
          tone: DsNoticeTone.Default,
          title: this.tipTitle(),
          bodyBuilder: this.tipBody,
        })
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
      Column({ space: $r('app.float.ds_space_16') }) {
        this.fieldLabel($r('app.string.ssh_key_generate_type'))
        this.typeSelector()

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
        top: $r('app.float.ds_space_24'),
        bottom: this.bottomBarHeight + BOTTOM_BAR_CONTENT_GAP,
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
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

  @LocalBuilder
  private bottomBarContent() {
    DsButton({
      label: $r('app.string.ssh_key_generate'),
      variant: DsButtonVariant.Filled,
      tone: DsButtonTone.Primary,
      fullWidth: true,
      onTap: () => this.onConfirm(algorithmFor(this.segmentIndex, this.bits)),
    })
  }

  @LocalBuilder
  private bottomBar() {
    DsBottomActionBar({
      onHeightChange: (height: number) => {
        if (height !== this.bottomBarHeight) {
          this.bottomBarHeight = height
        }
      },
      contentBuilder: this.bottomBarContent,
    })
  }

  build() {
    DsHalfModalSheet({
      title: $r('app.string.ssh_key_generate_title'),
      onClose: () => this.onClose(),
      bodyBuilder: this.bodyContent,
      bottomBarBuilder: this.bottomBar,
    })
  }
}
