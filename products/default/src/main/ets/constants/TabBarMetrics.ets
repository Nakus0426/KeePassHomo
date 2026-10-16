// 悬浮底部页签几何：页签由 AppShell 的 barFloatingStyle 悬浮在窗口底之上，页面据此推算底部内容让位

// 对应 AppShell barFloatingStyle.barBottomMargin
export const TAB_BAR_FLOAT_BOTTOM_MARGIN_VP: number = 28

// HDS 页签行 48vp 加玻璃上下内边距各 4vp
export const TAB_BAR_FLOAT_HEIGHT_VP: number = 56

// 页面内容底部须让开的高度
export const TAB_BAR_FLOAT_TOP_INSET_VP: number = TAB_BAR_FLOAT_BOTTOM_MARGIN_VP + TAB_BAR_FLOAT_HEIGHT_VP

// 页签图标槽位边长：位图内容只占画布约 87%，取 26vp 才能与内置 symbol 的墨迹大小一致
export const TAB_ICON_SIZE_VP: number = 26

// 页签图标与文字间距，对齐内置底部页签的实测视觉间距
export const TAB_ICON_LABEL_GAP_VP: number = 2

// 页签文字字号：HDS 内置底部页签默认 10fp，实测旧版墨迹与 12fp 之比恰为 12/10
export const TAB_LABEL_FONT_SIZE_FP: number = 10
