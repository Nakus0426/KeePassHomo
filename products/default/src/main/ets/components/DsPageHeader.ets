import { DsButton, DsButtonVariant } from './DsButton'
import { DsControlSize } from './DsControlSize'

export enum DsPageHeaderSize {
  Small = 'sm',
  Medium = 'md',
  Large = 'lg',
}

export const DS_PAGE_HEADER_HEIGHT_VP: number = 76

export interface DsPageHeaderAction {
  icon: Resource
  label: Resource
  enabled?: boolean
  // 缺省用 text_primary；收藏等切换态需要单独指定选中色。
  iconColor?: ResourceColor
  onTap: () => void
}

@ComponentV2
export struct DsPageHeader {
  @Param title: ResourceStr = ''
  @Param titleTransitionKey: string = ''
  @Param scrollOverflowingTitle: boolean = false
  @Param subtitle: ResourceStr | undefined = undefined
  @Param headerSize: DsPageHeaderSize = DsPageHeaderSize.Large
  @Param showBack: boolean = true
  // 半模态页头：关闭按钮固定在动作区最右，是弹窗唯一的可见关闭入口。
  @Param showClose: boolean = false
  @Param closeEnabled: boolean = true
  @Param actions: DsPageHeaderAction[] = []
  @BuilderParam titleBuilder?: () => void
  // 动作区前置的自定义控件：动作带切换动效（收藏等）时图标按钮表达不了，渲染在 actions 之前。
  @BuilderParam actionsBuilder?: () => void
  @Event onBack: () => void = () => {
  }
  @Event onClose: () => void = () => {
  }

  @Computed
  get headerHeight(): Resource {
    switch (this.headerSize) {
      case DsPageHeaderSize.Small:
        return $r('app.float.ds_page_header_height_sm')
      case DsPageHeaderSize.Medium:
        return $r('app.float.ds_page_header_height_md')
      default:
        return $r('app.float.ds_page_header_height_lg')
    }
  }

  @Computed
  get verticalPadding(): Resource {
    switch (this.headerSize) {
      case DsPageHeaderSize.Small:
        return $r('app.float.ds_page_header_padding_sm')
      case DsPageHeaderSize.Medium:
        return $r('app.float.ds_page_header_padding_md')
      default:
        return $r('app.float.ds_page_header_padding_lg')
    }
  }

  // 页头动作统一 44 方形图标按钮。
  @LocalBuilder
  private headerAction(action: DsPageHeaderAction) {
    DsButton({
      variant: DsButtonVariant.Text,
      buttonSize: DsControlSize.Medium,
      iconOnly: true,
      leadingIcon: action.icon,
      iconSizeOverride: $r('app.float.ds_icon_md'),
      iconColorOverride: action.iconColor ?? $r('app.color.ds_text_primary'),
      accessibilityLabelResource: action.label,
      disabled: action.enabled === false,
      onTap: action.onTap,
    })
  }

  @Computed
  get titleFontSize(): Resource {
    switch (this.headerSize) {
      case DsPageHeaderSize.Small:
        return $r('app.float.ds_font_headline_md')
      case DsPageHeaderSize.Medium:
        return $r('app.float.ds_font_headline')
      default:
        return $r('app.float.ds_font_display')
    }
  }

  @Computed
  get titleLetterSpacing(): number {
    switch (this.headerSize) {
      case DsPageHeaderSize.Small:
        return -0.15
      case DsPageHeaderSize.Medium:
        return -0.3
      default:
        return -0.7
    }
  }

  @LocalBuilder
  private primaryTitle() {
    Text(this.title)
      .fontSize(this.titleFontSize)
      .fontWeight(600)
      .fontColor($r('app.color.ds_text_primary'))
      .letterSpacing(this.titleLetterSpacing)
      .maxLines(1)
      .textOverflow({ overflow: this.scrollOverflowingTitle ? TextOverflow.MARQUEE : TextOverflow.Ellipsis })
      .marqueeOptions({ start: this.scrollOverflowingTitle, fadeout: this.scrollOverflowingTitle })
      .transition(this.titleTransitionKey.length > 0 ? TransitionEffect.OPACITY : TransitionEffect.IDENTITY)
  }

  build() {
    Row() {
      Row({ space: $r('app.float.ds_space_sm') }) {
        if (this.showBack) {
          DsButton({
            variant: DsButtonVariant.Text,
            // 页头图标按钮统一 44 / 20：pen 半模态页头同为 56 高 + 44 方形按钮。
            buttonSize: DsControlSize.Medium,
            iconOnly: true,
            leadingIcon: $r('app.string.symbol_arrow_back'),
            iconSizeOverride: $r('app.float.ds_icon_md'),
            iconColorOverride: $r('app.color.ds_text_primary'),
            accessibilityLabelResource: $r('app.string.back'),
            onTap: () => this.onBack(),
          })
        }

        if (this.titleBuilder !== undefined) {
          Column() {
            this.titleBuilder()
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        } else {
          Column({ space: 3 }) {
            if (this.titleTransitionKey.length > 0) {
              Stack({ alignContent: Alignment.Start }) {
                ForEach([this.titleTransitionKey], (_key: string) => {
                  this.primaryTitle()
                }, (key: string) => key)
              }
              .width('100%')
            } else {
              this.primaryTitle()
            }
            if (this.subtitle !== undefined) {
              Text(this.subtitle)
                .fontSize($r('app.float.ds_font_label_sm'))
                .fontWeight(500)
                .fontColor($r('app.color.ds_text_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }

        if (this.actionsBuilder !== undefined || this.actions.length > 0 || this.showClose) {
          Row({ space: $r('app.float.ds_space_sm') }) {
            if (this.actionsBuilder !== undefined) {
              this.actionsBuilder()
            }
            ForEach(this.actions, (action: DsPageHeaderAction, index: number) => {
              this.headerAction(action)
            }, (_action: DsPageHeaderAction, index: number) => index.toString())

            if (this.showClose) {
              this.headerAction({
                icon: $r('app.string.symbol_close'),
                label: $r('app.string.close'),
                enabled: this.closeEnabled,
                onTap: () => this.onClose(),
              })
            }
          }
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.headerHeight)
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      top: this.verticalPadding,
      bottom: this.verticalPadding,
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
