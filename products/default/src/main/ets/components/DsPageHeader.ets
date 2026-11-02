import { DsButton, DsButtonSize, DsButtonVariant } from './DsButton'

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
  onTap: () => void
}

@ComponentV2
export struct DsPageHeader {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Param headerSize: DsPageHeaderSize = DsPageHeaderSize.Large
  @Param showBack: boolean = true
  @Param actions: DsPageHeaderAction[] = []
  @BuilderParam titleBuilder?: () => void
  @Event onBack: () => void = () => {
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

  // 标题栏内的图标按钮跟随标题栏档位：Small 用更小的按钮与图标，避免盖过标题栏。
  @Computed
  get iconButtonSize(): DsButtonSize {
    return this.headerSize === DsPageHeaderSize.Small ? DsButtonSize.Small : DsButtonSize.Medium
  }

  @Computed
  get iconSize(): Resource {
    return this.headerSize === DsPageHeaderSize.Small ? $r('app.float.ds_icon_sm') : $r('app.float.ds_icon_md')
  }

  build() {
    Row() {
      Row({ space: $r('app.float.ds_space_sm') }) {
        if (this.showBack) {
          DsButton({
            variant: DsButtonVariant.Text,
            buttonSize: this.iconButtonSize,
            iconOnly: true,
            leadingIcon: $r('app.string.symbol_arrow_back'),
            iconSizeOverride: this.iconSize,
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
            Text(this.title)
              .fontSize(this.titleFontSize)
              .fontWeight(600)
              .fontColor($r('app.color.ds_text_primary'))
              .letterSpacing(this.titleLetterSpacing)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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

        if (this.actions.length > 0) {
          Row({ space: $r('app.float.ds_space_sm') }) {
            ForEach(this.actions, (action: DsPageHeaderAction, index: number) => {
              DsButton({
                variant: DsButtonVariant.Text,
                buttonSize: this.iconButtonSize,
                iconOnly: true,
                leadingIcon: action.icon,
                iconSizeOverride: this.iconSize,
                iconColorOverride: $r('app.color.ds_text_primary'),
                accessibilityLabelResource: action.label,
                disabled: action.enabled === false,
                onTap: action.onTap,
              })
            }, (_action: DsPageHeaderAction, index: number) => index.toString())
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
