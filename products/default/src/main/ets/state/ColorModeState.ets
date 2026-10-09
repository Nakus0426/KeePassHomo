import { AppStorageV2 } from '@kit.ArkUI'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'

// 全应用共享单例：由 DefaultAbility 在 onCreate / onConfigurationUpdate 中更新
// 消费方通过 @Local 持有后读取 isDark，或用 @Monitor('colorMode.isDark') 监听
@ObservedV2
export class ColorModeState {
  @Trace isDark: boolean = false

  // 入参可能是 resourceManager 或 ConfigurationConstant 两套 ColorMode 枚举
  // 两者枚举数值一致（深色 0、浅色 1），故统一按数值比较
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
