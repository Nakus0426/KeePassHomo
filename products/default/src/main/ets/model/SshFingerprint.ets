import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { Base64Util, LogUtil } from '@pura/harmony-utils'

// OpenSSH 指纹是公钥 blob 的 SHA-256 再 Base64，且不带补位等号。
export function sshPublicKeyFingerprint(publicKey: string): string {
  const parts: string[] = publicKey.trim().split(' ')
  if (parts.length < 2) {
    return ''
  }
  try {
    const blob: Uint8Array = Base64Util.decodeSync(parts[1])
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: blob })
    return Base64Util.encodeToStrSync(new Uint8Array(md.digestSync().data)).replace(/=+$/, '')
  } catch (error) {
    LogUtil.error(`SSH 公钥指纹计算失败，错误信息=${(error as Error).message}`)
    return ''
  }
}
