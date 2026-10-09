import { AnimationTokens } from '@ohos/common'

/** 滑动操作按钮宽度：ListItem 划出组件没有对应的系统尺寸 token，取图标加两侧内边距的固定宽度。 */
const SWIPE_ACTION_WIDTH_VP: number = 64

/**
 * 行重排位移记录：ForEach 按 uuid 复用节点，换词后行只是换了下标——属于布局变化，没有动画，
 * 于是看到「命中行瞬间跳到顶部」。换词时让行重建（key 带版本号），再把
 * 「上一轮下标 − 当前下标」折算成位移写进入场转场：转场本身带起始状态，不需要跨帧调度。
 */
export class GroupRowShift {
  private previousOrder: string[] = []
  private rowHeightVp: number = 0

  /** 换词瞬间记下上一轮的可见顺序（按渲染下标）。 */
  beginSwap(previousOrder: string[]): void {
    this.previousOrder = previousOrder
  }

  /**
   * 行高由行自身实测上报：副行恒为单行，全表行高一致，任一行的高度都可用。
   * 字段不参与观察，写入不会触发重绘。
   */
  reportRowHeight(heightVp: number): void {
    this.rowHeightVp = heightVp
  }

  /** 该行本轮应从哪里滑入：不在上一轮里（新命中）或行高未知时为 0，走普通淡入。 */
  shiftOf(uuid: string, index: number): number {
    const oldIndex: number = this.previousOrder.indexOf(uuid)
    if (oldIndex < 0 || oldIndex === index || this.rowHeightVp === 0) {
      return 0
    }
    return (oldIndex - index) * this.rowHeightVp
  }
}

/**
 * 分组行转场，口径对齐首页条目卡片：新行由小放大淡入（CARD_ENTER_SCALE），
 * 离开的行缩小淡出（CARD_EXIT_SCALE）；换词后仍在表内的行不做缩放，
 * 只从 shiftVp 指定的旧位置滑到新位置，读起来就是「这一行挪了地方」。
 */
export function groupRowTransition(shiftVp: number): TransitionEffect {
  const enterOpacity: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  const enter: TransitionEffect = shiftVp === 0
    ? enterOpacity.combine(TransitionEffect.scale({
      x: AnimationTokens.CARD_ENTER_SCALE,
      y: AnimationTokens.CARD_ENTER_SCALE,
    }))
    : enterOpacity.combine(TransitionEffect.translate({ y: shiftVp }))
  const exit: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
    .combine(TransitionEffect.scale({
      x: AnimationTokens.CARD_EXIT_SCALE,
      y: AnimationTokens.CARD_EXIT_SCALE,
    }))
  return TransitionEffect.asymmetric(enter, exit)
}

/**
 * 分组行：文件夹图标 + 组名 + 副行，支持左滑编辑/删除与出场收缩。
 * 供分组选择器与分组管理页共用，行只渲染入参，不感知数据来源与删除流程。
 */
@ComponentV2
export struct GroupRow {
  @Require @Param name: string
  @Require @Param subtitle: string
  @Param selected: boolean = false
  @Param showChevron: boolean = true
  /** 只读保险库与根分组不提供滑动操作，策略与首页条目卡片一致。 */
  @Param actionsEnabled: boolean = false
  /** 删除动画进行中：行高收 0 并缩淡，动画结束后宿主才落盘。 */
  @Param removing: boolean = false
  @Event onRowClick: () => void = () => {
  }
  @Event onEdit: () => void = () => {
  }
  @Event onDelete: () => void = () => {
  }

  /** 左滑划出项：编辑与删除两个图标按钮，顶层必须是单个组件。 */
  @Builder
  private swipeActions() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.square_and_pencil'))
          .fontSize($r('sys.float.titlebar_icon_width'))
          .fontColor([$r('sys.color.icon_on_primary')])
      }
      .width(SWIPE_ACTION_WIDTH_VP)
      .height('100%')
      .backgroundColor($r('sys.color.brand'))
      .onClick(() => this.onEdit())

      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize($r('sys.float.titlebar_icon_width'))
          .fontColor([$r('sys.color.icon_on_primary')])
      }
      .width(SWIPE_ACTION_WIDTH_VP)
      .height('100%')
      .backgroundColor($r('sys.color.warning'))
      .onClick(() => this.onDelete())
    }
    .height('100%')
  }

  build() {
    ListItem() {
      Row({ space: $r('sys.float.padding_level8') }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.folder'))
            .fontSize($r('sys.float.Title_L'))
            .fontColor([$r('sys.color.brand')])
        }
        .padding($r('sys.float.padding_level4'))
        .borderRadius('50%')
        .backgroundColor($r('sys.color.comp_emphasize_secondary'))

        Column({ space: $r('sys.float.padding_level2') }) {
          Text(this.name)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.selected) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize($r('sys.float.Title_S'))
            .fontColor([$r('sys.color.confirm')])
        } else if (this.showChevron) {
          SymbolGlyph($r('sys.symbol.chevron_forward'))
            .fontSize($r('sys.float.Title_S'))
            .fontColor([$r('sys.color.font_secondary')])
        }
      }
      .width('100%')
      .padding($r('sys.float.padding_level8'))
      .backgroundColor(this.selected ? $r('sys.color.comp_emphasize_secondary') : Color.Transparent)
      .stateStyles({
        pressed: {
          .backgroundColor($r('sys.color.interactive_pressed'))
        },
      })
      .onClick(() => this.onRowClick())
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
    // 出场对齐首页卡片：高度收 0 让后续行随布局动画上移，数据移除时已不可见，故不跳动。
    .height(this.removing ? 0 : 'auto')
    .opacity(this.removing ? 0 : 1)
    .scale({
      x: this.removing ? AnimationTokens.CARD_EXIT_SCALE : 1,
      y: this.removing ? AnimationTokens.CARD_EXIT_SCALE : 1,
    })
    .clip(this.removing)
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
    .swipeAction({
      end: this.actionsEnabled ? () => {
        this.swipeActions()
      } : undefined,
      edgeEffect: SwipeEdgeEffect.None,
    })
  }
}
