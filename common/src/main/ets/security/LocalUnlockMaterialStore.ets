import { util } from '@kit.ArkTS'
import { asset } from '@kit.AssetStoreKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { userAuth } from '@kit.UserAuthenticationKit'

const LOCAL_UNLOCK_ALIAS: Uint8Array = new util.TextEncoder().encodeInto('KeePassHomo.LocalUnlockMaterial')

export class LocalUnlockMaterialStore {
  async save(material: Uint8Array): Promise<void> {
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    attributes.set(asset.Tag.SECRET, material)
    attributes.set(asset.Tag.ALIAS, LOCAL_UNLOCK_ALIAS)
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED)
    attributes.set(asset.Tag.REQUIRE_PASSWORD_SET, true)
    attributes.set(asset.Tag.AUTH_TYPE, asset.AuthType.ANY)
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    await asset.add(attributes)
  }

  async readAfterAuthentication(): Promise<Uint8Array> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, LOCAL_UNLOCK_ALIAS)
    const challenge = await asset.preQuery(query)
    try {
      const token = await this.authenticate(challenge)
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
      query.set(asset.Tag.AUTH_CHALLENGE, challenge)
      query.set(asset.Tag.AUTH_TOKEN, token)
      const results = await asset.query(query)
      if (results.length !== 1) {
        throw new Error('本机快速解锁材料查询结果无效')
      }
      return results[0].get(asset.Tag.SECRET) as Uint8Array
    } finally {
      const handle: asset.AssetMap = new Map<asset.Tag, asset.Value>()
      handle.set(asset.Tag.AUTH_CHALLENGE, challenge)
      await asset.postQuery(handle)
    }
  }

  async remove(): Promise<void> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, LOCAL_UNLOCK_ALIAS)
    await asset.remove(query)
  }

  async verifyRoute(): Promise<void> {
    const randomData: cryptoFramework.DataBlob = await cryptoFramework.createRandom().generateRandom(32)
    const material = randomData.data
    await this.save(material)
    try {
      const restored = await this.readAfterAuthentication()
      try {
        if (!this.bytesEqual(material, restored)) {
          throw new Error('本机快速解锁材料读回不一致')
        }
      } finally {
        restored.fill(0)
      }
    } finally {
      try {
        await this.remove()
      } finally {
        material.fill(0)
      }
    }
  }

  private authenticate(challenge: Uint8Array): Promise<Uint8Array> {
    const authParam: userAuth.AuthParam = {
      challenge,
      authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
      authTrustLevel: userAuth.AuthTrustLevel.ATL2,
      skipLockedBiometricAuth: true,
    }
    const widgetParam: userAuth.WidgetParam = {
      title: '验证本机快速解锁材料',
    }
    const authInstance = userAuth.getUserAuthInstance(authParam, widgetParam)
    return new Promise<Uint8Array>((resolve, reject) => {
      const callback: userAuth.IAuthCallback = {
        onResult: (result: userAuth.UserAuthResult): void => {
          authInstance.off('result', callback)
          if (result.result !== userAuth.UserAuthResultCode.SUCCESS || result.token === undefined) {
            reject(new Error(`系统用户认证失败，错误码：${result.result}`))
            return
          }
          resolve(result.token)
        },
      }
      authInstance.on('result', callback)
      authInstance.start()
    })
  }

  private bytesEqual(left: Uint8Array, right: Uint8Array): boolean {
    if (left.length !== right.length) {
      return false
    }
    for (let index = 0; index < left.length; index++) {
      if (left[index] !== right[index]) {
        return false
      }
    }
    return true
  }
}
