import { AppStorageV2 } from '@kit.ArkUI'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'

/**
 * 全应用共享的深浅色模式状态。
 * 由 DefaultAbility 在 onCreate 与 onConfigurationUpdate 中更新，
 * 页面与组件通过 AppStorageV2 单例订阅（@Local 持有后读取 isDark，或 @Monitor('colorMode.isDark') 监听）。
 */
@ObservedV2
export class ColorModeState {
  @Trace isDark: boolean = false

  /**
   * 更新深浅色状态。
   * 初始值来自 resourceManager.getConfigurationSync()（resourceManager.ColorMode），
   * 变化值来自 onConfigurationUpdate（ConfigurationConstant.ColorMode）；
   * 两个枚举数值一致（深色 0、浅色 1），统一按数值比较。
   */
  update(colorMode: ConfigurationConstant.ColorMode | resourceManager.ColorMode | undefined): void {
    if (colorMode === undefined) {
      return
    }
    this.isDark = (colorMode as number) === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
  }
}

export const colorModeState: ColorModeState = AppStorageV2.connect(
  ColorModeState,
  'colorMode',
  () => new ColorModeState(),
) as ColorModeState
