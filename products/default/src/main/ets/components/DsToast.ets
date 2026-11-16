import { ComponentContent, UIContext } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { LogUtil } from '@pura/harmony-utils'

const TOAST_DURATION: number = 2000
const TOAST_BOTTOM_OFFSET: number = -80
const TOAST_MAX_WIDTH: number = 350
const TOAST_LINE_HEIGHT: number = 18

export enum DsToastTone {
  Default = 'default',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

class ToastParams {
  message: ResourceStr
  tone: DsToastTone

  constructor(message: ResourceStr, tone: DsToastTone) {
    this.message = message
    this.tone = tone
  }
}

@Builder
function toastContent(params: ToastParams) {
  DsToast({ message: params.message, tone: params.tone })
}

const TOAST_CONTENT: WrappedBuilder<[ToastParams]> = wrapBuilder(toastContent)

@ComponentV2
export struct DsToast {
  @Param message: ResourceStr = ''
  @Param tone: DsToastTone = DsToastTone.Default

  // 四档语义只换 sharp 轮廓图标；default 不带图标，靠文案独立成立。
  @Computed
  get icon(): Resource | undefined {
    switch (this.tone) {
      case DsToastTone.Success:
        return $r('app.string.symbol_check_box_sharp')
      case DsToastTone.Warning:
        return $r('app.string.symbol_warning_sharp')
      case DsToastTone.Error:
        return $r('app.string.symbol_disabled_by_default_sharp')
      default:
        return undefined
    }
  }

  build() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      if (this.icon !== undefined) {
        SymbolGlyph(this.icon)
          .fontSize($r('app.float.ds_icon_xs'))
          .fontColor([$r('app.color.ds_inverse_primary')])
          .foregroundColor($r('app.color.ds_inverse_primary'))
      }
      Text(this.message)
        .fontSize($r('app.float.ds_font_body_sm'))
        .lineHeight(TOAST_LINE_HEIGHT)
        .fontColor($r('app.color.ds_inverse_on_surface'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
    }
    .constraintSize({ maxWidth: TOAST_MAX_WIDTH })
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_space_16'),
      right: $r('app.float.ds_space_16'),
    })
    .backgroundColor($r('app.color.ds_inverse_surface'))
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
  }
}

// 用非模态自绘弹窗承载轻提示：系统 showToast 无法设置字号、圆角与图标。
export class DsToastHost {
  private static content: ComponentContent<ToastParams> | undefined = undefined
  private static timerId: number = -1

  static show(uiContext: UIContext, message: ResourceStr, tone: DsToastTone = DsToastTone.Default): void {
    DsToastHost.present(uiContext, message, tone).catch((error: BusinessError) => {
      LogUtil.error(`显示轻提示失败，错误码=${error.code}，错误信息=${error.message}`)
    })
  }

  private static async present(uiContext: UIContext, message: ResourceStr, tone: DsToastTone): Promise<void> {
    await DsToastHost.dismiss(uiContext)
    // ComponentContent 不依赖组件实例，openCustomDialog 的 builder 形式无法在组件外构造自定义组件。
    const content: ComponentContent<ToastParams> =
      new ComponentContent(uiContext, TOAST_CONTENT, new ToastParams(message, tone))
    DsToastHost.content = content
    // 计时必须在 openCustomDialog 之前启动：该 Promise 在部分场景不会兑现，不能作为自动消失的前提。
    DsToastHost.timerId = setTimeout(() => {
      DsToastHost.dismiss(uiContext).catch((error: BusinessError) => {
        LogUtil.error(`关闭轻提示失败，错误码=${error.code}，错误信息=${error.message}`)
      })
    }, TOAST_DURATION)
    await uiContext.getPromptAction().openCustomDialog(content, {
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: TOAST_BOTTOM_OFFSET },
      isModal: false,
      autoCancel: false,
      focusable: false,
      // 自定义 transition 会与关闭时机冲突，残留最后一帧；改用系统弹窗自带的缩放 + 淡入淡出。
      onDidDisappear: () => {
        if (DsToastHost.content === content) {
          DsToastHost.content = undefined
          clearTimeout(DsToastHost.timerId)
          DsToastHost.timerId = -1
        }
        content.dispose()
      },
    })
  }

  private static async dismiss(uiContext: UIContext): Promise<void> {
    if (DsToastHost.timerId !== -1) {
      clearTimeout(DsToastHost.timerId)
      DsToastHost.timerId = -1
    }
    const content: ComponentContent<ToastParams> | undefined = DsToastHost.content
    if (content === undefined) {
      return
    }
    DsToastHost.content = undefined
    try {
      await uiContext.getPromptAction().closeCustomDialog(content)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`关闭轻提示失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
      content.dispose()
    }
  }
}
