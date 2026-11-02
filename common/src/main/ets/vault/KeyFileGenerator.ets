import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { KdbxCredentials } from 'kdbxweb'
import { StrUtil } from '@pura/harmony-utils'

// 2.0 为 KeePass 2.47 起的 XML 密钥文件格式：十六进制数据 + 前 4 字节 SHA-256 完整性校验。
const KEY_FILE_VERSION: number = 2
const KEY_FILE_KEY_BYTES: number = 32

// 密钥材料取自平台 CSPRNG：kdbxweb 的 createRandomKeyFile 会把 Math.random 混入种子，不用于生成密钥。
@SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
export async function generateRandomKeyFile(): Promise<Uint8Array> {
  const keyBytes: Uint8Array = cryptoFramework.createRandom().generateRandomSync(KEY_FILE_KEY_BYTES).data
  try {
    return await KdbxCredentials.createKeyFileWithHash(keyBytes.buffer as ArrayBuffer, KEY_FILE_VERSION)
  } finally {
    keyBytes.fill(0)
  }
}

// 返回完整 64 位十六进制：截断发生在展示层，由 Text 的中间省略按可用宽度决定。
@SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
export function keyFileFingerprint(data: Uint8Array): string {
  const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data })
  return StrUtil.hexToStr(new Uint8Array(md.digestSync().data))
}
