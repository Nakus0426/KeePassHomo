import { common } from '@kit.AbilityKit'
import { UIContext } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { FileUtil, LogUtil } from '@pura/harmony-utils'
import { SshKeyDraft } from './SshKeyPayload'
import { DsToastHost } from '../components/DsToast'
import { pickSaveTarget, UserCancelledError } from './DocumentPicker'

// 导出私钥明文：用户取消选择时静默返回，写入失败按导出失败提示。
export async function exportSshPrivateKey(uiContext: UIContext, key: SshKeyDraft): Promise<void> {
  try {
    const context = uiContext.getHostContext() as common.UIAbilityContext
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    options.newFileNames = [key.name]
    const uri: string = await pickSaveTarget(context, options)
    const file: fileIo.File = FileUtil.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, key.privateKey)
    } finally {
      FileUtil.closeSync(file)
    }
    DsToastHost.show(uiContext, $r('app.string.ssh_key_export_success'))
  } catch (error) {
    if (error instanceof UserCancelledError) {
      return
    }
    const failure: BusinessError = error as BusinessError
    LogUtil.error(`导出 SSH 私钥失败，错误码=${failure.code}，错误信息=${failure.message}`)
    DsToastHost.show(uiContext, $r('app.string.ssh_key_pick_failed'))
  }
}
