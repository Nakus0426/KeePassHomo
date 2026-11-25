import { FileUtil, ResUtil } from '@pura/harmony-utils'
import { DeferredAction } from '../../components/DeferredAction'
import { DsContextMenu, dsContextMenuOptions } from '../../components/DsContextMenu'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { DsTemplateIcon } from '../../components/DsTemplateIcon'

// 附件卡片：编辑态与预览态共用外观、按压反馈与长按菜单，动作由调用方注入。
@ComponentV2
export struct AttachmentCard {
  @Param name: string = ''
  // 组件基类已占用 size（通用属性），尺寸参数改名避让。
  @Param fileSize: number = 0
  // 移除与重命名只属于编辑态。
  @Param editable: boolean = false
  @Event onPreview: () => void = () => {
  }
  @Event onExport: () => void = () => {
  }
  @Event onRename: () => void = () => {
  }
  @Event onRemove: () => void = () => {
  }
  // 菜单退场动画结束后再触发弹窗/选择器，避免两层动效叠在一起。
  private readonly deferred: DeferredAction = new DeferredAction()

  // 格式取文件扩展名大写：UTD 的 description 是带句号的文档式文案，typeId 是机器串，都不适合直出。
  private summary(): string {
    const extension: string = FileUtil.getFileExtention(this.name)
    const format: string = extension.length === 0
      ? ResUtil.getStringSync($r('app.string.attachment_format_unknown'))
      : extension.toUpperCase()
    return `${format} · ${FileUtil.getFormatFileSize(this.fileSize)}`
  }

  @LocalBuilder
  private menuHeader() {
    Column({ space: $r('app.float.ds_space_2') }) {
      Text($r('app.string.attachment_actions'))
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
      Text($r('app.string.attachment_actions_hint'))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private menuContent() {
    DsMenuItem({
      icon: $r('app.string.symbol_eye'),
      label: $r('app.string.attachment_preview'),
      onAction: () => this.deferred.defer(() => this.onPreview()),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_download'),
      label: $r('app.string.attachment_export'),
      onAction: () => this.deferred.defer(() => this.onExport()),
    })
    if (this.editable) {
      DsMenuItem({
        icon: $r('app.string.symbol_edit'),
        label: $r('app.string.attachment_rename'),
        onAction: () => this.deferred.defer(() => this.onRename()),
      })
      DsMenuItem({
        icon: $r('app.string.symbol_delete'),
        label: $r('app.string.attachment_delete'),
        theme: DsMenuItemTheme.Error,
        onAction: () => this.deferred.defer(() => this.onRemove()),
      })
    }
  }

  @Builder
  private cardMenu() {
    DsContextMenu({
      header: this.menuHeader,
      content: this.menuContent,
    })
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('app.float.ds_space_md') }) {
        DsTemplateIcon({ source: $r('app.media.layout_type_attachment') })

        Column({ space: $r('app.float.ds_space_2') }) {
          Text(this.name)
            .width('100%')
            .fontSize($r('app.float.ds_font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.summary())
            .width('100%')
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .onClick(() => this.onPreview())
    .bindContextMenu(this.cardMenu(), ResponseType.LongPress,
      dsContextMenuOptions(() => this.deferred.run()))
  }
}
