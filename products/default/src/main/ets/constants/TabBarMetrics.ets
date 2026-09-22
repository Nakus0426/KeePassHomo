/**
 * 悬浮底部页签几何：页签由 AppShell 的 barFloatingStyle 悬浮在窗口底之上，
 * 页面据此推算底部内容让位。
 */

/** 悬浮页签与窗口底边的留白，对应 AppShell barFloatingStyle.barBottomMargin。 */
export const TAB_BAR_FLOAT_BOTTOM_MARGIN_VP: number = 28

/** 悬浮页签玻璃容器高度：页签行 48vp 加玻璃上下内边距各 4vp。 */
export const TAB_BAR_FLOAT_HEIGHT_VP: number = 56

/** 悬浮页签玻璃容器顶端距窗口底边的距离，即页面内容底部须让开的区域高度。 */
export const TAB_BAR_FLOAT_TOP_INSET_VP: number = TAB_BAR_FLOAT_BOTTOM_MARGIN_VP + TAB_BAR_FLOAT_HEIGHT_VP
