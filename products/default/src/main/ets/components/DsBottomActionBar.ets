import { immersiveLayoutState, ImmersiveLayoutState } from '../state/ImmersiveLayoutState'

const BOTTOM_SAFE_AREA_GAP_VP: number = 8

@ComponentV2
export struct DsBottomActionBar {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Param surfaceColor: ResourceColor = $r('app.color.ds_surface_canvas')
  @Param fadeColor: ResourceColor = $r('app.color.ds_surface_canvas_transparent')
  // 生成器页底栏位于悬浮导航栏之上，由外层留出导航高度，不再叠加底部安全区。
  @Param includeSafeArea: boolean = true
  @BuilderParam contentBuilder: () => void
  @Event onHeightChange: (height: number) => void = () => {
  }

  @Computed
  get bottomInset(): number {
    return this.includeSafeArea
      ? this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx) + BOTTOM_SAFE_AREA_GAP_VP
      : BOTTOM_SAFE_AREA_GAP_VP
  }

  build() {
    Column() {
      this.contentBuilder()
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_lg'),
      bottom: this.bottomInset,
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    // 完全透明的端点会被按不透明黑色处理，Token 使用 1/255 透明度保留底色。
    .linearGradient({
      angle: 180,
      colors: [
        [this.fadeColor, 0],
        [this.surfaceColor, 1],
      ],
    })
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.onHeightChange(newValue.height as number)
    })
  }
}
