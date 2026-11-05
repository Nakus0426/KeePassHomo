import { LengthMetrics } from '@kit.ArkUI'
import { AnimationTokens } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { DsButton, DsButtonSize, DsButtonVariant } from './DsButton'

export enum DsBreadcrumbSize {
  Small = 'small',
  Medium = 'medium',
  Large = 'large',
}

export interface DsBreadcrumbItemData {
  key: string
  label: ResourceStr
  icon?: Resource
  disabled?: boolean
}

// 增删项横移量取固定值：不依赖运行时测量单项宽度，仍能表达从左进入、向左退出的位移。
const ITEM_MOTION_OFFSET: number = 16

@ComponentV2
export struct DsBreadcrumbSeparator {
  @Param breadcrumbSize: DsBreadcrumbSize = DsBreadcrumbSize.Medium

  @Computed
  get fontSize(): Resource {
    switch (this.breadcrumbSize) {
      case DsBreadcrumbSize.Small:
        return $r('app.float.ds_font_label_sm')
      case DsBreadcrumbSize.Large:
        return $r('app.float.ds_font_title')
      default:
        return $r('app.float.ds_font_body')
    }
  }

  build() {
    Text('/')
      .fontSize(this.fontSize)
      .fontColor($r('app.color.ds_text_tertiary'))
      .padding({
        left: $r('app.float.ds_space_sm'),
        right: $r('app.float.ds_space_sm'),
      })
  }
}

@ComponentV2
export struct DsBreadcrumbItem {
  @Param label: ResourceStr = ''
  @Param icon: Resource | undefined = undefined
  @Param breadcrumbSize: DsBreadcrumbSize = DsBreadcrumbSize.Medium
  // 当前层：主文字色、加粗、不可点。
  @Param active: boolean = false
  @Param disabled: boolean = false
  // 提供后替换默认文本，用于自定义插槽内容。
  @BuilderParam contentBuilder?: () => void
  @Event onTap: () => void = () => {
  }

  @Computed
  get controlHeight(): Resource {
    switch (this.breadcrumbSize) {
      case DsBreadcrumbSize.Small:
        return $r('app.float.ds_breadcrumb_height_sm')
      case DsBreadcrumbSize.Large:
        return $r('app.float.ds_breadcrumb_height_lg')
      default:
        return $r('app.float.ds_breadcrumb_height_md')
    }
  }

  @Computed
  get iconSize(): Resource {
    switch (this.breadcrumbSize) {
      case DsBreadcrumbSize.Small:
        return $r('app.float.ds_breadcrumb_icon_sm')
      case DsBreadcrumbSize.Large:
        return $r('app.float.ds_breadcrumb_icon_lg')
      default:
        return $r('app.float.ds_breadcrumb_icon_md')
    }
  }

  @Computed
  get labelSize(): Resource {
    switch (this.breadcrumbSize) {
      case DsBreadcrumbSize.Small:
        return $r('app.float.ds_font_label_sm')
      case DsBreadcrumbSize.Large:
        return $r('app.float.ds_font_title')
      default:
        return $r('app.float.ds_font_body')
    }
  }

  @Computed
  get horizontalPadding(): Resource {
    switch (this.breadcrumbSize) {
      case DsBreadcrumbSize.Small:
        return $r('app.float.ds_space_xs')
      case DsBreadcrumbSize.Large:
        return $r('app.float.ds_space_sm')
      default:
        return $r('app.float.ds_space_6')
    }
  }

  @Computed
  get textColor(): ResourceColor {
    if (this.disabled) {
      return $r('app.color.ds_text_disabled')
    }
    return this.active ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_secondary')
  }

  @Computed
  get labelWeight(): number {
    return this.active ? 600 : 500
  }

  @Computed
  get accessibilityLabelText(): string {
    return typeof this.label === 'string' ? this.label : ResUtil.getStringSync(this.label as Resource)
  }

  @LocalBuilder
  private defaultLabel() {
    Text(this.label)
      .fontSize(this.labelSize)
      .fontWeight(this.labelWeight)
      .fontColor(this.textColor)
      .letterSpacing(0.2)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @LocalBuilder
  private itemContent() {
    if (this.contentBuilder !== undefined) {
      this.contentBuilder()
    } else {
      this.defaultLabel()
    }
  }

  build() {
    DsButton({
      variant: DsButtonVariant.Text,
      buttonSize: DsButtonSize.Medium,
      controlHeightOverride: this.controlHeight,
      iconSizeOverride: this.iconSize,
      leadingIcon: this.icon,
      iconColorOverride: this.textColor,
      horizontalPaddingOverride: this.horizontalPadding,
      disabled: this.disabled,
      accessibilityLabel: this.accessibilityLabelText,
      contentBuilder: this.itemContent,
      onTap: () => {
        if (this.disabled || this.active) {
          return
        }
        this.onTap()
      },
    })
  }
}

@ComponentV2
export struct DsBreadcrumb {
  @Param items: DsBreadcrumbItemData[] = []
  @Param breadcrumbSize: DsBreadcrumbSize = DsBreadcrumbSize.Medium
  @Param disabled: boolean = false
  @Event onSelect: (index: number) => void = () => {
  }

  // 副本驱动渲染：items 变化时在 animateTo 内更新，ForEach 的增删才会播放 transition。
  @Local private rendered: DsBreadcrumbItemData[] = []
  private readonly itemTransition: TransitionEffect = TransitionEffect.asymmetric(
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: -ITEM_MOTION_OFFSET }))
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }),
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: -ITEM_MOTION_OFFSET }))
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }),
  )

  aboutToAppear(): void {
    this.rendered = this.items.slice()
  }

  @Monitor('items')
  onItemsChanged(): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.rendered = this.items.slice()
    })
  }

  build() {
    Scroll() {
      Row() {
        ForEach(this.rendered, (item: DsBreadcrumbItemData, index: number) => {
          Row() {
            if (index > 0) {
              DsBreadcrumbSeparator({ breadcrumbSize: this.breadcrumbSize })
            }
            DsBreadcrumbItem({
              label: item.label,
              icon: item.icon,
              breadcrumbSize: this.breadcrumbSize,
              active: index === this.rendered.length - 1,
              disabled: this.disabled || item.disabled === true,
              onTap: () => {
                if (index < this.rendered.length - 1) {
                  this.onSelect(index)
                }
              },
            })
          }
          .transition(this.itemTransition)
        }, (item: DsBreadcrumbItemData) => item.key)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .fadingEdge(true, { fadingEdgeLength: LengthMetrics.resource($r('app.float.ds_space_sm')) })
  }
}
