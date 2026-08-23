import { pasteboard } from '@kit.BasicServicesKit'

const SENSITIVE_CLIPBOARD_TAG: string = 'KeePassHomo.Sensitive'

export interface ClipboardWriteToken {
  changeCount: number;
}

export class SecureClipboard {
  async write(text: string): Promise<ClipboardWriteToken> {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
    const property = data.getProperty()
    property.tag = SENSITIVE_CLIPBOARD_TAG
    property.shareOption = pasteboard.ShareOption.LOCALDEVICE
    data.setProperty(property)
    const systemPasteboard = pasteboard.getSystemPasteboard()
    try {
      await systemPasteboard.setData(data)
    } catch (error) {
      throw new Error((error as Error).message)
    }
    return { changeCount: systemPasteboard.getChangeCount() }
  }

  async clearIfOwned(token: ClipboardWriteToken): Promise<boolean> {
    const systemPasteboard = pasteboard.getSystemPasteboard()
    if (systemPasteboard.getChangeCount() !== token.changeCount) {
      return false
    }
    await systemPasteboard.clearData()
    return true
  }
}
