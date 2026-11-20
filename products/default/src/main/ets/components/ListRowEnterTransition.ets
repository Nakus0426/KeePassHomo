import { AnimationTokens } from '@ohos/common'

// 列表行进场：滚动中挂载的行只淡入，新建的行额外自下方轻推入位。
// 与离场形态（DsListRowMotion）分开，编辑态等不参与离场的场景也能复用。
export const LIST_ROW_ENTER_OFFSET_VP: number = 8

export const LIST_ROW_FADE_IN: TransitionEffect = TransitionEffect.OPACITY
  .animation(AnimationTokens.FEEDBACK_ANIMATION)

export const LIST_ROW_PUSH_IN: TransitionEffect = TransitionEffect.OPACITY
  .combine(TransitionEffect.translate({ y: LIST_ROW_ENTER_OFFSET_VP }))
  .animation(AnimationTokens.FEEDBACK_ANIMATION)
