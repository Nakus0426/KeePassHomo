import { EyeMorphShape } from './EyeMorphShape'
import { MorphShape } from './MorphShape'

let eyeShape: MorphShape | undefined = undefined

// 形变几何按图标对预生成；新增对需在 tools/icon-migration/generate_morph.py 补数据后在此登记
export function findMorphShape(iconOff: Resource, iconOn: Resource): MorphShape | undefined {
  if (iconOff.id === $r('app.string.symbol_eye_off').id && iconOn.id === $r('app.string.symbol_eye').id) {
    if (eyeShape === undefined) {
      eyeShape = new EyeMorphShape()
    }
    return eyeShape
  }
  return undefined
}
