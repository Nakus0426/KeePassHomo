import { UIContext } from '@kit.ArkUI'
import { DsToastHost } from '../../components/DsToast'
import { AppViewModel } from '../../viewmodel/AppViewModel'

// 分组选择器的新建入口共用：成功提示固定文案，失败沿用 ViewModel 写入的状态文案。
export function createGroupFromPicker(context: UIContext, app: AppViewModel, parentUuid: string, name: string): void {
  app.createGroup(parentUuid, name).then((created: boolean) => {
    if (created) {
      DsToastHost.show(context, $r('app.string.group_created'))
      return
    }
    if (app.status.length > 0) {
      DsToastHost.show(context, app.status)
    }
  })
}
