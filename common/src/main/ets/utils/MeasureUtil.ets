import { ResUtil } from '@pura/harmony-utils'

// 读尺寸 Token 的数值（vp），供需要做几何运算的组件使用。
export function measureVp(uiContext: UIContext, resource: Resource): number {
  return uiContext.px2vp(ResUtil.getNumber(resource.id))
}
