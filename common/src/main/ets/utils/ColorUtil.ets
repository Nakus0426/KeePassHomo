import { ResUtil } from '@pura/harmony-utils'

export interface ColorMetricsLike {
  getColor(): ResourceColor
}

// Resource 资源色解析后色值固化，深浅色切换不会自动更新，需跟随色调时应重新调用；
// ColorMetrics 仅支持下入参，出参形态需在 UI 层用 ColorMetrics.createColor(withAlpha(...)) 包装。
export class ColorUtil {
  static withAlpha(color: ResourceColor | ColorMetricsLike, alpha: number): number {
    if (!(alpha >= 0 && alpha <= 1)) {
      throw new Error(`透明度取值非法：${alpha}，应在 [0, 1] 区间`)
    }
    const alphaChannel: number = Math.round(alpha * 255)
    const argb: number = ColorUtil.resolveToArgb(color)
    return ((argb & 0x00FFFFFF) | (alphaChannel << 24)) >>> 0
  }

  // linearGradient 的零透明度颜色须用字符串，数值型 0x00RRGGBB 会被 ArkUI 忽略 Alpha 通道。
  static withAlphaHex(color: ResourceColor | ColorMetricsLike, alpha: number): string {
    if (!(alpha >= 0 && alpha <= 1)) {
      throw new Error(`透明度取值非法：${alpha}，应在 [0, 1] 区间`)
    }
    const alphaChannel: number = Math.round(alpha * 255)
    const argb: number = ColorUtil.resolveToArgb(color)
    return `#${ColorUtil.toHexByte(alphaChannel)}${ColorUtil.toHexByte((argb >> 16) & 0xFF)}${ColorUtil.toHexByte(
      (argb >> 8) & 0xFF)}${ColorUtil.toHexByte(argb & 0xFF)}`
  }

  private static resolveToArgb(color: ResourceColor | ColorMetricsLike): number {
    if (typeof color === 'number') {
      return color
    }
    if (typeof color === 'string') {
      return ColorUtil.parseHexString(color)
    }
    const resource: Resource = color as Resource
    if (typeof resource.id === 'number') {
      return ResUtil.getColorSync(resource.id)
    }
    return ColorUtil.resolveToArgb((color as ColorMetricsLike).getColor())
  }

  private static parseHexString(value: string): number {
    if (!value.startsWith('#')) {
      throw new Error(`不支持的颜色字符串：${value}`)
    }
    const hex: string = value.substring(1)
    let a: number = 255
    let r: number = 0
    let g: number = 0
    let b: number = 0
    switch (hex.length) {
      case 3:
        r = ColorUtil.digitPair(hex, 0)
        g = ColorUtil.digitPair(hex, 2)
        b = ColorUtil.digitPair(hex, 4)
        break
      case 4:
        a = ColorUtil.digitPair(hex, 0)
        r = ColorUtil.digitPair(hex, 2)
        g = ColorUtil.digitPair(hex, 4)
        b = ColorUtil.digitPair(hex, 6)
        break
      case 6:
        r = ColorUtil.byteValue(hex, 0)
        g = ColorUtil.byteValue(hex, 2)
        b = ColorUtil.byteValue(hex, 4)
        break
      case 8:
        a = ColorUtil.byteValue(hex, 0)
        r = ColorUtil.byteValue(hex, 2)
        g = ColorUtil.byteValue(hex, 4)
        b = ColorUtil.byteValue(hex, 6)
        break
      default:
        throw new Error(`不支持的颜色字符串：${value}`)
    }
    return ((a << 24) | (r << 16) | (g << 8) | b) >>> 0
  }

  private static digitPair(hex: string, index: number): number {
    const digit: number = parseInt(hex.charAt(index), 16)
    if (Number.isNaN(digit)) {
      throw new Error(`颜色字符串包含非法字符：${hex.charAt(index)}`)
    }
    return digit * 17
  }

  private static byteValue(hex: string, index: number): number {
    const value: number = parseInt(hex.substring(index, index + 2), 16)
    if (Number.isNaN(value)) {
      throw new Error(`颜色字符串包含非法字符：${hex.substring(index, index + 2)}`)
    }
    return value
  }

  private static toHexByte(value: number): string {
    const hex: string = value.toString(16).toUpperCase()
    return hex.length === 1 ? `0${hex}` : hex
  }
}
