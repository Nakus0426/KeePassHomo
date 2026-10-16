import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { FileUtil, ResUtil } from '@pura/harmony-utils'
import { fileTypeIcon } from '../../model/FileTypeCatalog'

// 附件卡片：编辑态与预览态共用外观、按压反馈与长按菜单，动作由调用方注入。
@ComponentV2
export struct AttachmentCard {
  @Param name: string = ''
  // 组件基类已占用 size（通用属性），尺寸参数改名避让。
  @Param fileSize: number = 0
  // 预览态的附件必然已入库，不显示保存状态标签。
  @Param showBadge: boolean = true
  @Param persisted: boolean = true
  // 移除只属于编辑态。
  @Param editable: boolean = false
  @Event onPreview: () => void = () => {
  }
  @Event onExport: () => void = () => {
  }
  @Event onRemove: () => void = () => {
  }

  // 格式取文件扩展名大写：UTD 的 description 是带句号的文档式文案，typeId 是机器串，都不适合直出。
  private summary(): string {
    const extension: string = FileUtil.getFileExtention(this.name)
    const format: string = extension.length === 0
      ? ResUtil.getStringSync($r('app.string.attachment_format_unknown'))
      : extension.toUpperCase()
    return `${format} · ${FileUtil.getFormatFileSize(this.fileSize)}`
  }

  @Builder
  private cardMenu() {
    Menu() {
      MenuItem({
        content: $r('app.string.attachment_export'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_down_to_line')).fontSize(
          $r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.onExport())

      if (this.editable) {
        MenuItem({
          content: $r('app.string.attachment_remove'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash')).fontSize($r('sys.float.Body_L'))
            .fontColor([$r('sys.color.warning')]),
        })
          .labelFont({ size: $r('sys.float.Body_M') })
          .contentFontColor($r('sys.color.warning'))
          .onClick(() => this.onRemove())
      }
    }
    .menuItemDivider({
      strokeWidth: LengthMetrics.resource($r('sys.float.alert_divider_width')),
      color: $r('sys.color.grid_menu_divider_color'),
      startMargin: LengthMetrics.resource($r('sys.float.menu_divider_start_margin')),
      endMargin: LengthMetrics.resource($r('sys.float.menu_divider_end_margin')),
    })
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        Image(fileTypeIcon(this.name))
          .width($r('app.float.file_icon_size'))
          .height($r('app.float.file_icon_size'))
          .objectFit(ImageFit.Contain)
          // Image 默认开启长按拖拽，会抢掉卡片的长按菜单。
          .draggable(false)

        Column({ space: $r('sys.float.padding_level2') }) {
          Text(this.name)
            .width('100%')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.summary())
            .width('100%')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 标签作为行内兄弟节点占位：文件名只在剩余宽度里省略，不会压到标签上。
        if (this.showBadge) {
          Text(this.persisted ? $r('app.string.badge_saved') : $r('app.string.badge_pending'))
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.brand'))
            .alignSelf(ItemAlign.Start)
            .padding({
              left: $r('sys.float.padding_level4'),
              right: $r('sys.float.padding_level4'),
              top: $r('sys.float.padding_level2'),
              bottom: $r('sys.float.padding_level2'),
            })
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .borderRadius($r('sys.float.corner_radius_level16'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .onClick(() => this.onPreview())
    .bindContextMenu(this.cardMenu(), ResponseType.LongPress, { preview: MenuPreviewMode.IMAGE })
  }
}
