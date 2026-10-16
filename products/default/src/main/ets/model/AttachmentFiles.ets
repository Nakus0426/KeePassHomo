import { common } from '@kit.AbilityKit'
import { UIContext } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { AppToast } from '@ohos/common'
import { FileUtil, LogUtil, PreviewUtil } from '@pura/harmony-utils'

// 预览临时目录：系统预览窗口按需读取该文件，且系统不提供预览关闭回调，只能在下次预览前清空。
const PREVIEW_DIR: string = 'attachment_preview'

// 导出附件明文：用户取消选择时静默返回；字节在认证通过后才回读，避免认证失败时提前解密。
export async function exportAttachment(uiContext: UIContext, name: string,
  readData: () => ArrayBuffer): Promise<void> {
  try {
    const context = uiContext.getHostContext() as common.UIAbilityContext
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    options.newFileNames = [name]
    const uris: string[] = await new picker.DocumentViewPicker(context).save(options)
    if (uris === undefined || uris.length === 0) {
      return
    }
    const file: fileIo.File = FileUtil.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, readData())
    } finally {
      FileUtil.closeSync(file)
    }
    AppToast.showAboveSheets(uiContext, $r('app.string.attachment_export_saved'))
  } catch (error) {
    const failure: BusinessError = error as BusinessError
    LogUtil.error(`导出附件失败，附件名=${name}，错误码=${failure.code}，错误信息=${failure.message}`)
    AppToast.showAboveSheets(uiContext, $r('app.string.attachment_export_failed'))
  }
}

// 系统预览只认 uri 且必须跳出应用，故先把明文写进沙箱缓存目录，再交给预览窗口。
export async function previewAttachment(uiContext: UIContext, name: string,
  readData: () => ArrayBuffer): Promise<void> {
  try {
    const dir: string = FileUtil.getCacheDirPath(PREVIEW_DIR)
    for (const entry of FileUtil.listFileSync(dir)) {
      FileUtil.unlinkSync(`${dir}${FileUtil.separator}${entry}`)
    }
    const path: string = `${dir}${FileUtil.separator}${name}`
    const file: fileIo.File = FileUtil.openSync(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, readData())
    } finally {
      FileUtil.closeSync(file)
    }
    const uri: string = FileUtil.getUriFromPath(path)
    if (!PreviewUtil.canIUsePreview() || !(await PreviewUtil.canPreview(uri))) {
      // 不交给预览窗口的明文不留在缓存里。
      FileUtil.unlinkSync(path)
      AppToast.showAboveSheets(uiContext, $r('app.string.attachment_preview_unsupported'))
      return
    }
    await PreviewUtil.openPreviewEasy(uri)
  } catch (error) {
    const failure: BusinessError = error as BusinessError
    LogUtil.error(`预览附件失败，附件名=${name}，错误码=${failure.code}，错误信息=${failure.message}`)
    AppToast.showAboveSheets(uiContext, $r('app.string.attachment_preview_failed'))
  }
}
