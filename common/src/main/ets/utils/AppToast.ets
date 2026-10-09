import { promptAction, UIContext, uiMaterial } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { LogUtil } from '@pura/harmony-utils'

// ULTRA_THICK 沉浸材质无释放接口，可跨调用复用。
const TOAST_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
  style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
})

// 不用 @pura/harmony-utils 的 ToastUtil：其 ToastOptions 未声明 systemMaterial 字段，无法传入 API 26 沉浸材质。
export class AppToast {
  // 主窗内显示：半模态、对话框在场时会被盖住。
  static show(uiContext: UIContext, message: ResourceStr, duration?: number): void {
    AppToast.present(uiContext, message, promptAction.ToastShowMode.DEFAULT, duration)
  }

  // 显示在弹窗类组件之上：需在半模态关闭前给出反馈时使用。
  static showAboveSheets(uiContext: UIContext, message: ResourceStr, duration?: number): void {
    AppToast.present(uiContext, message, promptAction.ToastShowMode.TOP_MOST, duration)
  }

  private static present(uiContext: UIContext, message: ResourceStr,
    showMode: promptAction.ToastShowMode, duration?: number): void {
    try {
      uiContext.getPromptAction().showToast({
        message,
        duration,
        showMode,
        systemMaterial: TOAST_MATERIAL,
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`显示提示失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    }
  }
}
