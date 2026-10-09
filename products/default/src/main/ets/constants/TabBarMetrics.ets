// 悬浮底部页签几何：页签由 AppShell 的 barFloatingStyle 悬浮在窗口底之上，页面据此推算底部内容让位

// 对应 AppShell barFloatingStyle.barBottomMargin
export const TAB_BAR_FLOAT_BOTTOM_MARGIN_VP: number = 28

// HDS 页签行 48vp 加玻璃上下内边距各 4vp
export const TAB_BAR_FLOAT_HEIGHT_VP: number = 56

// 页面内容底部须让开的高度
export const TAB_BAR_FLOAT_TOP_INSET_VP: number = TAB_BAR_FLOAT_BOTTOM_MARGIN_VP + TAB_BAR_FLOAT_HEIGHT_VP
