import { AppToast } from '@ohos/common'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { SshKeyDraft } from '../../model/SshKeyPayload'
import { exportSshPrivateKey } from '../../model/SshKeyExport'
import { SshKeyCard } from './SshKeyCard'

// 预览态的 SSH 密钥卡片列表：卡片与编辑态共用 SshKeyCard，只注入预览态可用的动作。
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

  build() {
    Column({ space: $r('sys.float.padding_level8') }) {
      ForEach(this.keys, (key: SshKeyDraft) => {
        SshKeyCard({
          sshKey: key,
          showBadge: false,
          onCopyPrivate: () => this.copy(key.privateKey),
          onCopyPublic: () => this.copy(key.publicKey),
          onExport: () => exportSshPrivateKey(this.getUIContext(), key),
        })
      }, (key: SshKeyDraft) => `${key.name}`)
    }
    .width('100%')
  }
}
