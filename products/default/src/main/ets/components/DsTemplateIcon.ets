// 模板插画：按设计尺寸直接铺满，不加底板也不裁切。
// Image 默认开启长按拖拽，会抢掉卡片点击与长按菜单。
@ComponentV2
export struct DsTemplateIcon {
  @Require @Param source: Resource

  build() {
    Image(this.source)
      .width($r('app.float.ds_template_icon_size'))
      .height($r('app.float.ds_template_icon_size'))
      .objectFit(ImageFit.Contain)
      .draggable(false)
  }
}
