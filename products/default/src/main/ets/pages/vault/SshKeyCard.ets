import { SshKeyDraft, sshKeySummary } from '../../model/SshKeyPayload'
import { sshPublicKeyFingerprint } from '../../model/SshFingerprint'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { DsContextMenu } from '../../components/DsContextMenu'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { DsTag } from '../../components/DsTag'

const ICON_TILE_SIZE: number = 32

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

  // 指纹只由公钥行派生，不写回受保护字段。
  @Computed
  get fingerprint(): string {
    return sshPublicKeyFingerprint(this.sshKey.publicKey)
  }

  @LocalBuilder
  private menuHeader() {
    Column({ space: $r('app.float.ds_space_2') }) {
      Text($r('app.string.ssh_key_actions'))
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
      Text($r('app.string.ssh_key_actions_hint'))
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
      icon: $r('app.string.symbol_docs'),
      label: $r('app.string.ssh_key_copy_private'),
      onAction: () => this.onCopyPrivate(),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_key'),
      label: $r('app.string.ssh_key_copy_public'),
      onAction: () => this.onCopyPublic(),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_download'),
      label: $r('app.string.ssh_key_export'),
      onAction: () => this.onExport(),
    })
    if (this.editable) {
      DsMenuItem({
        icon: $r('app.string.symbol_edit'),
        label: $r('app.string.ssh_key_rename'),
        onAction: () => this.onRename(),
      })
      DsMenuItem({
        icon: $r('app.string.symbol_delete'),
        label: $r('app.string.ssh_key_remove'),
        theme: DsMenuItemTheme.Error,
        onAction: () => this.onRemove(),
      })
    }
  }

  @Builder
  private keyMenu() {
    DsContextMenu({
      header: this.menuHeader,
      content: this.menuContent,
    })
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('app.float.ds_space_md') }) {
        Row() {
          SymbolGlyph($r('app.string.symbol_key'))
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([$r('app.color.ds_text_primary')])
            .foregroundColor($r('app.color.ds_text_primary'))
        }
        .width(ICON_TILE_SIZE)
        .height(ICON_TILE_SIZE)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.ds_surface_high'))

        Column({ space: $r('app.float.ds_space_2') }) {
          Text(this.sshKey.name)
            .width('100%')
            .fontSize($r('app.float.ds_font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(sshKeySummary(this.sshKey))
            .width('100%')
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.fingerprint.length > 0) {
            Text($r('app.string.ssh_key_fingerprint', this.fingerprint))
              .width('100%')
              .fontSize($r('app.float.ds_font_micro'))
              .fontFamily(PASSWORD_FONT_FAMILY)
              .fontColor($r('app.color.ds_text_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 标签作为行内兄弟节点占位：名称只在剩余宽度里省略，不会压到标签上。
        if (this.showBadge) {
          DsTag({
            text: this.sshKey.persisted ? $r('app.string.badge_saved') : $r('app.string.badge_pending'),
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .onClick(() => this.onCopyPrivate())
    .bindContextMenu(this.keyMenu(), ResponseType.LongPress, {
      preview: MenuPreviewMode.IMAGE,
      hapticFeedbackMode: HapticFeedbackMode.ENABLED,
    })
  }
}
