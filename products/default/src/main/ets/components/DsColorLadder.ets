export interface DsActionColors {
  base: ResourceColor
  hover: ResourceColor
  press: ResourceColor
  onColor: ResourceColor
}

// 主色控件共用的反馈色阶梯，避免各组件各抄一份状态色。
export class DsColorLadder {
  static readonly PRIMARY: DsActionColors = {
    base: $r('app.color.ds_primary'),
    hover: $r('app.color.ds_primary_hover'),
    press: $r('app.color.ds_primary_press'),
    onColor: $r('app.color.ds_on_primary'),
  }
  static readonly RING_SUBTLE: ResourceColor = $r('app.color.ds_overlay_subtle')
  static readonly RING_MUTED: ResourceColor = $r('app.color.ds_overlay_muted')
}
