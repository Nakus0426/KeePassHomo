import { matrix4 } from '@kit.ArkUI'
import { AnimationTokens, ColorUtil, VaultField } from '@ohos/common'
import { DsContextMenu, dsContextMenuOptions } from '../../components/DsContextMenu'
import { DsMenuItem } from '../../components/DsMenuItem'
import { PASSWORD_MASK } from '../../viewmodel/EntryPresentation'
// 真实 ID-1 卡比例 85.6 / 54。
const CARD_ASPECT: number = 1.585
// 卡面内元素比例统一以卡宽为基准：按卡高定的比例已除 CARD_ASPECT 折算过来。
const CARD_NUMBER_FONT_RATIO: number = 20 / 356
const CARD_NUMBER_SPACING_RATIO: number = 1 / 356
const CARD_NUMBER_LEFT_RATIO: number = 24 / 356
const CARD_NUMBER_TOP_RATIO: number = 36 / 356
const CARD_DETAILS_TOP_RATIO: number = 170 / 356
// 卡高 22% 的方画布：最宽的 Discover 词标渲染宽约卡宽 18%，与真卡相当。
const CARD_LOGO_SIZE_RATIO: number = 0.139
const CARD_LOGO_RIGHT_RATIO: number = 0.055
// 凸印：主字下方叠一层反差色，模拟卡号边缘的高差。
const CARD_EMBOSS_OFFSET_RATIO: number = 0.0035
// 极端长卡号（如 19 位）仍在单行内自适应缩字号，不换行。
const CARD_NUMBER_MIN_FONT_SCALE: number = 0.7
// 显隐交叉淡化的时长；两态各占一层，只互换透明度。
const CARD_NUMBER_FADE_DURATION: number = 200
// 按下瞬间的压入时长；抬起回正复用 STATE_TRANSITION_DURATION。
const CARD_PRESS_DURATION: number = 120

// 3D 按压倾斜：轴取手指相对卡心方向的垂直轴，倾角随偏离卡心距离线性增大。
const CARD_TILT_MAX_ANGLE: number = 10
// 相机距离取卡宽的倍数：绝对 px 会随屏幕密度改变透视强度（真实距离约卡宽 4 倍，取 3 倍做视觉强化）。
const CARD_PERSPECTIVE_WIDTHS: number = 3
const CARD_PRESS_SCALE: number = 0.97
// 手指侧应被压下；若真机手感相反（手指侧被抬起），改这里即可。
const CARD_TILT_SIGN: number = 1
const CARD_GLARE_MAX_OPACITY: number = 0.38
// 光带峰值不透明度，再乘按压深度控制整体亮度。
const CARD_GLARE_PEAK_ALPHA: number = 0.55
// 光带峰值靠近翘起侧：0 位在受压侧，1 位在翘起侧。
const CARD_GLARE_PEAK_POSITION: number = 0.72
// 受压侧压暗的最大不透明度。
const CARD_SHADE_MAX_ALPHA: number = 0.22
// 非刚体形变：受压角沿 z 额外下沉（占卡宽比例），二次分布把下沉集中在受压角。
const CARD_PRESS_SINK_RATIO: number = 0.06
// 内容视差：浮起的卡号与 logo 相对卡面朝受压方向外移，取卡宽比例作视觉夸张。
const CARD_PARALLAX_RATIO: number = 0.012
const CARD_RIM_MAX_OPACITY: number = 0.45
// ShadowOptions 的 radius / offset 单位是 px，由 vp2px 换算。
const CARD_SHADOW_RADIUS_VP: number = 26
const CARD_SHADOW_OFFSET_VP: number = 6
// 渐变只换角度，颜色与停止点固定；提为常量，跟手时不再逐帧重建。
const CARD_GLARE_COLORS: Array<[ResourceColor, number]> = [
  [ColorUtil.withAlphaHex($r('sys.color.white'), 0), 0],
  [ColorUtil.withAlphaHex($r('sys.color.white'), CARD_GLARE_PEAK_ALPHA), CARD_GLARE_PEAK_POSITION],
  [ColorUtil.withAlphaHex($r('sys.color.white'), 0), 1],
]
const CARD_SHADE_COLORS: Array<[ResourceColor, number]> = [
  [ColorUtil.withAlphaHex($r('sys.color.black'), CARD_SHADE_MAX_ALPHA), 0],
  [ColorUtil.withAlphaHex($r('sys.color.black'), 0), 1],
]

interface CardFaceMetrics {
  numberFontSize: number;
  numberSpacing: number;
  numberLeft: number;
  numberTop: number;
  detailsTop: number;
  embossOffset: number;
  logoSize: number;
  logoRight: number;
}

interface MatrixPoint {
  x: number;
  y: number;
}

@Extend(Text)
function bankCardNumberStyle(fontSize: number, spacing: number) {
  .fontSize(fontSize)
  .maxFontSize(fontSize)
  .minFontSize(fontSize * CARD_NUMBER_MIN_FONT_SCALE)
  .maxLines(1)
  .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
  .fontWeight(600)
  .letterSpacing(spacing)
}

@ComponentV2
export struct EntryPreviewBankCard {
  @Require @Param numberMask: string
  @Require @Param numberDigits: string
  @Require @Param numberRevealed: boolean
  @Param holder: VaultField | undefined = undefined
  @Param expiry: VaultField | undefined = undefined
  @Param logo: Resource | undefined = undefined
  @Event onCopy: (text: string) => void = (_text: string) => {}
  // 卡面元素全部按卡宽比例定位，宽度由 onAreaChange 实测。
  @Local private cardWidthVp: number = 0
  // 3D 按压倾斜：手指相对卡心的归一化偏移（-1~1）与按压深度，跟手期间直接绑定。
  @Local private cardPressed: boolean = false
  @Local private cardTiltNx: number = 0
  @Local private cardTiltNy: number = 0
  // 目标点数组复用；矩阵本身每帧新建，交给框架做属性比较。
  private readonly cardDstPoints: MatrixPoint[] = [
    { x: 0, y: 0 }, { x: 0, y: 0 }, { x: 0, y: 0 }, { x: 0, y: 0 },
  ]

  @Computed
  private get cardMetrics(): CardFaceMetrics {
    const width: number = this.cardWidthVp
    return {
      numberFontSize: width * CARD_NUMBER_FONT_RATIO,
      numberSpacing: width * CARD_NUMBER_SPACING_RATIO,
      numberLeft: width * CARD_NUMBER_LEFT_RATIO,
      numberTop: width * CARD_NUMBER_TOP_RATIO,
      detailsTop: width * CARD_DETAILS_TOP_RATIO,
      embossOffset: width * CARD_EMBOSS_OFFSET_RATIO,
      logoSize: width * CARD_LOGO_SIZE_RATIO,
      logoRight: width * CARD_LOGO_RIGHT_RATIO,
    }
  }

  @Computed
  private get cardWidthPx(): number {
    return this.getUIContext().vp2px(this.cardWidthVp)
  }

  @Computed
  private get cardCorners(): MatrixPoint[] {
    const widthPx: number = this.cardWidthPx
    const heightPx: number = widthPx / CARD_ASPECT
    return [{ x: 0, y: 0 }, { x: widthPx, y: 0 }, { x: widthPx, y: heightPx }, { x: 0, y: heightPx }]
  }

  @Computed
  private get cardTiltRadius(): number {
    return Math.sqrt(this.cardTiltNx * this.cardTiltNx + this.cardTiltNy * this.cardTiltNy)
  }

  @Computed
  private get cardPressDepth(): number {
    return Math.min(1, this.cardTiltRadius)
  }

  // 绕平面内垂直轴旋转（受压侧 z 下沉、翘起侧抬起）+ 受压角额外下沉，再按相机距离做透视投影，
  // 四角目标点交给 setPolyToPoly 一次成型；按下缩放直接折进目标点，不另开 scale。
  @Computed
  private get cardTransform(): matrix4.Matrix4Transit {
    const widthPx: number = this.cardWidthPx
    const radius: number = this.cardTiltRadius
    if (widthPx <= 0 || radius === 0) {
      return matrix4.identity()
    }
    const depth: number = this.cardPressDepth
    const halfWidth: number = widthPx / 2
    const halfHeight: number = widthPx / CARD_ASPECT / 2
    const perspectivePx: number = widthPx * CARD_PERSPECTIVE_WIDTHS
    const dirX: number = this.cardTiltNx / radius
    const dirY: number = this.cardTiltNy / radius
    const tilt: number = CARD_TILT_MAX_ANGLE * depth * CARD_TILT_SIGN * Math.PI / 180
    const sinTilt: number = Math.sin(tilt)
    const cosTilt: number = Math.cos(tilt)
    // 四角在受压方向上的最大投影，用于把"受压角下沉"归一化成二次权重。
    const maxProjection: number = halfWidth * Math.abs(dirX) + halfHeight * Math.abs(dirY)
    const pressScale: number = this.cardPressed ? CARD_PRESS_SCALE : 1
    const src: MatrixPoint[] = this.cardCorners
    const dst: MatrixPoint[] = this.cardDstPoints
    for (let index: number = 0; index < src.length; index++) {
      const corner: MatrixPoint = src[index]
      const x: number = corner.x - halfWidth
      const y: number = corner.y - halfHeight
      const projection: number = x * dirX + y * dirY
      let z: number = -projection * sinTilt
      const pressedWeight: number = projection / maxProjection
      if (pressedWeight > 0) {
        z -= CARD_PRESS_SINK_RATIO * widthPx * depth * pressedWeight * pressedWeight
      }
      // 平面内分量：绕垂直轴旋转还会带一点沿轴向的平移。
      const axial: number = -dirY * x + dirX * y
      const planarX: number = x * cosTilt - dirY * axial * (1 - cosTilt)
      const planarY: number = y * cosTilt + dirX * axial * (1 - cosTilt)
      const factor: number = perspectivePx / (perspectivePx - z) * pressScale
      dst[index].x = halfWidth + planarX * factor
      dst[index].y = halfHeight + planarY * factor
    }
    return matrix4.identity().setPolyToPoly({ src: src, dst: dst, pointCount: 4 })
  }

  // 光轴背离受压侧：0 位落在受压侧、1 位落在翘起侧，明暗与光带共用这根轴。
  // linearGradient 角度约定为 0° 由下往上、顺时针为正，故屏幕向量的角度取 atan2(x, -y)。
  @Computed
  private get cardLightAngle(): number {
    return Math.atan2(-this.cardTiltNx, this.cardTiltNy) * 180 / Math.PI
  }

  // 视差方向按透视投影推导：浮起的内容会被放大，故相对卡面朝受压侧外移。
  @Computed
  private get cardShiftScale(): number {
    return CARD_PARALLAX_RATIO * this.cardWidthVp / Math.max(1, this.cardTiltRadius)
  }

  @Computed
  private get cardShiftX(): number {
    return this.cardShiftScale * this.cardTiltNx
  }

  @Computed
  private get cardShiftY(): number {
    return this.cardShiftScale * this.cardTiltNy
  }

  @Computed
  private get cardGlareOpacity(): number {
    return CARD_GLARE_MAX_OPACITY * this.cardPressDepth
  }

  @Computed
  private get cardRimOpacity(): number {
    return CARD_RIM_MAX_OPACITY * this.cardPressDepth
  }

  @Computed
  private get cardShadow(): ShadowOptions {
    const depth: number = this.cardPressDepth
    const offset: number = this.getUIContext().vp2px(CARD_SHADOW_OFFSET_VP * depth)
    return {
      radius: this.getUIContext().vp2px(CARD_SHADOW_RADIUS_VP * (0.5 + 0.5 * depth)),
      color: ColorUtil.withAlpha($r('sys.color.black'), 0.12 + 0.10 * depth),
      offsetX: -this.cardTiltNx * offset,
      offsetY: -this.cardTiltNy * offset,
    }
  }

  // TouchObject.x/y 单位是 vp、以卡面左上角为原点，这里换算成相对卡心的归一化偏移。
  private trackCardPress(x: number, y: number): void {
    const halfWidth: number = this.cardWidthVp / 2
    const halfHeight: number = this.cardWidthVp / CARD_ASPECT / 2
    if (halfWidth <= 0 || halfHeight <= 0) {
      return
    }
    const nx: number = Math.max(-1, Math.min(1, (x - halfWidth) / halfWidth))
    const ny: number = Math.max(-1, Math.min(1, (y - halfHeight) / halfHeight))
    this.cardTiltNx = nx
    this.cardTiltNy = ny
  }

  // 跟手期间不加过渡动画：Move 直接改状态，只有按下与抬起两段用 animateTo 包裹。
  private onCardTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.releaseCard()
      return
    }
    const touch: TouchObject | undefined = event.touches[0]
    if (touch === undefined) {
      return
    }
    switch (event.type) {
      case TouchType.Down:
        this.getUIContext().animateTo({
          duration: CARD_PRESS_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        }, () => {
          this.cardPressed = true
          this.trackCardPress(touch.x, touch.y)
        })
        break
      case TouchType.Move:
        this.trackCardPress(touch.x, touch.y)
        break
      default:
        break
    }
  }

  private releaseCard(): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.cardPressed = false
      this.cardTiltNx = 0
      this.cardTiltNy = 0
    })
  }

  @LocalBuilder
  private cardMenuItems() {
    if ((this.holder?.value ?? '').length > 0) {
      DsMenuItem({
        icon: $r('app.string.symbol_copy'), label: $r('app.string.entry_preview_copy_holder'),
        onAction: () => this.onCopy(this.holder?.value ?? ''),
      })
    }
    if ((this.expiry?.value ?? '').length > 0) {
      DsMenuItem({
        icon: $r('app.string.symbol_copy'), label: $r('app.string.entry_preview_copy_expiry'),
        onAction: () => this.onCopy(this.expiry?.value ?? ''),
      })
    }
  }

  @LocalBuilder
  private cardMenu(_response: ResponseType) {
    DsContextMenu({ content: this.cardMenuItems })
  }

  @Computed
  private get cardMenuOptions(): ContextMenuOptions {
    const options: ContextMenuOptions = dsContextMenuOptions(() => this.releaseCard(), Placement.BottomRight)
    if (this.numberRevealed) {
      options.preview = MenuPreviewMode.NONE
    }
    return options
  }

  private cardFaceValue(field: VaultField | undefined): string {
    return field?.value && field.protected ? PASSWORD_MASK : field?.value ?? ''
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image($r('app.media.credit_card_face'))
        .draggable(false)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.ds_credit_card_face_tint'))
        .hitTestBehavior(HitTestMode.None)

      Row() {
        Stack({ alignContent: Alignment.BottomStart }) {
          // 掩码态：与明文态各占一层并同时在场，只交换透明度做交叉淡化。
          Stack({ alignContent: Alignment.BottomStart }) {
            Text(this.numberMask)
              .bankCardNumberStyle(this.cardMetrics.numberFontSize, this.cardMetrics.numberSpacing)
              .fontColor($r('app.color.ds_credit_card_face_emboss'))
              .offset({ y: this.cardMetrics.embossOffset })

            Text(this.numberMask)
              .bankCardNumberStyle(this.cardMetrics.numberFontSize, this.cardMetrics.numberSpacing)
              .fontColor($r('app.color.ds_credit_card_face_text'))
          }
          .opacity(this.numberRevealed ? 0 : 1)
          .accessibilityLevel(this.numberRevealed ? 'no-hide-descendants' : 'auto')
          .animation({
            duration: CARD_NUMBER_FADE_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          })

          Stack({ alignContent: Alignment.BottomStart }) {
            Text(this.numberDigits)
              .bankCardNumberStyle(this.cardMetrics.numberFontSize, this.cardMetrics.numberSpacing)
              .fontColor($r('app.color.ds_credit_card_face_emboss'))
              .offset({ y: this.cardMetrics.embossOffset })

            Text(this.numberDigits)
              .bankCardNumberStyle(this.cardMetrics.numberFontSize, this.cardMetrics.numberSpacing)
              .fontColor($r('app.color.ds_credit_card_face_text'))
          }
          .opacity(this.numberRevealed ? 1 : 0)
          .accessibilityLevel(this.numberRevealed ? 'auto' : 'no-hide-descendants')
          .animation({
            duration: CARD_NUMBER_FADE_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: this.cardMetrics.numberLeft })
      .position({ x: 0, y: this.cardMetrics.numberTop })
      .translate({ x: this.cardShiftX, y: this.cardShiftY })

      Row({ space: $r('app.float.ds_space_sm') }) {
        Column({ space: $r('app.float.ds_space_6') }) {
          Text(this.cardFaceValue(this.holder))
            .fontSize($r('app.float.ds_font_label_sm'))
            .fontWeight(600)
            .letterSpacing($r('app.float.ds_tracking_wide_md'))
            .fontColor($r('app.color.ds_credit_card_face_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.cardFaceValue(this.expiry))
            .fontSize($r('app.float.ds_font_body'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_credit_card_face_text'))
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.logo !== undefined) {
          Image(this.logo)
            .draggable(false)
            .width(this.cardMetrics.logoSize)
            .height(this.cardMetrics.logoSize)
            .objectFit(ImageFit.Contain)
        }
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')
      .padding({ left: this.cardMetrics.numberLeft, right: this.cardMetrics.logoRight })
      .position({ x: 0, y: this.cardMetrics.detailsTop })
      .translate({ x: this.cardShiftX, y: this.cardShiftY })

      // 棱边提亮：按压越深越亮，抬手由 animateTo 收回。
      Column()
        .width('100%')
        .height('100%')
        .borderRadius($r('app.float.ds_radius_none'))
        .border({ width: 1, color: ColorUtil.withAlphaHex($r('sys.color.white'), this.cardRimOpacity) })
        .hitTestBehavior(HitTestMode.None)

      // 移动光带：峰值落在翘起侧，亮度随按压深度；跟手期间不做插值。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: this.cardLightAngle,
          colors: CARD_GLARE_COLORS,
        })
        .opacity(this.cardGlareOpacity)
        .hitTestBehavior(HitTestMode.None)

      // 受压侧压暗：与光带共用一根光轴，0 位为受压侧。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: this.cardLightAngle,
          colors: CARD_SHADE_COLORS,
        })
        .opacity(this.cardPressDepth)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .aspectRatio(CARD_ASPECT)
    .borderRadius($r('app.float.ds_radius_none'))
    .clip(true)
    .transform(this.cardTransform)
    // setPolyToPoly 的映射以组件中心点为基准，官方要求把变换中心搬回左上角。
    .scale({
      x: 1,
      y: 1,
      centerX: 0,
      centerY: 0,
    })
    .shadow(this.cardShadow)
    .onTouch((event: TouchEvent) => this.onCardTouch(event))
    .bindContextMenuWithResponse(
      (this.holder?.value ?? '').length > 0 || (this.expiry?.value ?? '').length > 0
        ? this.cardMenu : undefined,
      this.cardMenuOptions)
    // 卡面自身消费拖动：父级 Scroll 不参与命中测试，跟手倾斜与页面滚动不会互相打架。
    .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      // Area 的宽高单位已是 vp，不能再过 px2vp。
      this.cardWidthVp = newValue.width as number
    })
  }
}
