import { LengthMetrics } from '@kit.ArkUI'

// ArkUI 菜单容器固定 4vp 内边距，负边距须按实际值补偿。
const MENU_SYSTEM_INSET: number = 4
const MENU_TARGET_SPACE: number = 4

// 全项目长按菜单统一承载参数：直角预览 + 设计系统面底 + 模糊遮罩。
// 宿主 bindContextMenu 必须使用本函数，不要在调用处手写视觉参数。
export function dsContextMenuOptions(onDisappear: () => void, placement?: Placement): ContextMenuOptions {
  const options: ContextMenuOptions = {
    preview: MenuPreviewMode.IMAGE,
    previewBorderRadius: $r('app.float.ds_radius_none'),
    borderRadius: $r('app.float.ds_radius_none'),
    backgroundColor: $r('app.color.ds_surface_lowest'),
    backgroundBlurStyle: BlurStyle.NONE,
    targetSpace: LengthMetrics.vp(MENU_TARGET_SPACE),
    hapticFeedbackMode: HapticFeedbackMode.ENABLED,
    onDisappear: onDisappear,
    mask: {
      color: $r('app.color.ds_scrim_blur'),
      backgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
    },
  }
  if (placement !== undefined) {
    options.placement = placement
  }
  return options
}

@ComponentV2
export struct DsContextMenu {
  @BuilderParam header: () => void = this.empty
  @BuilderParam content: () => void = this.empty
  @BuilderParam footer: () => void = this.empty

  @Builder
  private empty() {
  }

  build() {
    // 空 Footer 与列间距已留出末项下边距；再叠加 padding 会与分隔线后的上边距不一致。
    Column({ space: $r('app.float.ds_space_sm') }) {
      Column() {
        this.header()
      }
      .width('100%')

      Column({ space: $r('app.float.ds_space_sm') }) {
        this.content()
      }
      .width('100%')

      Column() {
        this.footer()
      }
      .width('100%')
    }
    .width($r('app.float.ds_context_menu_content_width'))
    .backgroundColor($r('app.color.ds_surface_lowest'))
    .clip(true)
    .margin({
      left: -MENU_SYSTEM_INSET,
      right: -MENU_SYSTEM_INSET,
      top: -MENU_SYSTEM_INSET,
      bottom: -MENU_SYSTEM_INSET,
    })
  }
}
