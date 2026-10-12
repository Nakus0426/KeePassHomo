import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppToast } from '@ohos/common'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { SshKeyDraft, sshKeySummary } from '../../model/SshKeyPayload'

// 预览态的 SSH 密钥卡片：只展示摘要，点按复制私钥，长按取公钥与私钥。
@ComponentV2
export struct EntrySshKeyList {
  @Param keys: SshKeyDraft[] = []
  @Event onActivity: () => void = () => {
  }
  private readonly app: AppViewModel = appViewModel

  private copy(value: string): void {
    if (value.length === 0) {
      return
    }
    this.app.copyValue(value).then((copied: boolean) => {
      if (copied) {
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
    this.onActivity()
  }

  @Builder
  private keyMenu(key: SshKeyDraft) {
    Menu() {
      MenuItem({
        content: $r('app.string.ssh_key_copy_private'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_text_on_doc_text')),
      })
        .onClick(() => this.copy(key.privateKey))

      MenuItem({
        content: $r('app.string.ssh_key_copy_public'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.key')),
      })
        .onClick(() => this.copy(key.publicKey))
    }
  }

  @Builder
  private keyCard(key: SshKeyDraft) {
    Row({ space: $r('sys.float.padding_level8') }) {
      SymbolGlyph($r('sys.symbol.key'))
        .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
        .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
        .fontColor([$r('sys.color.brand')])

      Column({ space: $r('sys.float.padding_level2') }) {
        Text(key.name)
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(sshKeySummary(key))
          .width('100%')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .borderRadius($r('sys.float.corner_radius_level10'))
    .onClick(() => this.copy(key.privateKey))
    .bindContextMenu(this.keyMenu(key), ResponseType.LongPress)
  }

  build() {
    List() {
      ForEach(this.keys, (key: SshKeyDraft) => {
        ListItem() {
          this.keyCard(key)
        }
      }, (key: SshKeyDraft) => `${key.name}`)
    }
    .width('100%')
    .height('auto')
    .padding(0)
    .scrollBar(BarState.Off)
  }
}
