import { HdsNavDestination } from '@kit.UIDesignKit'
import { uiMaterial } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { ROUTE_UNLOCK, ROUTE_VAULT } from '../../constants/RouteConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { AnimationTokens, AppErrorModel, BounceAnimator } from '@ohos/common'
import { FormTextField } from '../../components/FormTextField'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'

const LUNCH_ICON_SIZE = 100

@ComponentV2
export struct UnlockPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private colorMode: ColorModeState = colorModeState
  @Local private viewModel: AppViewModel = appViewModel
  @Local private password: string = ''
  @Local private passwordVisible: boolean = false
  @Local private passwordFocused: boolean = false
  @Local private exitProgress: number = 0
  @Local private topShift: number = 0
  @Local private bottomShift: number = 0
  private pageHeight: number = 0
  private exitAnimating: boolean = false
  private readonly unlockBounce: BounceAnimator = new BounceAnimator()
  /**
   * 自定义转场代理：入场返回 undefined 走系统默认转场（与文件摘要页等一致）；
   * 离场返回零时长空转场——整栈重建移除本页时不播横向离场动画，避免与首页 FADE 淡入叠加出残影。
   */
  private readonly navTransition: NavDestinationTransitionDelegate =
    (_operation: NavigationOperation, isEnter: boolean): Array<NavDestinationTransition> | undefined => {
      if (isEnter) {
        return undefined
      }
      return [{
        event: () => {
        },
        duration: 0,
      }]
    }
  private readonly toastMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    { style: uiMaterial.ImmersiveStyle.ULTRA_THICK })

  @Computed
  get bottomSafeAreaHeight() {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get formPaddingToHeight() {
    const padding = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(padding) + LUNCH_ICON_SIZE / 2
  }

  @Computed
  get suffixButtonSize(): number {
    const buttonHeight: number = ResUtil.getNumber($r('app.float.control_height').id)
    const padding: number = ResUtil.getNumber($r('sys.float.padding_level4').id)
    return this.getUIContext().px2vp(buttonHeight - padding * 2)
  }

  // 分割线与解锁按钮的显示条件：输入框有焦点，或已输入非空密码
  @Computed
  get showUnlockSuffix(): boolean {
    return this.passwordFocused || this.password.length > 0
  }

  @Monitor('viewModel.lastError')
  onLastErrorChanged(): void {
    const error: AppErrorModel | undefined = this.viewModel.lastError
    if (error !== undefined) {
      this.showToast(error.message)
    }
  }

  private async handleSubmit(): Promise<void> {
    if (this.exitAnimating) {
      return
    }
    if (this.password.length === 0) {
      this.showToast($r('app.string.unlock_password_required'))
      return
    }
    if (await this.viewModel.unlockVault(this.password)) {
      this.playExitAnimation()
    }
  }

  /**
   * 解锁成功离场动画：上下背景分离、图标顺时针旋转随上半背景上移、整页淡出，
   * 动画结束后经系统 FADE 转场进入首页。
   */
  private playExitAnimation(): void {
    this.exitAnimating = true
    this.getUIContext().getFocusController().clearFocus()
    // 延迟启动，避开收键盘布局变化与动画首帧同帧的干扰
    setTimeout(() => {
      this.topShift = this.pageHeight * 0.2
      this.bottomShift = this.pageHeight * 0.8
      this.getUIContext().animateTo({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: Curve.EaseIn,
        onFinish: () => {
          appRouter.resetTo(ROUTE_VAULT, undefined, true)
        },
      }, () => {
        this.exitProgress = 1
      })
    }, 50)
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message,
        systemMaterial: this.toastMaterial,
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`显示解锁提示失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    }
  }

  @LocalBuilder
  private vaultSwitchBuilder() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.folder'))
            .fontSize($r('sys.float.Title_L'))
            .fontColor([$r('sys.color.brand')])
        }
        .padding($r('sys.float.padding_level4'))
        .borderRadius('50%')
        .backgroundColor($r('sys.color.comp_emphasize_secondary'))

        Column({ space: $r('sys.float.padding_level2') }) {
          Text(this.viewModel.currentSource().displayName)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
          Text(this.viewModel.formatName(this.viewModel.currentFormat()))
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_secondary')])
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      top: $r('sys.float.padding_level6'),
      bottom: $r('sys.float.padding_level6'),
      left: $r('sys.float.padding_level8'),
      right: $r('sys.float.padding_level8'),
    })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .enabled(!this.viewModel.busy)
    .onClick(() => this.viewModel.chooseLocalVault())
  }

  @LocalBuilder
  private passwordSuffixBuilder() {
    Row({ space: $r('sys.float.padding_level2') }) {
      PasswordVisibilityToggle({
        visible: this.passwordVisible,
        onChange: (visible: boolean) => this.passwordVisible = visible,
      })

      if (this.showUnlockSuffix) {
        Divider()
          .vertical(true)
          .margin({ top: $r('sys.float.padding_level6'), bottom: $r('sys.float.padding_level6') })
          .color($r('sys.color.comp_divider'))

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_forward'))
            .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
            .fontColor([$r('sys.color.brand')])
            .fontWeight(FontWeight.Normal)
            .scale({ x: this.unlockBounce.scale, y: this.unlockBounce.scale })
        }
        .width(this.suffixButtonSize)
        .height(this.suffixButtonSize)
        .backgroundColor(Color.Transparent)
        .stateStyles({
          pressed: {
            .backgroundColor($r('sys.color.interactive_pressed'))
          },
        })
        .accessibilityText($r('app.string.unlock_vault'))
        .enabled(!this.viewModel.busy)
        .onClick(() => this.unlockBounce.play(this.getUIContext(), () => this.handleSubmit()))
      }
    }
  }

  @LocalBuilder
  private keyFileBuilder() {
    Button() {
      Row({ space: $r('sys.float.padding_level2') }) {
        Text(this.viewModel.currentKeyFileName().length > 0
          ? this.viewModel.currentKeyFileName() : $r('app.string.key_file_label'))
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .maxLines(1)
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Body_M'))
          .fontColor([$r('sys.color.font_secondary')])
      }
    }
    .buttonStyle(ButtonStyleMode.TEXTUAL)
    .padding({
      top: $r('sys.float.padding_level2'),
      bottom: $r('sys.float.padding_level2'),
      left: $r('sys.float.padding_level4'),
      right: $r('sys.float.padding_level4'),
    })
    .onClick(() => this.viewModel.chooseKeyFile())
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Rect()
          .width('100%')
          .height('20%')
          .fill($r('sys.color.background_tertiary'))
          .position({ top: 0, left: 0 })
          .translate({ y: -this.topShift * this.exitProgress })
          .border({
            width: {
              top: 0,
              bottom: $r('sys.float.border_width'),
              left: 0,
              right: 0,
            },
            color: $r('sys.color.comp_divider'),
          })
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.launch_icon'))
            .width(LUNCH_ICON_SIZE * 256 / (256 - 30 * 2))
            .height(LUNCH_ICON_SIZE * 256 / (256 - 30 * 2))
        }
        .width(LUNCH_ICON_SIZE)
        .height(LUNCH_ICON_SIZE)
        .position({ top: '20%', left: '50%' })
        .translate({
          x: -LUNCH_ICON_SIZE / 2,
          y: -LUNCH_ICON_SIZE / 2 - this.topShift * this.exitProgress,
        })
        .rotate({ angle: 90 * this.exitProgress })
        .zIndex(1)
        .borderRadius('50%')
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)

        Rect()
          .width('100%')
          .height('80%')
          .fill(this.colorMode.isDark
            ? $r('sys.color.background_fourth') : $r('sys.color.background_secondary'))
          .position({ bottom: 0, left: 0 })
          .translate({ y: this.bottomShift * this.exitProgress })

        Column() {
          Column({ space: $r('sys.float.padding_level12') }) {
            Column({ space: $r('sys.float.padding_level6') }) {
              Text($r('app.string.unlock_vault'))
                .fontSize($r('sys.float.Title_L'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))

              Text($r('app.string.unlock_vault_desc'))
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }

            this.vaultSwitchBuilder()

            FormTextField({
              placeholder: $r('app.string.text_input_placeholder'),
              type: InputType.Password,
              text: this.password,
              showPassword: this.passwordVisible,
              onChange: (value: string) => this.password = value,
              onFocusChange: (focused: boolean) => this.passwordFocused = focused,
              onSubmit: () => this.handleSubmit(),
            }) {
              this.passwordSuffixBuilder()
            }
          }

          this.keyFileBuilder()
        }
        .width('100%')
        .height('80%')
        .justifyContent(FlexAlign.SpaceBetween)
        .position({ bottom: 0, left: 0 })
        .translate({ y: this.bottomShift * this.exitProgress })
        .padding(
          {
            top: this.formPaddingToHeight,
            bottom: this.bottomSafeAreaHeight,
            left: $r('sys.float.padding_level8'),
            right: $r('sys.float.padding_level8'),
          })
      }
      .height('100%')
      .width('100%')
      .opacity(1 - this.exitProgress)
      .onAreaChange((_old: Area, newArea: Area) => {
        this.pageHeight = newArea.height as number
      })
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .customTransition(this.navTransition)
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_UNLOCK)
      return true
    })
  }
}

@Builder
export function unlockPageBuilder() {
  UnlockPage()
}
