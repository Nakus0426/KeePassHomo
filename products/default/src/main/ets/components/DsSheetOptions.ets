import { LengthMetrics } from '@kit.ArkUI'

const SHEET_RADIUS: LengthMetrics = LengthMetrics.vp(0)
const TOP_BORDER_WIDTH: LengthMetrics = LengthMetrics.vp(1)
// 注册 onWillDismiss 后默认「先回弹到原位、再关闭」；不调用 springBack 取消回弹，直接从当前位置下滑关闭。
const CANCEL_SPRING_BACK: Callback<SpringBackAction> = (_action: SpringBackAction): void => {
}

// 半模态容器参数按各宿主实际用到的字段收敛；新增字段先在这里加，再改调用方。
export interface DsSheetOptionsParams {
  detents?: [(SheetSize | Length), (SheetSize | Length)?, (SheetSize | Length)?]
  scrollSizeMode?: ScrollSizeMode
  onHeightDidChange?: Callback<number>
  onWillDismiss?: Callback<DismissSheetAction>
  onAppear?: () => void
  onDisappear?: () => void
  // 沉浸式预览需要顶部一条分隔描边，其余半模态不描边。
  topBorder?: boolean
  // 多档位时系统控制条会与该页自绘拖拽条叠加，且样式不受设计系统控制；置 false 只显示自绘那根。
  dragBar?: boolean
  keyboardAvoidMode?: SheetKeyboardAvoidMode
}

// 全项目半模态统一容器参数：直角面板 + 设计系统面底 + 无系统关闭按钮。
// 宿主 bindSheet 必须使用本函数，不要在调用处手写 radius / backgroundColor。
export function dsSheetOptions(params: DsSheetOptionsParams): SheetOptions {
  const options: SheetOptions = {
    // 默认保留系统拖拽条手势区域（MODAL 标题栏下不可见），视觉拖拽条由 DsHalfModalSheet 自绘。
    dragBar: params.dragBar ?? true,
    showClose: false,
    backgroundColor: $r('app.color.ds_surface_lowest'),
    radius: SHEET_RADIUS,
    detents: params.detents,
    scrollSizeMode: params.scrollSizeMode,
    onHeightDidChange: params.onHeightDidChange,
    onWillDismiss: params.onWillDismiss,
    onAppear: params.onAppear,
    onDisappear: params.onDisappear,
    keyboardAvoidMode: params.keyboardAvoidMode,
    onWillSpringBackWhenDismiss: CANCEL_SPRING_BACK,
  }
  if (params.topBorder === true) {
    options.borderWidth = { top: TOP_BORDER_WIDTH }
    options.borderColor = { top: $r('app.color.ds_outline_variant') }
  }
  return options
}
