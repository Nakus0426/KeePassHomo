import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { EntryAvatar } from '../../components/EntryAvatar'
import { IconToggleButton } from '../../components/IconToggleButton'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'
import { VaultField, VaultFieldType } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'

const PREVIEW_MENU_MAX_COUNT: number = 4
const PASSWORD_MASK: string = '••••••••'

/**
 * 预览详情行：整行可点，点击行为由页面经 onCellClick 绑定（默认为复制值）。
 * 交互与按压反馈对齐 components/Cell.ets，布局沿用预览页既有两行结构。
 */
@ComponentV2
struct Cell {
  @Require @Param icon: Resource
  @Require @Param label: ResourceStr
  @Param value: string = ''
  @Param clickable: boolean = true
  @Event onCellClick: () => void = () => {
  }
  /** 右侧自定义区域：密码可见性、跳转链接、展开折叠按钮。 */
  @BuilderParam trailingBuilder?: () => void
  /** 行内附加内容：密码可见倒计时、备注展开文本。 */
  @BuilderParam extraBuilder?: () => void

  build() {
    ListItem() {
      Row({ space: $r('sys.float.padding_level8') }) {
        SymbolGlyph(this.icon)
          .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
          .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
          .fontColor([$r('sys.color.brand')])

        Column({ space: $r('sys.float.padding_level4') }) {
          Text(this.label)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
          Text(this.value.length > 0 ? this.value : ' ')
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.trailingBuilder !== undefined) {
          Row({ space: $r('sys.float.padding_level4') }) {
            this.trailingBuilder()
          }
          .alignSelf(ItemAlign.Center)
        }
      }
      .alignItems(VerticalAlign.Top)

      if (this.extraBuilder !== undefined) {
        this.extraBuilder()
      }

    }
    .padding($r('sys.float.padding_level6'))
    .margin($r('sys.float.padding_level2'))
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor(this.clickable ? $r('sys.color.interactive_pressed') : Color.Transparent)
      },
    })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .onClick(() => {
      if (!this.clickable) {
        return
      }
      this.onCellClick()
    })
  }
}

@ComponentV2
export struct EntryPreviewContent {
  @Param title: string = ''
  @Param groupPath: string = ''
  @Param fields: VaultField[] = []
  @Param tags: string[] = []
  @Param entryUuid: string = ''
  @Param favorite: boolean = false
  @Param readOnly: boolean = false
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
  @Event onClose: () => void = () => {
  }
  @Event onEdit: () => void = () => {
  }
  @Local private session: AppSessionState = appSessionState
  @Local private passwordVisible: boolean = false
  @Local private passwordSeconds: number = 0
  @Local private notesExpanded: boolean = false
  private passwordTimer: number = -1
  private readonly viewModel: AppViewModel = appViewModel
  private readonly favoriteIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.star')).fontSize($r('sys.float.titlebar_icon_width'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly favoritedIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.star_fill')).fontSize($r('sys.float.titlebar_icon_width'))
      .fontColor([$r('app.color.favorite')])
  private readonly editIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')).fontSize($r('sys.float.titlebar_icon_width'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly deleteIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.trash')).fontSize($r('sys.float.titlebar_icon_width'))
      .fontColor([$r('sys.color.warning')])
  private readonly closeIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.xmark')).fontSize($r('sys.float.titlebar_icon_width'))
      .fontColor([$r('sys.color.titlebar_icon_color')])

  @Computed
  private get username(): string {
    return this.fieldValue('UserName')
  }

  @Computed
  private get password(): string {
    return this.fieldValue('Password')
  }

  @Computed
  private get url(): string {
    return this.fieldValue('URL')
  }

  @Computed
  private get notes(): string {
    return this.fieldValue('Notes')
  }

  @Computed
  private get customFields(): VaultField[] {
    return this.fields.filter((field: VaultField) =>
    field.name !== 'Title' && field.name !== 'UserName' && field.name !== 'Password' &&
      field.name !== 'URL' && field.name !== 'Notes')
  }

  aboutToDisappear(): void {
    this.clearPasswordTimer()
    this.passwordVisible = false
    this.passwordSeconds = 0
  }

  @Monitor('session.sensitiveEpoch')
  onSensitiveStateChanged(): void {
    this.hidePassword()
  }

  private fieldValue(name: string): string {
    return this.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  private clearPasswordTimer(): void {
    if (this.passwordTimer >= 0) {
      clearInterval(this.passwordTimer)
      this.passwordTimer = -1
    }
  }

  private hidePassword(): void {
    this.clearPasswordTimer()
    this.passwordVisible = false
    this.passwordSeconds = 0
  }

  private startPasswordTimeout(): void {
    this.clearPasswordTimer()
    this.passwordVisible = true
    this.passwordSeconds = 30
    this.passwordTimer = setInterval(() => {
      this.passwordSeconds--
      if (this.passwordSeconds <= 0) {
        this.hidePassword()
      }
    }, 1000)
  }

  private togglePasswordVisibility(): void {
    if (this.passwordVisible) {
      this.hidePassword()
      return
    }
    this.startPasswordTimeout()
  }

  private copyPassword(): void {
    if (this.password.length === 0) {
      return
    }
    this.viewModel.copyValue(this.password).then(() => this.startPasswordTimeout())
  }

  private copy(value: string): void {
    this.viewModel.copyValue(value)
  }

  private openUrl(): void {
    this.viewModel.openFieldAction(this.url, VaultFieldType.Url)
  }

  private countdownText(): string {
    const time: string = `00:${this.passwordSeconds < 10 ? '0' : ''}${this.passwordSeconds}`
    return ResUtil.getStringSync($r('app.string.password_hide_countdown')).replace('%s', time)
  }

  private toggleFavorite(): void {
    this.viewModel.toggleFavorite(this.entryUuid)
  }

  private confirmDelete(): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.delete_entry_title'),
      message: $r('app.string.delete_entry_message'),
      primaryButton: {
        value: $r('app.string.cancel'), action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('sys.color.warning'),
        action: () => this.viewModel.deleteEntry(this.entryUuid).then((deleted: boolean) => {
          if (deleted) {
            this.onClose()
          }
        }),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private menuItem(icon: SymbolGlyphModifier, label: Resource, action: () => void,
    enabled: boolean = true): HdsNavigationMenuItemOptions {
    const content: HdsNavigationIconOptions = {
      icon: icon,
      label: label,
      isEnabled: enabled,
      action: action,
    }
    return { content: content }
  }

  private previewMenuItems(): HdsNavigationMenuItemOptions[] {
    if (this.readOnly) {
      return [this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose())]
    }
    return [
      this.menuItem(this.favorite ? this.favoritedIcon : this.favoriteIcon,
        this.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
        () => this.toggleFavorite(), !this.viewModel.busy),
      this.menuItem(this.editIcon, $r('app.string.edit'), () => this.onEdit(), !this.viewModel.busy),
      this.menuItem(this.deleteIcon, $r('app.string.delete_entry'), () => this.confirmDelete(), !this.viewModel.busy),
      this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose()),
    ]
  }

  @LocalBuilder
  private passwordTrailing() {
    PasswordVisibilityToggle({
      visible: this.passwordVisible,
      exclusive: true,
      onChange: () => this.togglePasswordVisibility(),
    })
  }

  @LocalBuilder
  private urlTrailing() {
    if (this.url.length > 0) {
      IconToggleButton({
        symbol: $r('sys.symbol.arrow_up_right'),
        accessibilityLabel: $r('app.string.open_link'),
        exclusive: true,
        onToggle: () => this.openUrl(),
      })
    }
  }

  @LocalBuilder
  private notesTrailing() {
    IconToggleButton({
      symbol: this.notesExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
      accessibilityLabel: $r('app.string.notes'),
      exclusive: true,
      onToggle: () => this.notesExpanded = !this.notesExpanded,
    })
  }

  @Builder
  private previewMenu() {
    HdsNavigation() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level16') }) {
          Row({ space: $r('sys.float.padding_level8') }) {
            EntryAvatar(
              { title: this.title, avatarData: this.avatarData, avatarSize: $r('app.float.entry_avatar_size') })
            Column({ space: $r('sys.float.padding_level4') }) {
              Text(this.title)
                .width('100%')
                .fontSize($r('sys.float.Title_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .marqueeOptions({ fadeout: true, start: true })
              Row({ space: $r('sys.float.padding_level4') }) {
                SymbolGlyph($r('sys.symbol.folder')).fontSize($r('sys.float.Body_M'))
                  .fontColor([$r('sys.color.font_secondary')])
                Text(this.groupPath).fontSize($r('sys.float.Body_M')).fontColor($r('sys.color.font_secondary'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .margin({ left: $r('sys.float.padding_level8') })

          List() {
            Cell({
              icon: $r('sys.symbol.person'),
              label: $r('app.string.username'),
              value: this.username,
              clickable: this.username.length > 0,
              onCellClick: () => this.copy(this.username),
            })

            Cell({
              icon: $r('sys.symbol.lock'),
              label: $r('app.string.password'),
              value: this.passwordVisible || this.password.length === 0 ? this.password : PASSWORD_MASK,
              clickable: this.password.length > 0,
              onCellClick: () => this.copyPassword(),
              trailingBuilder: this.passwordTrailing,
              extraBuilder: () => {
                if (this.passwordSeconds > 0) {
                  Text(this.countdownText()).width('100%').fontSize($r('sys.float.Caption_S'))
                    .fontColor($r('sys.color.font_tertiary'))
                    .padding({ left: $r('sys.float.padding_level16'), bottom: $r('sys.float.padding_level8') })
                }
              },
            })

            Cell({
              icon: $r('sys.symbol.link'),
              label: $r('app.string.website'),
              value: this.url,
              clickable: this.url.length > 0,
              onCellClick: () => this.copy(this.url),
              trailingBuilder: this.urlTrailing,
            })

            Cell({
              icon: $r('sys.symbol.doc_text'),
              label: $r('app.string.notes'),
              value: '',
              clickable: this.notes.length > 0,
              onCellClick: () => this.copy(this.notes),
              trailingBuilder: this.notesTrailing,
              extraBuilder: () => {
                if (this.notesExpanded) {
                  Text(this.notes)
                    .width('100%')
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('sys.color.font_primary'))
                    .wordBreak(WordBreak.BREAK_ALL)
                    .padding({
                      left: $r('sys.float.padding_level16'),
                      right: $r('sys.float.padding_level8'),
                      top: $r('sys.float.padding_level4'),
                      bottom: $r('sys.float.padding_level8'),
                    })
                }
              },
            })

            ListItem() {
              Row({ space: $r('sys.float.padding_level8') }) {
                SymbolGlyph($r('sys.symbol.label'))
                  .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
                  .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
                  .fontColor([$r('sys.color.brand')])
                Flex({
                  wrap: FlexWrap.Wrap, space: {
                    main: LengthMetrics.vp(ResUtil.getNumber($r('sys.float.padding_level4').id)),
                    cross: LengthMetrics.vp(ResUtil.getNumber($r('sys.float.padding_level4').id)),
                  },
                }) {
                  ForEach(this.tags, (tag: string) => {
                    Text(tag)
                      .fontSize($r('sys.float.Caption_M'))
                      .fontColor($r('sys.color.brand'))
                      .padding({
                        left: $r('sys.float.padding_level8'),
                        right: $r('sys.float.padding_level8'),
                        top: $r('sys.float.padding_level4'),
                        bottom: $r('sys.float.padding_level4'),
                      })
                      .backgroundColor($r('sys.color.comp_background_secondary'))
                      .borderRadius($r('sys.float.chip_border_radius_normal'))
                  }, (tag: string) => tag)
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding($r('sys.float.padding_level4'))
            }
            .width('100%')
            .backgroundColor(Color.Transparent)

            ForEach(this.customFields, (field: VaultField) => {
              Cell({
                icon: field.type === VaultFieldType.Password ? $r('sys.symbol.lock') : $r('sys.symbol.circle_grid_2x2'),
                label: field.name,
                value: field.value.length > 0 &&
                  (field.protected || field.type === VaultFieldType.Password) ? PASSWORD_MASK : field.value,
                clickable: field.value.length > 0,
                onCellClick: () => this.copy(field.value),
              })
            }, (field: VaultField) => field.name)
          }
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
          .borderRadius($r('sys.float.corner_radius_level10'))
          .divider({
            strokeWidth: 1,
            color: $r('sys.color.grid_menu_divider_color'),
            startMargin: $r('sys.float.padding_level8'),
            endMargin: $r('sys.float.padding_level8'),
          })
          .margin({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
          .scrollBar(BarState.Off)

        }
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({ top: this.topOffset, bottom: this.bottomOffset })
        .onTouch(() => this.viewModel.recordActivity())
      }
      .width('100%')
      .height('100%')
      .id('entry_preview_scroll')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: { enableScrollEffect: false, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: { title: { mainTitle: '' }, menu: { maxCount: PREVIEW_MENU_MAX_COUNT, value: this.previewMenuItems() } },
    })
  }

  build() {
    this.previewMenu()
  }
}
