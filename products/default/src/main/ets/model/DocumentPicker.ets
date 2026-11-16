import { common } from '@kit.AbilityKit'
import { picker } from '@kit.CoreFileKit'

// 用户取消选择而非真实失败：调用方应静默中止流程。
export class UserCancelledError extends Error {
  constructor() {
    super('用户取消了文件选择')
  }
}

// 选择器取消时返回空数组而没有错误码，统一在这一层转成可识别的取消。
export async function pickFiles(context: common.Context,
  options: picker.DocumentSelectOptions): Promise<string[]> {
  const uris: string[] = await new picker.DocumentViewPicker(context).select(options)
  if (uris.length === 0) {
    throw new UserCancelledError()
  }
  return uris
}

export async function pickSaveTarget(context: common.Context,
  options: picker.DocumentSaveOptions): Promise<string> {
  const uris: string[] = await new picker.DocumentViewPicker(context).save(options)
  if (uris.length === 0) {
    throw new UserCancelledError()
  }
  return uris[0]
}
