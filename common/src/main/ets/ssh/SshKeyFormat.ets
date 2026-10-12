import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { Base64Util, LogUtil, RandomUtil } from '@pura/harmony-utils'
import { asciiBytes, base64Lines, concatBytes, fixedBytes, sshMpint, sshString, sshUint32 } from './SshWireFormat'

const ED25519_KEY_TYPE = 'ssh-ed25519'
const RSA_KEY_TYPE = 'ssh-rsa'
const ED25519_KEY_SIZE = 32
const OPENSSH_PEM_LINE_LENGTH = 70

export enum SshKeyAlgorithm {
  Ed25519 = 'Ed25519',
  Rsa2048 = 'RSA2048',
  Rsa3072 = 'RSA3072',
  Rsa4096 = 'RSA4096'
}

export interface SshKeyPairText {
  // Ed25519 为 OpenSSH 私钥容器 PEM，RSA 为 PKCS#8 PEM
  privateKey: string
  // 单行 OpenSSH 公钥，形如 "ssh-ed25519 AAAA..."
  publicKey: string
}

export async function generateSshKeyPair(algorithm: SshKeyAlgorithm): Promise<SshKeyPairText> {
  LogUtil.info(`SSH 密钥对生成开始，算法=${algorithm}`)
  const generator = cryptoFramework.createAsyKeyGenerator(algorithm)
  const keyPair = await generator.generateKeyPair()
  const result = algorithm === SshKeyAlgorithm.Ed25519 ? buildEd25519(keyPair) : buildRsa(keyPair)
  LogUtil.info(`SSH 密钥对生成完成，算法=${algorithm}`)
  return result
}

function buildEd25519(keyPair: cryptoFramework.KeyPair): SshKeyPairText {
  const publicKey = fixedBytes(
    keyPair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.ED25519_PK_BN) as bigint,
    ED25519_KEY_SIZE)
  const seed = fixedBytes(
    keyPair.priKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.ED25519_SK_BN) as bigint,
    ED25519_KEY_SIZE)
  const publicBlob = concatBytes([sshString(asciiBytes(ED25519_KEY_TYPE)), sshString(publicKey)])
  return {
    // getEncodedPem 官方只列举 RSA/EC/ML-DSA/ML-KEM，Ed25519 私钥只能按 OpenSSH 容器自建
    privateKey: encodeOpenSshPrivateKey(publicBlob, publicKey, seed),
    publicKey: `${ED25519_KEY_TYPE} ${Base64Util.encodeToStrSync(publicBlob)}`,
  }
}

function buildRsa(keyPair: cryptoFramework.KeyPair): SshKeyPairText {
  const modulus = keyPair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.RSA_N_BN) as bigint
  // RSA 公钥指数 e 在密钥参数枚举中名为 RSA_PK_BN，枚举内不存在 RSA_E_BN
  const exponent = keyPair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.RSA_PK_BN) as bigint
  const publicBlob = concatBytes([
    sshString(asciiBytes(RSA_KEY_TYPE)),
    sshMpint(exponent),
    sshMpint(modulus),
  ])
  return {
    privateKey: keyPair.priKey.getEncodedPem('PKCS8'),
    publicKey: `${RSA_KEY_TYPE} ${Base64Util.encodeToStrSync(publicBlob)}`,
  }
}

function encodeOpenSshPrivateKey(publicBlob: Uint8Array, publicKey: Uint8Array, seed: Uint8Array): string {
  // checkint 必须出现两次且取值相同，否则 OpenSSH 判定容器解密失败
  const checkint = RandomUtil.getRandomUint8Array(4)
  const body = concatBytes([
    checkint,
    checkint,
    sshString(asciiBytes(ED25519_KEY_TYPE)),
    sshString(publicKey),
    // OpenSSH 的 Ed25519 私钥字段是 64 字节：32 字节种子后接 32 字节公钥
    sshString(concatBytes([seed, publicKey])),
    sshString(new Uint8Array(0)),
  ])
  const privateSection = concatBytes([body, padding(body.length)])
  // ciphername 与 kdfname 均为 none：容器不加密，口令保护由上层条目决定
  const blob = concatBytes([
    asciiBytes('openssh-key-v1'),
    new Uint8Array([0]),
    sshString(asciiBytes('none')),
    sshString(asciiBytes('none')),
    sshString(new Uint8Array(0)),
    sshUint32(1),
    sshString(publicBlob),
    sshString(privateSection),
  ])
  const lines = base64Lines(blob, OPENSSH_PEM_LINE_LENGTH)
  return `-----BEGIN OPENSSH PRIVATE KEY-----\n${lines.join('\n')}\n-----END OPENSSH PRIVATE KEY-----\n`
}

// 填充字节从 0x01 递增；长度补到 8 的整数倍，已对齐时仍需补满 8 字节
function padding(length: number): Uint8Array {
  const size = 8 - (length % 8)
  const bytes = new Uint8Array(size)
  for (let i = 0; i < size; i++) {
    bytes[i] = i + 1
  }
  return bytes
}
