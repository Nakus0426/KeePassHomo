import { UIContext } from '@kit.ArkUI'
import { AnimationTokens } from '@ohos/common'
import { LIST_ROW_FADE_IN } from './ListRowEnterTransition'

// 离场提交：先标记收高让卡片原位塌陷，动画结束后再提交数据删除。
// 会话已关闭（切条目 / 收起面板）时不再写回，避免落在已释放的草稿上。
export function playRowLeave(uiContext: UIContext, active: boolean, markLeaving: () => void,
  commit: () => void): void {
  uiContext.animateTo({
    duration: AnimationTokens.STATE_TRANSITION_DURATION,
    curve: AnimationTokens.EASE_EXIT,
    onFinish: () => {
      if (active) {
        commit()
      }
    },
  }, markLeaving)
}

// 全项目列表行统一动效：进场淡入（可选自下方轻推），离场收高 + 后倾倒塌。
// 离场由 leaving 状态驱动而非 transition：卡片留在自己的位置塌陷，下方内容随布局上移，
// 不会脱离流布局浮到其他行之上。
const ROW_EXIT_SCALE: number = 0.92
// 绕水平轴（x）向后倒：绕 z 轴是在屏幕平面内歪，看着像向左扭曲。
const ROW_EXIT_ROTATE: number = 12
const ROW_EXIT_PERSPECTIVE: number = 800
const ROW_EXIT_ANIMATION: AnimateParam = {
  duration: AnimationTokens.STATE_TRANSITION_DURATION,
  curve: AnimationTokens.EASE_EXIT,
}

@ComponentV2
export struct DsListRowMotion {
  // 是否进入离场：由数据侧标记，动画结束后调用方再移除数据。
  @Require @Param leaving: boolean
  // 进场效果由调用方定：列表行已由 ListItem 统一淡入时传 IDENTITY，避免同一行淡入两次。
  @Param enterTransition: TransitionEffect = LIST_ROW_FADE_IN
  @BuilderParam content: () => void = this.empty

  @Builder
  private empty() {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .transition(this.enterTransition)
    .height(this.leaving ? 0 : 'auto')
    .opacity(this.leaving ? 0 : 1)
    .scale({
      x: this.leaving ? ROW_EXIT_SCALE : 1,
      y: this.leaving ? ROW_EXIT_SCALE : 1,
    })
    .rotate({
      x: 1,
      y: 0,
      z: 0,
      angle: this.leaving ? ROW_EXIT_ROTATE : 0,
      centerY: '100%',
      perspective: ROW_EXIT_PERSPECTIVE,
    })
    .clip(this.leaving)
    .animation(ROW_EXIT_ANIMATION)
  }
}
