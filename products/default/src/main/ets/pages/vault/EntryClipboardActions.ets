import { UIContext } from '@kit.ArkUI'
import { DsToastHost } from '../../components/DsToast'
import { AppViewModel } from '../../viewmodel/AppViewModel'

// 条目字段复制的统一入口：空值不写剪贴板，成功提示固定文案。
export function copyEntryValue(context: UIContext, app: AppViewModel, value: string): Promise<boolean> {
  if (value.length === 0) {
    return Promise.resolve(false)
  }
  return app.copyValue(value).then((copied: boolean) => {
    if (copied) {
      DsToastHost.show(context, $r('app.string.copy_completed'))
    }
    return copied
  })
}
