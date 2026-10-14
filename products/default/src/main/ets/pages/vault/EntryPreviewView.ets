import { ChipV2, ChipV2Label, ChipV2Options, LengthMetrics, matrix4, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { EntrySheetViewModel, entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntryAvatar } from '../../components/EntryAvatar'
import { IconToggleButton } from '../../components/IconToggleButton'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'
import {
  AnimationTokens,
  AppToast,
  ColorUtil,
  ItemTemplate,
  RESERVED_FIELD_NAMES,
  VaultAttachmentMeta,
  VaultField,
  VaultFieldType,
} from '@ohos/common'
import { FileUtil, ResUtil } from '@pura/harmony-utils'
import {
  definitionFor,
  isTemplateFieldKey,
  ItemTemplateDefinition,
  TemplateFieldDefinition,
  TemplateFieldOption,
} from '../../model/EntryTemplateCatalog'
import { parseSshKeys, SSH_KEYS_FIELD, SshKeyDraft } from '../../model/SshKeyPayload'
import { EntrySshKeyList } from './EntrySshKeyList'

const PREVIEW_MENU_MAX_COUNT: number = 4
const PASSWORD_MASK: string = '••••••••'
// 与详情页既有显示时长一致；B04 统一切换到 PASSWORD_REVEAL_SECONDS 时改这一处。
const PREVIEW_REVEAL_SECONDS: number = 30

const CARD_NUMBER_KEY: string = 'CardNumber'
const CARD_TYPE_KEY: string = 'CardType'
// 真实 ID-1 卡比例 85.6 / 54。
const CARD_ASPECT: number = 1.585
const CARD_DIGIT_GROUP: number = 4
// 掩码长度固定，不泄露卡号位数。
// 用 ASCII 星号而非 U+2022：圆点在 HarmonyOS Sans 中缺失，会回退成 CJK 全宽字形（约 1em），
// 满字号下 16 点放不进卡内宽度，触发自适应缩字并让两态行高不一致。
const CARD_NUMBER_MASK: string = '**** **** **** ****'
// 卡面内元素比例统一以卡宽为基准：按卡高定的比例已除 CARD_ASPECT 折算过来。
const CARD_NUMBER_FONT_RATIO: number = 0.06
const CARD_NUMBER_SPACING_RATIO: number = 0.009
const CARD_NUMBER_LEFT_RATIO: number = 0.06
// 卡高 32%，保证整串卡号位于右下角 logo 之上。
const CARD_NUMBER_BOTTOM_RATIO: number = 0.202
// 卡高 22% 的方画布：最宽的 Discover 词标渲染宽约卡宽 18%，与真卡相当。
const CARD_LOGO_SIZE_RATIO: number = 0.139
const CARD_LOGO_RIGHT_RATIO: number = 0.055
const CARD_LOGO_BOTTOM_RATIO: number = 0.044
// 凸印：白字之下垫一层下移的黑影，受光面在上缘。
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

interface CardFaceMetrics {
  numberFontSize: number;
  numberSpacing: number;
  numberLeft: number;
  numberBottom: number;
  embossOffset: number;
  logoSize: number;
  logoRight: number;
  logoBottom: number;
}

interface MatrixPoint {
  x: number;
  y: number;
}

@ComponentV2
struct Cell {
  @Require @Param icon: Resource
  @Require @Param label: ResourceStr
  @Param value: string = ''
  @Param valueExpanded: boolean = false
  @Param clickable: boolean = true
  @Param showTrailingButton: boolean = false
  @Param trailingSymbol: Resource = $r('sys.symbol.chevron_down')
  @Param showExpandedContent: boolean = false
  @Param expandedContent: string = ''
  @Event onTrailingClick: () => void = () => {
  }
  @Event onCellClick: () => void = () => {
  }
  @BuilderParam trailingBuilder?: () => void
  @BuilderParam extraBuilder?: () => void

  build() {
    ListItem() {
      Column() {
        Row({ space: $r('sys.float.padding_level4') }) {
          SymbolGlyph(this.icon)
            .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
            .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
            .fontColor([$r('sys.color.brand')])

          Column({ space: $r('sys.float.padding_level4') }) {
            Text(this.label)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
            if (this.valueExpanded) {
              Text(this.value.length > 0 ? this.value : ' ')
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
                .wordBreak(WordBreak.BREAK_ALL)
            } else {
              Text(this.value.length > 0 ? this.value : ' ')
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .wordBreak(WordBreak.BREAK_ALL)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.trailingBuilder !== undefined) {
            Row({ space: $r('sys.float.padding_level4') }) {
              this.trailingBuilder()
            }
            .alignSelf(ItemAlign.Center)
          }
          if (this.showTrailingButton) {
            IconToggleButton({
              symbol: this.trailingSymbol,
              accessibilityLabel: $r('app.string.notes'),
              exclusive: true,
              onToggle: () => this.onTrailingClick(),
            })
          }
        }
        .alignItems(VerticalAlign.Top)

        if (this.extraBuilder !== undefined) {
          this.extraBuilder()
        }
      }

    }
    .padding($r('sys.float.padding_level6'))
    .margin($r('sys.float.padding_level2'))
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor(this.clickable ? $r('sys.color.interactive_pressed') : Color.Transparent)
      },
    })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .onClick(() => {
      if (!this.clickable) {
        return
      }
      this.onCellClick()
    })
  }
}

@ComponentV2
export struct EntryPreviewView {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
  @Event onClose: () => void = () => {
  }
  @Event onEdit: () => void = () => {
  }
  @Local private session: AppSessionState = appSessionState
  // 明文可见性是敏感状态，只在预览体存活期间有效，绝不外提；受保护字段共用一套倒计时。
  @Local private revealedKeys: Set<string> = new Set<string>()
  @Local private revealSeconds: number = 0
  // 卡面元素全部按卡宽比例定位，宽度由 onAreaChange 实测。
  @Local private cardWidthVp: number = 0
  // 3D 按压倾斜：手指相对卡心的归一化偏移（-1~1）与按压深度，跟手期间直接绑定。
  @Local private cardPressed: boolean = false
  @Local private cardTiltNx: number = 0
  @Local private cardTiltNy: number = 0
  @Local private cardPressDepth: number = 0
  private revealTimer: number = -1
  private readonly viewModel: AppViewModel = appViewModel
  private readonly favoriteIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.star'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly favoritedIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.star_fill'))
      .fontColor([$r('app.color.favorite')])
  private readonly editIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.square_and_pencil'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly deleteIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.trash'))
      .fontColor([$r('sys.color.warning')])
  private readonly closeIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.xmark'))
      .fontColor([$r('sys.color.titlebar_icon_color')])

  private needsExpansion(value: string): boolean {
    return value.includes('\n') || value.length > 48
  }

  private customFieldIcon(type: VaultFieldType): Resource {
    switch (type) {
      case VaultFieldType.Url:
        return $r('sys.symbol.link')
      case VaultFieldType.Email:
        return $r('sys.symbol.envelope')
      case VaultFieldType.Phone:
        return $r('sys.symbol.phone')
      case VaultFieldType.Address:
        return $r('sys.symbol.map')
      case VaultFieldType.Date:
        return $r('sys.symbol.calendar')
      case VaultFieldType.Password:
        return $r('sys.symbol.key')
      case VaultFieldType.Text:
        return $r('sys.symbol.textformat')
      default:
        return $r('sys.symbol.circle_grid_2x2')
    }
  }

  @Computed
  private get notes(): string {
    return this.fieldValue('Notes')
  }

  @Computed
  private get definition(): ItemTemplateDefinition {
    return definitionFor(this.sheet.template)
  }

  // 「其他」区：既不是 KDBX 保留字段，也不属于当前模板定义。
  @Computed
  private get customFields(): VaultField[] {
    return this.sheet.fields.filter((field: VaultField) =>
    !RESERVED_FIELD_NAMES.includes(field.name) && !isTemplateFieldKey(this.sheet.template, field.name))
  }

  // 附件只展示名字与体积；增删与导出在编辑页完成。
  @Computed
  private get attachments(): VaultAttachmentMeta[] {
    return this.sheet.previewEntry?.attachments ?? []
  }

  // SSH 密钥行由卡片列表渲染，不进字段行。
  @Computed
  private get previewFields(): TemplateFieldDefinition[] {
    return this.definition.fields.filter((field: TemplateFieldDefinition) =>
    !field.attachments && !field.sshKeys)
  }

  @Computed
  private get sshKeys(): SshKeyDraft[] {
    return parseSshKeys(this.fieldValue(SSH_KEYS_FIELD))
  }

  // 卡面只在信用卡模板出现；其它模板没有卡号与卡类型字段。
  @Computed
  private get showBankCard(): boolean {
    return this.definition.template === ItemTemplate.CreditCard
  }

  @Computed
  private get cardMetrics(): CardFaceMetrics {
    const width: number = this.cardWidthVp
    return {
      numberFontSize: width * CARD_NUMBER_FONT_RATIO,
      numberSpacing: width * CARD_NUMBER_SPACING_RATIO,
      numberLeft: width * CARD_NUMBER_LEFT_RATIO,
      numberBottom: width * CARD_NUMBER_BOTTOM_RATIO,
      embossOffset: width * CARD_EMBOSS_OFFSET_RATIO,
      logoSize: width * CARD_LOGO_SIZE_RATIO,
      logoRight: width * CARD_LOGO_RIGHT_RATIO,
      logoBottom: width * CARD_LOGO_BOTTOM_RATIO,
    }
  }

  // 卡面固定浅灰，故取不随深浅色变的彩色版 cardIcon，而非菜单用的 icon。
  @Computed
  private get cardLogo(): Resource | undefined {
    const cardType: string = this.fieldValue(CARD_TYPE_KEY)
    const field: TemplateFieldDefinition | undefined =
      this.definition.fields.find((definition: TemplateFieldDefinition) => definition.key === CARD_TYPE_KEY)
    if (cardType.length === 0 || field === undefined) {
      return undefined
    }
    const matched: TemplateFieldOption | undefined =
      field.options.find((option: TemplateFieldOption) => option.value === cardType)
    return matched === undefined ? undefined : matched.cardIcon
  }

  // 掩码态与明文态各占一层并同时在场，只交换透明度，避免换字时的字形跳变。
  @Computed
  private get cardNumberRevealed(): boolean {
    return this.cardNumberDigits.length > 0 && this.revealedKeys.has(CARD_NUMBER_KEY)
  }

  @Computed
  private get cardNumberDigits(): string {
    const raw: string = this.fieldValue(CARD_NUMBER_KEY).replace(/\s+/g, '')
    return raw.length === 0 ? '' : this.groupDigits(raw)
  }

  // 绕平面内垂直轴旋转（受压侧 z 下沉、翘起侧抬起）+ 受压角额外下沉，再按相机距离做透视投影，
  // 四角目标点交给 setPolyToPoly 一次成型；按下缩放直接折进目标点，不另开 scale。
  @Computed
  private get cardTransform(): matrix4.Matrix4Transit {
    const widthPx: number = this.getUIContext().vp2px(this.cardWidthVp)
    const depth: number = this.cardPressDepth
    const radius: number = Math.sqrt(this.cardTiltNx * this.cardTiltNx + this.cardTiltNy * this.cardTiltNy)
    if (widthPx <= 0 || depth === 0 || radius === 0) {
      return matrix4.identity()
    }
    const heightPx: number = widthPx / CARD_ASPECT
    const halfWidth: number = widthPx / 2
    const halfHeight: number = heightPx / 2
    const perspectivePx: number = widthPx * CARD_PERSPECTIVE_WIDTHS
    const dirX: number = this.cardTiltNx / radius
    const dirY: number = this.cardTiltNy / radius
    const tilt: number = CARD_TILT_MAX_ANGLE * depth * CARD_TILT_SIGN * Math.PI / 180
    const sinTilt: number = Math.sin(tilt)
    const cosTilt: number = Math.cos(tilt)
    // 四角在受压方向上的最大投影，用于把"受压角下沉"归一化成二次权重。
    const maxProjection: number = halfWidth * Math.abs(dirX) + halfHeight * Math.abs(dirY)
    const pressScale: number = this.cardPressed ? CARD_PRESS_SCALE : 1
    const corners: MatrixPoint[] = [
      { x: -halfWidth, y: -halfHeight },
      { x: halfWidth, y: -halfHeight },
      { x: halfWidth, y: halfHeight },
      { x: -halfWidth, y: halfHeight },
    ]
    const src: MatrixPoint[] = [
      { x: 0, y: 0 },
      { x: widthPx, y: 0 },
      { x: widthPx, y: heightPx },
      { x: 0, y: heightPx },
    ]
    const dst: MatrixPoint[] = []
    for (const corner of corners) {
      const projection: number = corner.x * dirX + corner.y * dirY
      let z: number = -projection * sinTilt
      const pressedWeight: number = maxProjection === 0 ? 0 : projection / maxProjection
      if (pressedWeight > 0) {
        z -= CARD_PRESS_SINK_RATIO * widthPx * depth * pressedWeight * pressedWeight
      }
      // 平面内分量：绕垂直轴旋转还会带一点沿轴向的平移。
      const axial: number = -dirY * corner.x + dirX * corner.y
      const planarX: number = corner.x * cosTilt - dirY * axial * (1 - cosTilt)
      const planarY: number = corner.y * cosTilt + dirX * axial * (1 - cosTilt)
      const factor: number = perspectivePx / (perspectivePx - z) * pressScale
      dst.push({ x: halfWidth + planarX * factor, y: halfHeight + planarY * factor })
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
  private cardShiftScale(): number {
    const radius: number = Math.sqrt(this.cardTiltNx * this.cardTiltNx + this.cardTiltNy * this.cardTiltNy)
    if (radius === 0) {
      return 0
    }
    return CARD_PARALLAX_RATIO * this.cardWidthVp * this.cardPressDepth / radius
  }

  @Computed
  private get cardShiftX(): number {
    return this.cardShiftScale() * this.cardTiltNx
  }

  @Computed
  private get cardShiftY(): number {
    return this.cardShiftScale() * this.cardTiltNy
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

  private groupDigits(raw: string): string {
    const groups: string[] = []
    for (let index: number = 0; index < raw.length; index += CARD_DIGIT_GROUP) {
      groups.push(raw.substring(index, index + CARD_DIGIT_GROUP))
    }
    return groups.join(' ')
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
    this.cardPressDepth = Math.min(1, Math.sqrt(nx * nx + ny * ny))
  }

  // 跟手期间不加过渡动画：Move 直接改状态，只有按下与抬起两段用 animateTo 包裹。
  private onCardTouch(event: TouchEvent): void {
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
      case TouchType.Up:
      case TouchType.Cancel:
        this.releaseCard()
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
      this.cardPressDepth = 0
    })
  }

  aboutToDisappear(): void {
    this.hideRevealed()
  }

  @Monitor('session.sensitiveEpoch')
  onSensitiveStateChanged(): void {
    this.hideRevealed()
  }

  private fieldValue(name: string): string {
    return this.sheet.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  private templateValue(definition: TemplateFieldDefinition): string {
    return this.fieldValue(definition.reservedField.length > 0 ? definition.reservedField : definition.key)
  }

  private clearRevealTimer(): void {
    if (this.revealTimer >= 0) {
      clearInterval(this.revealTimer)
      this.revealTimer = -1
    }
  }

  private hideRevealed(): void {
    this.clearRevealTimer()
    this.revealedKeys = new Set<string>()
    this.revealSeconds = 0
  }

  // Set 原地增删不触发 @Trace 通知，整体替换。
  private startRevealTimeout(key: string): void {
    this.clearRevealTimer()
    const next: Set<string> = new Set(this.revealedKeys)
    next.add(key)
    this.revealedKeys = next
    this.revealSeconds = PREVIEW_REVEAL_SECONDS
    this.revealTimer = setInterval(() => {
      this.revealSeconds--
      if (this.revealSeconds <= 0) {
        this.hideRevealed()
      }
    }, 1000)
  }

  private toggleReveal(key: string): void {
    if (this.revealedKeys.has(key)) {
      this.hideRevealed()
      return
    }
    this.startRevealTimeout(key)
  }

  private safeValue(value: string): string {
    return value.length > 0 ? PASSWORD_MASK : ''
  }

  private copy(value: string): void {
    this.viewModel.copyValue(value).then((copied: boolean) => {
      if (copied) {
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  // 复制受保护字段等同一次查看：显示掩码并开始倒计时。
  private copyProtected(key: string, value: string): void {
    if (value.length === 0) {
      return
    }
    this.viewModel.copyValue(value).then((copied: boolean) => {
      if (copied) {
        this.startRevealTimeout(key)
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  private openUrl(): void {
    this.viewModel.openFieldAction(this.fieldValue('URL'), VaultFieldType.Url)
  }

  private countdownText(): string {
    const time: string = `00:${this.revealSeconds < 10 ? '0' : ''}${this.revealSeconds}`
    return ResUtil.getStringSync($r('app.string.password_hide_countdown')).replace('%s', time)
  }

  private confirmDelete(): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.delete_entry_title'),
      message: $r('app.string.delete_entry_message'),
      primaryButton: {
        value: $r('app.string.cancel'), action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('sys.color.warning'),
        action: () => this.viewModel.deleteEntry(this.sheet.entryUuid).then((deleted: boolean) => {
          if (deleted) {
            this.onClose()
          }
        }),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private menuItem(icon: SymbolGlyphModifier, label: Resource, action: () => void,
    enabled: boolean = true): HdsNavigationMenuItemOptions {
    const content: HdsNavigationIconOptions = {
      icon: icon,
      type: IconStyleMode.SMALL,
      label: label,
      isEnabled: enabled,
      action: action,
    }
    return { content: content }
  }

  private previewMenuItems(): HdsNavigationMenuItemOptions[] {
    if (this.sheet.readOnly) {
      return [this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose())]
    }
    return [
      this.menuItem(this.sheet.favorite ? this.favoritedIcon : this.favoriteIcon,
        this.sheet.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
        () => this.sheet.toggleFavorite(), !this.viewModel.busy),
      this.menuItem(this.editIcon, $r('app.string.edit'), () => this.onEdit(), !this.viewModel.busy),
      this.menuItem(this.deleteIcon, $r('app.string.delete_entry'), () => this.confirmDelete(),
        !this.viewModel.busy),
      this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose()),
    ]
  }

  @LocalBuilder
  private revealTrailing(definition: TemplateFieldDefinition) {
    PasswordVisibilityToggle({
      visible: this.revealedKeys.has(definition.key),
      exclusive: true,
      onChange: () => this.toggleReveal(definition.key),
    })
  }

  // 卡面元素一律直接写在本 builder 内：带参数的子 @Builder 只在首次渲染取值，
  // 实测卡宽到来后不会刷新，字号会停在初始的 0。
  @Builder
  private bankCard() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image($r('app.media.credit_card_face'))
        .draggable(false)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Row() {
        Stack({ alignContent: Alignment.BottomStart }) {
          // 掩码态：与明文态各占一层并同时在场，只交换透明度做交叉淡化。
          Stack({ alignContent: Alignment.BottomStart }) {
            Text(CARD_NUMBER_MASK)
              .fontSize(this.cardMetrics.numberFontSize)
              .maxFontSize(this.cardMetrics.numberFontSize)
              .minFontSize(this.cardMetrics.numberFontSize * CARD_NUMBER_MIN_FONT_SCALE)
              .maxLines(1)
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.black'))
              .letterSpacing(this.cardMetrics.numberSpacing)
              .offset({ y: this.cardMetrics.embossOffset })

            Text(CARD_NUMBER_MASK)
              .fontSize(this.cardMetrics.numberFontSize)
              .maxFontSize(this.cardMetrics.numberFontSize)
              .minFontSize(this.cardMetrics.numberFontSize * CARD_NUMBER_MIN_FONT_SCALE)
              .maxLines(1)
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.white'))
              .letterSpacing(this.cardMetrics.numberSpacing)
          }
          .opacity(this.cardNumberRevealed ? 0 : 1)
          .animation({
            duration: CARD_NUMBER_FADE_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          })

          Stack({ alignContent: Alignment.BottomStart }) {
            Text(this.cardNumberDigits)
              .fontSize(this.cardMetrics.numberFontSize)
              .maxFontSize(this.cardMetrics.numberFontSize)
              .minFontSize(this.cardMetrics.numberFontSize * CARD_NUMBER_MIN_FONT_SCALE)
              .maxLines(1)
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.black'))
              .letterSpacing(this.cardMetrics.numberSpacing)
              .offset({ y: this.cardMetrics.embossOffset })

            Text(this.cardNumberDigits)
              .fontSize(this.cardMetrics.numberFontSize)
              .maxFontSize(this.cardMetrics.numberFontSize)
              .minFontSize(this.cardMetrics.numberFontSize * CARD_NUMBER_MIN_FONT_SCALE)
              .maxLines(1)
              .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.white'))
              .letterSpacing(this.cardMetrics.numberSpacing)
          }
          .opacity(this.cardNumberRevealed ? 1 : 0)
          .animation({
            duration: CARD_NUMBER_FADE_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: this.cardMetrics.numberLeft })
      .margin({ bottom: this.cardMetrics.numberBottom })
      .translate({ x: this.cardShiftX, y: this.cardShiftY })

      if (this.cardLogo !== undefined) {
        Row() {
          Image(this.cardLogo)
            .draggable(false)
            .width(this.cardMetrics.logoSize)
            .height(this.cardMetrics.logoSize)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .padding({ right: this.cardMetrics.logoRight })
        .margin({ bottom: this.cardMetrics.logoBottom })
        .translate({ x: this.cardShiftX, y: this.cardShiftY })
      }

      // 棱边提亮：按压越深越亮，抬手由 animateTo 收回。
      Column()
        .width('100%')
        .height('100%')
        .borderRadius($r('sys.float.corner_radius_level10'))
        .border({ width: 1, color: ColorUtil.withAlphaHex($r('sys.color.white'), this.cardRimOpacity) })
        .hitTestBehavior(HitTestMode.None)

      // 移动光带：峰值落在翘起侧，亮度随按压深度；跟手期间不做插值。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: this.cardLightAngle,
          colors: [
            [ColorUtil.withAlphaHex($r('sys.color.white'), 0), 0],
            [ColorUtil.withAlphaHex($r('sys.color.white'), CARD_GLARE_PEAK_ALPHA), CARD_GLARE_PEAK_POSITION],
            [ColorUtil.withAlphaHex($r('sys.color.white'), 0), 1],
          ],
        })
        .opacity(this.cardGlareOpacity)
        .hitTestBehavior(HitTestMode.None)

      // 受压侧压暗：与光带共用一根光轴，0 位为受压侧。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: this.cardLightAngle,
          colors: [
            [ColorUtil.withAlphaHex($r('sys.color.black'), CARD_SHADE_MAX_ALPHA), 0],
            [ColorUtil.withAlphaHex($r('sys.color.black'), 0), 1],
          ],
        })
        .opacity(this.cardPressDepth)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .aspectRatio(CARD_ASPECT)
    .borderRadius($r('sys.float.corner_radius_level10'))
    .clip(true)
    .margin({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
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
    // 卡面自身消费拖动：父级 Scroll 不参与命中测试，跟手倾斜与页面滚动不会互相打架。
    .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      // Area 的宽高单位已是 vp，不能再过 px2vp。
      this.cardWidthVp = newValue.width as number
    })
  }

  @LocalBuilder
  private revealCountdown(definition: TemplateFieldDefinition) {
    if (this.revealedKeys.has(definition.key) && this.revealSeconds > 0) {
      Text(this.countdownText())
        .width('100%')
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
        .padding({ left: $r('sys.float.padding_level16'), bottom: $r('sys.float.padding_level8') })
    }
  }

  @Builder
  private templateCell(definition: TemplateFieldDefinition) {
    if (definition.reservedField === 'Notes') {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.sheet.notesExpanded ? this.notes : this.notes.split('\n')[0],
        valueExpanded: this.sheet.notesExpanded,
        clickable: this.notes.length > 0,
        onCellClick: () => this.copy(this.notes),
        trailingBuilder: this.notesTrailing,
      })
    } else if (definition.protected) {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.revealedKeys.has(definition.key)
          ? this.templateValue(definition) : this.safeValue(this.templateValue(definition)),
        clickable: this.templateValue(definition).length > 0,
        onCellClick: () => this.copyProtected(definition.key, this.templateValue(definition)),
        trailingBuilder: () => {
          this.revealTrailing(definition)
        },
        extraBuilder: () => {
          this.revealCountdown(definition)
        },
      })
    } else if (definition.reservedField === 'URL') {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.templateValue(definition),
        clickable: this.templateValue(definition).length > 0,
        onCellClick: () => this.copy(this.templateValue(definition)),
        trailingBuilder: this.urlTrailing,
      })
    } else {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.sheet.expandedCustomFields.has(definition.key)
          ? this.templateValue(definition) : this.templateValue(definition).split('\n')[0],
        valueExpanded: this.sheet.expandedCustomFields.has(definition.key),
        clickable: this.templateValue(definition).length > 0,
        onCellClick: () => this.copy(this.templateValue(definition)),
        showTrailingButton: this.needsExpansion(this.templateValue(definition)),
        trailingSymbol: this.sheet.expandedCustomFields.has(definition.key)
          ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
        onTrailingClick: () => this.sheet.toggleCustomExpanded(definition.key),
      })
    }
  }

  @LocalBuilder
  private urlTrailing() {
    if (this.fieldValue('URL').length > 0) {
      IconToggleButton({
        symbol: $r('sys.symbol.arrow_up_right'),
        accessibilityLabel: $r('app.string.open_link'),
        exclusive: true,
        onToggle: () => this.openUrl(),
      })
    }
  }

  @LocalBuilder
  private notesTrailing() {
    if (this.needsExpansion(this.notes)) {
      IconToggleButton({
        symbol: this.sheet.notesExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
        accessibilityLabel: $r('app.string.notes'),
        exclusive: true,
        onToggle: () => this.sheet.toggleNotesExpanded(),
      })
    }
  }

  @Builder
  private previewMenu() {
    HdsNavigation() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level16') }) {
          Row({ space: $r('sys.float.padding_level8') }) {
            EntryAvatar(
              {
                title: this.sheet.title,
                avatarData: this.sheet.avatarData,
                avatarSize: $r('app.float.entry_avatar_size'),
                initialsFontSize: $r('sys.float.Display_S'),
              })
            Column({ space: $r('sys.float.padding_level4') }) {
              Text(this.sheet.title)
                .width('100%')
                .fontSize($r('sys.float.Title_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .ellipsisMode(EllipsisMode.CENTER)
              Row({ space: $r('sys.float.padding_level4') }) {
                SymbolGlyph($r('sys.symbol.folder')).fontSize($r('sys.float.Body_M'))
                  .fontColor([$r('sys.color.font_secondary')])
                Text(this.sheet.groupPath).fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .ellipsisMode(EllipsisMode.CENTER)
                  .layoutWeight(1)
              }
              .width('100%')
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .margin({ left: $r('sys.float.padding_level8') })

          if (this.showBankCard) {
            this.bankCard()
          }

          Column({ space: $r('sys.float.padding_level8') }) {
            if (this.sshKeys.length > 0) {
              EntrySshKeyList({
                keys: this.sshKeys,
                onActivity: () => this.viewModel.recordActivity(),
              })
            }

            List() {
              ForEach(this.previewFields, (definition: TemplateFieldDefinition) => {
                this.templateCell(definition)
              }, (definition: TemplateFieldDefinition) => definition.key)
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
            .borderRadius($r('sys.float.corner_radius_level10'))
            .divider({
              strokeWidth: 1,
              color: $r('sys.color.grid_menu_divider_color'),
              startMargin: $r('sys.float.padding_level8'),
              endMargin: $r('sys.float.padding_level8'),
            })

            if (this.attachments.length > 0) {
              List() {
                ForEach(this.attachments, (attachment: VaultAttachmentMeta) => {
                  Cell({
                    icon: $r('sys.symbol.paperclip'),
                    label: $r('app.string.attachment_file'),
                    value: `${attachment.name} · ${FileUtil.getFormatFileSize(attachment.size)}`,
                    clickable: false,
                  })
                }, (attachment: VaultAttachmentMeta) => attachment.name)
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
              .borderRadius($r('sys.float.corner_radius_level10'))
              .divider({
                strokeWidth: 1,
                color: $r('sys.color.grid_menu_divider_color'),
                startMargin: $r('sys.float.padding_level8'),
                endMargin: $r('sys.float.padding_level8'),
              })
              .scrollBar(BarState.Off)
            }

            if (this.customFields.length > 0) {
              List() {
                ForEach(this.customFields, (field: VaultField) => {
                  Cell({
                    icon: this.customFieldIcon(field.type),
                    label: field.name,
                    value: this.sheet.expandedCustomFields.has(field.name)
                      ? (field.value.length > 0 &&
                        (field.protected || field.type === VaultFieldType.Password) ? PASSWORD_MASK : field.value)
                      : (field.value.length > 0 &&
                        (field.protected || field.type === VaultFieldType.Password) ? PASSWORD_MASK :
                        field.value).split('\n')[0],
                    valueExpanded: this.sheet.expandedCustomFields.has(field.name),
                    clickable: field.value.length > 0,
                    onCellClick: () => this.copy(field.value),
                    showTrailingButton: this.needsExpansion(field.value),
                    trailingSymbol: this.sheet.expandedCustomFields.has(field.name)
                      ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
                    onTrailingClick: () => this.sheet.toggleCustomExpanded(field.name),
                  })
                }, (field: VaultField) => field.name)
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
              .borderRadius($r('sys.float.corner_radius_level10'))
              .divider({
                strokeWidth: 1,
                color: $r('sys.color.grid_menu_divider_color'),
                startMargin: $r('sys.float.padding_level8'),
                endMargin: $r('sys.float.padding_level8'),
              })
              .scrollBar(BarState.Off)
            }

            Row() {
              Row({ space: $r('sys.float.padding_level4') }) {
                SymbolGlyph($r('sys.symbol.label'))
                  .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
                  .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
                  .fontColor([$r('sys.color.brand')])
                Flex({
                  wrap: FlexWrap.Wrap, space: {
                    main: LengthMetrics.resource($r('sys.float.padding_level8')),
                    cross: LengthMetrics.resource($r('sys.float.padding_level8')),
                  },
                }) {
                  ForEach(this.sheet.tags, (tag: string) => {
                    ChipV2({
                      chipV2Options: new ChipV2Options({
                        label: new ChipV2Label({ text: tag }),
                        allowClose: false,
                      }),
                    })
                  }, (tag: string) => tag)
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding($r('sys.float.padding_level8'))
            }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
            .borderRadius($r('sys.float.corner_radius_level10'))
          }
          .margin({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

        }
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({ top: this.topOffset, bottom: this.bottomOffset })
        .onTouch(() => this.viewModel.recordActivity())
      }
      .width('100%')
      .height('100%')
      .id('entry_preview_scroll')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: { enableScrollEffect: false, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: { title: { mainTitle: '' }, menu: { maxCount: PREVIEW_MENU_MAX_COUNT, value: this.previewMenuItems() } },
    })
  }

  build() {
    this.previewMenu()
  }
}
