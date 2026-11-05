import { EyeMorphShape } from './EyeMorphShape'
import { MorphShape } from './MorphShape'
import { StepMorphShape } from './StepMorphShape'
import { CLOUD_CHECK_MORPH, FACT_CHECK_MORPH, FOLDER_CHECK_MORPH, LOCK_CHECK_MORPH } from './StepMorphData'

let eyeShape: MorphShape | undefined = undefined
let cloudCheckShape: MorphShape | undefined = undefined
let folderCheckShape: MorphShape | undefined = undefined
let lockCheckShape: MorphShape | undefined = undefined
let factCheckShape: MorphShape | undefined = undefined

// 形变几何按图标对预生成；新增对需在 tools/icon-migration 补数据后在此登记。
export function findMorphShape(iconOff: Resource, iconOn: Resource): MorphShape | undefined {
  if (iconOff.id === $r('app.string.symbol_eye_off').id && iconOn.id === $r('app.string.symbol_eye').id) {
    if (eyeShape === undefined) {
      eyeShape = new EyeMorphShape()
    }
    return eyeShape
  }
  if (iconOn.id !== $r('app.string.symbol_check').id) {
    return undefined
  }
  if (iconOff.id === $r('app.string.symbol_cloud_sync').id) {
    if (cloudCheckShape === undefined) {
      cloudCheckShape = new StepMorphShape(CLOUD_CHECK_MORPH)
    }
    return cloudCheckShape
  }
  if (iconOff.id === $r('app.string.symbol_folder').id) {
    if (folderCheckShape === undefined) {
      folderCheckShape = new StepMorphShape(FOLDER_CHECK_MORPH)
    }
    return folderCheckShape
  }
  if (iconOff.id === $r('app.string.symbol_lock').id) {
    if (lockCheckShape === undefined) {
      lockCheckShape = new StepMorphShape(LOCK_CHECK_MORPH)
    }
    return lockCheckShape
  }
  if (iconOff.id === $r('app.string.symbol_fact_check').id) {
    if (factCheckShape === undefined) {
      factCheckShape = new StepMorphShape(FACT_CHECK_MORPH)
    }
    return factCheckShape
  }
  return undefined
}
