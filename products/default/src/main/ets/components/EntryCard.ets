import { ItemTemplate, PasswordStrengthCalculator, VaultEntry, VaultField } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { parseSshKeys, SSH_KEYS_FIELD } from '../model/SshKeyPayload'
import { EntryAvatar } from './EntryAvatar'
import { FavoriteToggle } from './FavoriteToggle'
import { strengthLabel } from './PasswordStrengthIndicator'

const USERNAME_FIELD_NAME: string = 'UserName'
const NOTES_FIELD_NAME: string = 'Notes'
const PASSWORD_FIELD_NAME: string = 'Password'
const CARD_TYPE_FIELD_NAME: string = 'CardType'
const CARD_NUMBER_FIELD_NAME: string = 'CardNumber'

@ComponentV2
export struct EntryCard {
  @Require @Param entry: VaultEntry
  @Param avatarData: ArrayBuffer | undefined = undefined
  // 收藏状态由列表行模型携带，@Param 才能驱动行模型变化刷新图标
  @Param favorite: boolean = false
  @Param favoriteEnabled: boolean = true
  @Event onEntryClick: () => void = () => {
  }
  @Event onFavoriteToggle: (next: boolean) => void = () => {
  }
  @Event onEdit: () => void = () => {
  }

  // 未标记模板的条目按登录信息渲染，与 definitionFor 回退 LOGIN 一致。
  @Computed
  private get subtitle(): ResourceStr {
    switch (this.entry.template) {
      case ItemTemplate.SecureNote:
        return this.fieldValue(NOTES_FIELD_NAME)
      case ItemTemplate.CreditCard:
        return this.cardSubtitle()
      case ItemTemplate.SshKey: {
        const count: number = parseSshKeys(this.fieldValue(SSH_KEYS_FIELD)).length
        return count === 0 ? '' : this.format($r('app.string.entry_card_ssh_key_count').id, String(count))
      }
      case ItemTemplate.Attachment: {
        const count: number = this.entry.attachments.length
        return count === 0 ? '' : this.format($r('app.string.entry_card_attachment_count').id, String(count))
      }
      case ItemTemplate.Password:
        return strengthLabel(PasswordStrengthCalculator.calculate(this.fieldValue(PASSWORD_FIELD_NAME)))
      default:
        return this.fieldValue(USERNAME_FIELD_NAME)
    }
  }

  // 密码长度只属于密码模板：登录信息的 Password 字段是登录密码，不进副标题。
  @Computed
  private get passwordLengthText(): string {
    if (this.entry.template !== ItemTemplate.Password) {
      return ''
    }
    const password: string = this.fieldValue(PASSWORD_FIELD_NAME)
    return password.length === 0
      ? ''
      : this.format($r('app.string.entry_card_password_length').id, String(password.length))
  }

  // Resource 对象的格式化重载自 API 20 废弃，带占位符的文案只能走资源 ID + 参数。
  private format(resId: number, value: string): string {
    return ResUtil.getStringSync(resId, [value])
  }

  private fieldValue(name: string): string {
    return this.entry.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  // 与预览页卡号同规则：只去空白字符，不去除 '-' 等符号；不足 4 位时显示实际内容。
  private cardSubtitle(): ResourceStr {
    const cardType: string = this.fieldValue(CARD_TYPE_FIELD_NAME)
    if (cardType.length > 0) {
      return cardType
    }
    const digits: string = this.fieldValue(CARD_NUMBER_FIELD_NAME).replace(/\s+/g, '')
    return digits.length === 0 ? '' : this.format($r('app.string.entry_card_card_last_four').id, digits.slice(-4))
  }

  private toggleFavorite(): void {
    this.onFavoriteToggle(!this.favorite)
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        EntryAvatar({ title: this.entry.title, avatarData: this.avatarData })

        Column({ space: $r('sys.float.padding_level1') }) {
          Text(this.entry.title)
            .width('100%')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: $r('sys.float.padding_level2') }) {
            Text(this.subtitle)
              .layoutWeight(1)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.passwordLengthText.length > 0) {
              Text(this.passwordLengthText)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        FavoriteToggle({
          favorite: this.favorite,
          clickable: this.favoriteEnabled,
          onToggle: () => this.toggleFavorite(),
        })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width('100%')
      .padding($r('sys.float.padding_level8'))
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(0)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .onClick(() => this.onEntryClick())
  }
}
