import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit'

const READ_PASTEBOARD: Permissions = 'ohos.permission.READ_PASTEBOARD'

// 未在 module.json5 声明该受限权限时系统按未授权返回，故无需区分「未声明」与「用户拒绝」。
export function isPasteboardReadGranted(): boolean {
  const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
    bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
  const status: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.createAtManager()
    .checkAccessTokenSync(info.appInfo.accessTokenId, READ_PASTEBOARD)
  return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
}

// 受限权限需用户授权：返回 true 表示本次已获授权，false 表示被拒绝或当前不可申请。
export async function requestPasteboardRead(context: common.UIAbilityContext): Promise<boolean> {
  const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
  const result = await manager.requestPermissionsFromUser(context, [READ_PASTEBOARD])
  return result.authResults.length > 0
    && result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
}
