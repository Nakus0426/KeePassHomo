import { bundleManager } from '@kit.AbilityKit'
import { AnimationTokens } from '@ohos/common'
import { DsButton, DsButtonSize, DsButtonVariant } from '../../components/DsButton'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { ROUTE_WELCOME } from '../../constants/RouteConstants'
import { appRouter } from '../../navigation/AppRouter'
import { WelcomeParam } from '../../navigation/RouteParams'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { appViewModel, AppViewModel } from '../../viewmodel/AppViewModel'

const APP_NAME_LETTER_SPACING: number = 0.4
const CARD_LABEL_LETTER_SPACING: number = -0.15
const CARD_ACTION_LETTER_SPACING: number = 0.2
const VERSION_LETTER_SPACING: number = 0.6

@ComponentV2
export struct WelcomePage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private showBack: boolean = false
  @Local private versionName: string = ''
  @Local private hoveredAction: number = -1
  @Local private pressedAction: number = -1

  @Computed
  get topInset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx)
  }

  aboutToAppear(): void {
    const param: WelcomeParam | undefined = appRouter.topParam() as WelcomeParam | undefined
    this.showBack = param?.showBack ?? false
    const info: bundleManager.BundleInfo =
      bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
    this.versionName = info.versionName
  }

  private actionBackground(index: number, filled: boolean): ResourceColor {
    if (this.pressedAction === index) {
      return filled ? $r('app.color.ds_primary_press') : $r('app.color.ds_secondary_press')
    }
    if (this.hoveredAction === index) {
      return filled ? $r('app.color.ds_primary_hover') : $r('app.color.ds_secondary_hover')
    }
    return filled ? $r('app.color.ds_primary') : $r('app.color.ds_surface_low')
  }

  private updateActionHover(index: number, isHover: boolean): void {
    if (isHover) {
      this.hoveredAction = index
      return
    }
    if (this.hoveredAction === index) {
      this.hoveredAction = -1
    }
  }

  private updateActionPress(index: number, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressedAction = index
      return
    }
    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.pressedAction === index) {
      this.pressedAction = -1
    }
  }

  @Builder
  private backBar() {
    Row() {
      DsButton({
        variant: DsButtonVariant.Text,
        buttonSize: DsButtonSize.Medium,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_arrow_back'),
        iconSizeOverride: $r('app.float.ds_icon_md'),
        iconColorOverride: $r('app.color.ds_text_primary'),
        accessibilityLabelResource: $r('app.string.back'),
        onTap: () => appRouter.pop(),
      })
    }
    .width('100%')
    .height(60)
    .padding({
      top: $r('app.float.ds_space_16'),
      left: $r('app.float.ds_space_lg'),
      right: $r('app.float.ds_space_lg'),
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.ds_surface_low'))
  }

  @Builder
  private brandHeader() {
    Column({ space: $r('app.float.ds_space_24') }) {
      Image($r('app.media.launch_icon'))
        .width($r('app.float.ds_logo_size'))
        .height($r('app.float.ds_logo_size'))
        .objectFit(ImageFit.Contain)
        .draggable(false)

      Column({ space: $r('app.float.ds_space_sm') }) {
        Text($r('app.string.app_brand_name'))
          .fontSize($r('app.float.ds_font_headline'))
          .lineHeight($r('app.float.ds_font_display'))
          .fontWeight(600)
          .letterSpacing(APP_NAME_LETTER_SPACING)
          .fontColor($r('app.color.ds_text_primary'))
        Text($r('app.string.welcome_tagline'))
          .fontSize($r('app.float.ds_font_body'))
          .lineHeight($r('app.float.ds_font_headline_md'))
          .fontColor($r('app.color.ds_text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_xl'),
      bottom: $r('app.float.ds_space_xl'),
      left: $r('app.float.ds_space_lg'),
      right: $r('app.float.ds_space_lg'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private actionCard(index: number, title: ResourceStr, description: ResourceStr, footer: ResourceStr, icon: Resource,
    filled: boolean, action: () => void) {
    Column() {
      Column({ space: $r('app.float.ds_space_sm') }) {
        Row({ space: $r('app.float.ds_space_sm') }) {
          SymbolGlyph(icon)
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary')])
            .foregroundColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary'))
          Text(title)
            .fontSize($r('app.float.ds_font_title'))
            .lineHeight(20)
            .fontWeight(600)
            .letterSpacing(CARD_LABEL_LETTER_SPACING)
            .fontColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary'))
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(description)
          .fontSize($r('app.float.ds_font_body_sm'))
          .lineHeight($r('app.float.ds_font_title_md'))
          .fontColor(filled ? $r('app.color.ds_primary_fixed_dim') : $r('app.color.ds_text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: $r('app.float.ds_space_xs') }) {
        Text(footer)
          .fontSize($r('app.float.ds_font_label_md'))
          .lineHeight(14)
          .fontWeight(500)
          .letterSpacing(CARD_ACTION_LETTER_SPACING)
          .fontColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary'))
        SymbolGlyph($r('app.string.symbol_arrow_forward'))
          .fontSize($r('app.float.ds_icon_tiny'))
          .fontColor([filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary')])
          .foregroundColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(110)
    .padding($r('app.float.ds_space_16'))
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(this.actionBackground(index, filled))
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
    .onHover((isHover: boolean) => this.updateActionHover(index, isHover))
    .onTouch((event: TouchEvent) => this.updateActionPress(index, event))
    .onClick(action)
  }

  @Builder
  private actions() {
    Column({ space: $r('app.float.ds_space_md') }) {
      this.actionCard(
        0,
        $r('app.string.create_vault'),
        $r('app.string.action_create_vault_desc'),
        $r('app.string.action_create_vault_footer'),
        $r('app.string.symbol_add_square'),
        true,
        () => this.viewModel.openCreateVault(),
      )
      this.actionCard(
        1,
        $r('app.string.action_open_local_title'),
        $r('app.string.action_open_local_desc'),
        $r('app.string.action_open_local_footer'),
        $r('app.string.symbol_folder'),
        false,
        () => this.viewModel.chooseLocalVault(),
      )
      this.actionCard(
        2,
        $r('app.string.action_webdav_title'),
        $r('app.string.action_webdav_desc'),
        $r('app.string.action_webdav_footer'),
        $r('app.string.symbol_cloud_sync'),
        false,
        () => this.viewModel.openWebDav(),
      )
    }
    .width('100%')
    .layoutWeight(1)
    .padding({
      top: $r('app.float.ds_space_24'),
      left: $r('app.float.ds_space_lg'),
      right: $r('app.float.ds_space_lg'),
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private versionFooter() {
    Text($r('app.string.launch_version', this.versionName))
      .width('100%')
      .textAlign(TextAlign.Center)
      .fontSize($r('app.float.ds_font_body_sm'))
      .lineHeight($r('app.float.ds_font_title_md'))
      .fontFamily(PASSWORD_FONT_FAMILY)
      .letterSpacing(VERSION_LETTER_SPACING)
      .fontColor($r('app.color.ds_text_disabled'))
      .padding({
        top: $r('app.float.ds_space_md'),
        bottom: $r('app.float.ds_space_26'),
        left: $r('app.float.ds_space_lg'),
        right: $r('app.float.ds_space_lg'),
      })
      .backgroundColor($r('app.color.ds_surface_canvas'))
  }

  build() {
    NavDestination() {
      Column() {
        // 全屏布局下补状态栏高度，避免品牌头贴到屏幕顶端。
        Row()
          .width('100%')
          .height(this.topInset)
          .backgroundColor($r('app.color.ds_surface_low'))
        if (this.showBack) {
          this.backBar()
        }
        this.brandHeader()
        this.actions()
        this.versionFooter()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .onBackPressed(() => {
      if (this.showBack) {
        appRouter.pop()
        return true
      }
      appRouter.handleRootBack(ROUTE_WELCOME)
      return true
    })
  }
}

@Builder
export function welcomePageBuilder() {
  WelcomePage()
}
