import { common } from '@kit.AbilityKit'
import { UIContext } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { AppToast } from '@ohos/common'
import { FileUtil, LogUtil } from '@pura/harmony-utils'
import { SshKeyDraft } from './SshKeyPayload'

// 导出私钥明文：用户取消选择时静默返回，写入失败按导出失败提示。
export async function exportSshPrivateKey(uiContext: UIContext, key: SshKeyDraft): Promise<void> {
  try {
    const context = uiContext.getHostContext() as common.UIAbilityContext
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    options.newFileNames = [key.name]
    const uris: string[] = await new picker.DocumentViewPicker(context).save(options)
    if (uris === undefined || uris.length === 0) {
      return
    }
    const file: fileIo.File = FileUtil.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, key.privateKey)
    } finally {
      FileUtil.closeSync(file)
    }
    AppToast.showAboveSheets(uiContext, $r('app.string.ssh_key_export_success'))
  } catch (error) {
    const failure: BusinessError = error as BusinessError
    LogUtil.error(`导出 SSH 私钥失败，错误码=${failure.code}，错误信息=${failure.message}`)
    AppToast.showAboveSheets(uiContext, $r('app.string.ssh_key_pick_failed'))
  }
}
