import { HdsNavDestination } from '@kit.UIDesignKit'
import { RESERVED_FIELD_NAMES, VaultField, VaultFieldType } from '@ohos/common'
import { ROUTE_ENTRY_DETAIL } from '../../constants/RouteConstants'
import { PASSWORD_REVEAL_SECONDS } from '../../constants/SecurityConstants'
import { PageTopBar } from '../../components/PageChrome'
import { appRouter } from '../../navigation/AppRouter'
import { EntryDetailParam } from '../../navigation/RouteParams'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditSheet, EntryEditSheetState } from './EntryEditSheet'

@ComponentV2
export struct EntryDetailPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private entryUuid: string = ''
  @Local private showPassword: boolean = false
  @Local private editSheet: EntryEditSheetState = new EntryEditSheetState()
  @Local private revealedFields: string[] = []
  private revealTimer: number = -1

  aboutToAppear(): void {
    const param: EntryDetailParam | undefined = appRouter.topParam() as EntryDetailParam | undefined
    this.entryUuid = param?.entryUuid ?? ''
  }

  private revealPassword(): void {
    this.showPassword = true
    this.revealTimer = setTimeout(() => this.showPassword = false, PASSWORD_REVEAL_SECONDS * 1000)
  }

  private hidePassword(): void {
    this.showPassword = false
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
  }

  private editEntry(): void {
    this.editSheet.entryUuid = this.entryUuid
    this.editSheet.visible = true
    this.viewModel.recordActivity()
  }

  @Computed
  private get customFields(): VaultField[] {
    return this.viewModel.entry(this.entryUuid).fields
      .filter((field: VaultField) => !RESERVED_FIELD_NAMES.includes(field.name))
  }

  private actionLabel(type: VaultFieldType): Resource | undefined {
    if (type === VaultFieldType.Url) {
      return $r('app.string.open_link')
    }
    if (type === VaultFieldType.Email) {
      return $r('app.string.send_email')
    }
    if (type === VaultFieldType.Phone) {
      return $r('app.string.dial_phone')
    }
    if (type === VaultFieldType.Address) {
      return $r('app.string.open_map')
    }
    return undefined
  }

  private isRevealed(name: string): boolean {
    return this.revealedFields.includes(name)
  }

  private toggleReveal(name: string): void {
    if (this.isRevealed(name)) {
      this.revealedFields = this.revealedFields.filter((item: string) => item !== name)
      return
    }
    this.revealedFields = this.revealedFields.concat([name])
  }

  private displayValue(field: VaultField): ResourceStr {
    if (field.type === VaultFieldType.Password && !this.isRevealed(field.name)) {
      return $r('app.string.password_hidden')
    }
    return field.value
  }

  @Builder
  private customFieldCard(field: VaultField) {
    Column({ space: 8 }) {
      Text(field.name)
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(this.displayValue(field))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        if (field.type === VaultFieldType.Password) {
          Button(this.isRevealed(field.name) ? $r('app.string.hide') : $r('app.string.show'))
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.toggleReveal(field.name))
        }
        if (this.actionLabel(field.type) !== undefined) {
          Button(this.actionLabel(field.type))
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.openFieldAction(field.value, field.type))
        }
        Button($r('app.string.copy'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.copyValue(field.value))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  @Builder
  private detailField(label: Resource, value: string) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(value)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        if (value.length > 0) {
          Button($r('app.string.copy'))
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.copyValue(value))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  @Builder
  private passwordField(value: string) {
    Column({ space: 8 }) {
      Text($r('app.string.password'))
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(this.showPassword ? value : $r('app.string.password_hidden'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        Button(this.showPassword ? $r('app.string.hide') : $r('app.string.show'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.showPassword ? this.hidePassword() : this.revealPassword())
        Button($r('app.string.copy'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.copyValue(value))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Column({ space: 16 }) {
          PageTopBar({
            title: $r('app.string.login_template'),
            showBack: true,
            onBack: () => appRouter.pop(),
          })
          Text(this.viewModel.entry(this.entryUuid).title)
            .width('100%')
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
          Text(this.viewModel.entry(this.entryUuid).groupPath)
            .width('100%')
            .fontColor($r('sys.color.font_secondary'))
          Row({ space: 8 }) {
            Button(this.viewModel.entry(this.entryUuid).favorite
              ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'))
              .enabled(!this.viewModel.busy && !this.viewModel.currentSource().readOnly)
              .backgroundColor($r('sys.color.comp_emphasize_secondary'))
              .fontColor($r('sys.color.brand'))
              .onClick(() => this.viewModel.toggleFavorite(this.entryUuid))
            Button(this.viewModel.entry(this.entryUuid).archived
              ? $r('app.string.restore_entry') : $r('app.string.archive_entry'))
              .enabled(!this.viewModel.busy && !this.viewModel.currentSource().readOnly)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => this.viewModel.toggleArchived(this.entryUuid))
          }
          .width('100%')

          this.detailField($r('app.string.username'),
            this.viewModel.field(this.viewModel.entry(this.entryUuid), 'UserName'))
          this.passwordField(
            this.viewModel.field(this.viewModel.entry(this.entryUuid), 'Password'))
          this.detailField($r('app.string.website'),
            this.viewModel.field(this.viewModel.entry(this.entryUuid), 'URL'))
          this.detailField($r('app.string.notes'),
            this.viewModel.field(this.viewModel.entry(this.entryUuid), 'Notes'))
          if (this.viewModel.entry(this.entryUuid).tags.length > 0) {
            this.detailField($r('app.string.tags'),
              this.viewModel.entry(this.entryUuid).tags.join(', '))
          }
          if (this.customFields.length > 0) {
            Text($r('app.string.fields'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
            ForEach(this.customFields, (field: VaultField) => {
              this.customFieldCard(field)
            }, (field: VaultField) => field.name)
          }
          if (this.viewModel.clipboardSeconds > 0) {
            Text($r('app.string.copied_countdown', this.viewModel.clipboardSeconds))
              .width('100%')
              .fontColor($r('sys.color.confirm'))
              .textAlign(TextAlign.Center)
          }
          Blank()
          if (!this.viewModel.currentSource().readOnly) {
            Button($r('app.string.edit'))
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.brand'))
              .onClick(() => this.editEntry())
          }
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding($r('sys.float.padding_level12'))
        .onTouch(() => this.viewModel.recordActivity())

        EntryEditSheet({ state: this.editSheet })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onHidden(() => {
      this.hidePassword()
      this.revealedFields = []
    })
  }
}

@Builder
export function entryDetailPageBuilder() {
  EntryDetailPage()
}
