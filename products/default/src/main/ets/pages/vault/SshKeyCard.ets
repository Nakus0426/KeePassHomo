import { SshKeyDraft, sshKeySummary } from '../../model/SshKeyPayload'
import { sshPublicKeyFingerprint } from '../../model/SshFingerprint'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { DeferredAction } from '../../components/DeferredAction'
import { DsContextMenu, dsContextMenuOptions } from '../../components/DsContextMenu'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { DsTemplateIcon } from '../../components/DsTemplateIcon'

// 密钥卡片：编辑态与预览态共用外观、按压反馈与长按菜单，动作由调用方注入。
@ComponentV2
export struct SshKeyCard {
  @Param sshKey: SshKeyDraft = new SshKeyDraft()
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
  // 导出、重命名与删除会打开弹窗/选择器，等菜单退场后再触发。
  private readonly deferred: DeferredAction = new DeferredAction()

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
      icon: $r('app.string.symbol_copy'),
      label: $r('app.string.ssh_key_copy_private'),
      onAction: () => this.onCopyPrivate(),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_copy'),
      label: $r('app.string.ssh_key_copy_public'),
      onAction: () => this.onCopyPublic(),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_download'),
      label: $r('app.string.ssh_key_export'),
      onAction: () => this.deferred.defer(() => this.onExport()),
    })
    if (this.editable) {
      DsMenuItem({
        icon: $r('app.string.symbol_edit'),
        label: $r('app.string.ssh_key_rename'),
        onAction: () => this.deferred.defer(() => this.onRename()),
      })
      DsMenuItem({
        icon: $r('app.string.symbol_delete'),
        label: $r('app.string.ssh_key_remove'),
        theme: DsMenuItemTheme.Error,
        onAction: () => this.deferred.defer(() => this.onRemove()),
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
        DsTemplateIcon({ source: $r('app.media.layout_type_ssh_key') })

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
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .bindContextMenu(this.keyMenu(), ResponseType.LongPress,
      dsContextMenuOptions(() => this.deferred.run()))
  }
}
