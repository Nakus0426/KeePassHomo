import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { SshKeyDraft, sshKeySummary } from '../../model/SshKeyPayload'

// 密钥卡片：编辑态与预览态共用外观、按压反馈与长按菜单，动作由调用方注入。
@ComponentV2
export struct SshKeyCard {
  @Param sshKey: SshKeyDraft = new SshKeyDraft()
  // 预览态的密钥必然已入库，不显示保存状态标签。
  @Param showBadge: boolean = true
  // 重命名与删除只属于编辑态。
  @Param editable: boolean = false
  @Event onCopyPrivate: () => void = () => {
  }
  @Event onCopyPublic: () => void = () => {
  }
  @Event onExport: () => void = () => {
  }
  @Event onRename: () => void = () => {
  }
  @Event onRemove: () => void = () => {
  }

  @Builder
  private keyMenu() {
    Menu() {
      MenuItem({
        content: $r('app.string.ssh_key_copy_private'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_text_on_doc_text')).fontSize(
          $r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.onCopyPrivate())

      MenuItem({
        content: $r('app.string.ssh_key_copy_public'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.key')).fontSize($r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.onCopyPublic())

      MenuItem({
        content: $r('app.string.ssh_key_export'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_down_to_line')).fontSize(
          $r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.onExport())

      if (this.editable) {
        MenuItem({
          content: $r('app.string.ssh_key_rename'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')).fontSize(
            $r('sys.float.Body_L')),
        })
          .labelFont({ size: $r('sys.float.Body_M') })
          .onClick(() => this.onRename())

        MenuItem({
          content: $r('app.string.ssh_key_remove'),
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
      Stack({ alignContent: Alignment.TopEnd }) {
        Row({ space: $r('sys.float.padding_level8') }) {
          Stack() {
            SymbolGlyph($r('sys.symbol.key'))
              .fontSize($r('sys.float.Title_L'))
              .fontColor([$r('sys.color.brand')])
          }
          .padding($r('sys.float.padding_level4'))
          .borderRadius('50%')
          .backgroundColor($r('sys.color.comp_emphasize_secondary'))

          Column({ space: $r('sys.float.padding_level2') }) {
            Text(this.sshKey.name)
              .width('100%')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(sshKeySummary(this.sshKey))
              .width('100%')
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        if (this.showBadge) {
          Text(this.sshKey.persisted ? $r('app.string.ssh_key_badge_saved') : $r('app.string.ssh_key_badge_pending'))
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.brand'))
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
    .onClick(() => this.onCopyPrivate())
    .bindContextMenu(this.keyMenu(), ResponseType.LongPress, { preview: MenuPreviewMode.IMAGE })
  }
}
