import { promptAction, UIContext, uiMaterial } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { LogUtil } from '@pura/harmony-utils'

/** 全局 Toast 材质：系统沉浸光感材质 ULTRA_THICK，无释放接口，可跨调用复用。 */
const TOAST_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
  style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
})

/**
 * 应用级 Toast 唯一入口。
 *
 * 不使用 @pura/harmony-utils 的 ToastUtil：其 ToastOptions 未声明 systemMaterial 字段，
 * 类型安全前提下无法传入 API 26 的系统沉浸光感材质，故此处自研封装，禁止降级回 ToastUtil。
 */
export class AppToast {
  /** 主窗内显示，层级低于弹窗类组件；半模态/对话框在场时会被盖住。duration 缺省走系统默认 1500ms。 */
  static show(uiContext: UIContext, message: ResourceStr, duration?: number): void {
    AppToast.present(uiContext, message, promptAction.ToastShowMode.DEFAULT, duration)
  }

  /**
   * 显示在弹窗类组件之上：半模态、对话框等在子窗中层级更高，
   * 需要在其关闭前就给出反馈时用这个模式（如校验失败但仍停留在半模态内）。
   */
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
