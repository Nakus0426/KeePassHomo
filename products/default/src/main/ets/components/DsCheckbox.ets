import { AnimationTokens } from '@ohos/common'

// 方形复选指示：单选触控由宿主持有，本组件只画选中态。
@ComponentV2
export struct DsCheckbox {
  @Param checked: boolean = false

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.checked) {
        SymbolGlyph($r('app.string.symbol_check'))
          .fontSize($r('app.float.ds_checkbox_check_size'))
          .fontColor([$r('app.color.ds_on_primary')])
          .foregroundColor($r('app.color.ds_on_primary'))
      }
    }
    .width($r('app.float.ds_icon_xs'))
    .height($r('app.float.ds_icon_xs'))
    .backgroundColor(this.checked ? $r('app.color.ds_primary') : $r('app.color.ds_surface_hover'))
    .borderRadius($r('app.float.ds_radius_none'))
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
  }
}
