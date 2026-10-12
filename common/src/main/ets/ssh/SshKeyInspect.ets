// SSH 私钥摘要：解析 OpenSSH 容器与 PKCS#1/PKCS#8 PEM，字节布局依据 OpenSSH PROTOCOL.key、RFC 4251、RFC 8017、RFC 8410
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { Base64Util } from '@pura/harmony-utils'
import { asciiBytes, concatBytes, fixedBytes, sshMpint, sshString } from './SshWireFormat'

const RSA_ALGORITHM = 'RSA'
const ED25519_ALGORITHM = 'Ed25519'
const RSA_KEY_TYPE = 'ssh-rsa'
const ED25519_KEY_TYPE = 'ssh-ed25519'
const RSA_KEY_TYPE_BYTES = asciiBytes(RSA_KEY_TYPE)
const ED25519_KEY_TYPE_BYTES = asciiBytes(ED25519_KEY_TYPE)
const ED25519_KEY_SIZE = 32
const ED25519_BITS = 256

const OPENSSH_HEADER = '-----BEGIN OPENSSH PRIVATE KEY-----'
const OPENSSH_FOOTER = '-----END OPENSSH PRIVATE KEY-----'
const PKCS1_HEADER = '-----BEGIN RSA PRIVATE KEY-----'
const PKCS1_FOOTER = '-----END RSA PRIVATE KEY-----'
const PKCS8_HEADER = '-----BEGIN PRIVATE KEY-----'
const PKCS8_FOOTER = '-----END PRIVATE KEY-----'
// openssh-key-v1 魔数结尾带一个 NUL，共 15 字节
const OPENSSH_MAGIC = asciiBytes('openssh-key-v1\u0000')

// 平台解码遇到字母表外字符会抛错，非法 Base64 必须在本模块内先判定为返回值
const PEM_BASE64 = /^[A-Za-z0-9+/]+={0,2}$/

const DER_INTEGER = 0x02
const DER_OID = 0x06
const DER_OCTET_STRING = 0x04
const DER_SEQUENCE = 0x30

// rsaEncryption 1.2.840.113549.1.1.1 与 id-Ed25519 1.3.101.112 的 DER 编码
const RSA_OID = new Uint8Array([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01])
const ED25519_OID = new Uint8Array([0x2b, 0x65, 0x70])

export interface SshKeyInspection {
  algorithm: string;
  bits: number;
  publicKey: string;
}

// 无法识别的形态（EC、加密 PEM、无头部、Base64 或 DER 非法）一律返回 undefined，不抛异常
export function inspectSshPrivateKey(text: string): SshKeyInspection | undefined {
  // 粘贴内容可能带 CRLF 与首尾空白，去掉 \r 后按行处理
  const lines = text.replace(/\r/g, '').trim().split('\n')
  const openssh = pemBody(lines, OPENSSH_HEADER, OPENSSH_FOOTER)
  if (openssh !== undefined) {
    return inspectOpenSsh(openssh)
  }
  const pkcs1 = pemBody(lines, PKCS1_HEADER, PKCS1_FOOTER)
  if (pkcs1 !== undefined) {
    return inspectPkcs1(Base64Util.decodeSync(pkcs1))
  }
  const pkcs8 = pemBody(lines, PKCS8_HEADER, PKCS8_FOOTER)
  if (pkcs8 !== undefined) {
    return inspectPkcs8(Base64Util.decodeSync(pkcs8))
  }
  return undefined
}

// 取首行标签与结束标签之间的 Base64 正文，标签不符、缺结束标签或字符集非法都视为不支持
function pemBody(lines: string[], header: string, footer: string): string | undefined {
  if (lines[0].trim() !== header) {
    return undefined
  }
  const parts: string[] = []
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim()
    if (line === footer) {
      const body = parts.join('')
      return PEM_BASE64.test(body) && body.length % 4 === 0 ? body : undefined
    }
    parts.push(line)
  }
  return undefined
}

// 顺序读取游标：SSH 长度前缀与 DER 长度域都决定边界，越界即判定为不支持
class Cursor {
  private readonly data: Uint8Array
  private position: number = 0

  constructor(data: Uint8Array) {
    this.data = data
  }

  read(length: number): Uint8Array | undefined {
    if (length < 0 || this.position + length > this.data.length) {
      return undefined
    }
    const part = this.data.subarray(this.position, this.position + length)
    this.position += length
    return part
  }
}

function readUint32(cursor: Cursor): number | undefined {
  const bytes = cursor.read(4)
  if (bytes === undefined) {
    return undefined
  }
  return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) >>> 0
}

function readSshString(cursor: Cursor): Uint8Array | undefined {
  const length = readUint32(cursor)
  return length === undefined ? undefined : cursor.read(length)
}

function skipSshString(cursor: Cursor): boolean {
  return readSshString(cursor) !== undefined
}

function readDerLength(cursor: Cursor): number | undefined {
  const first = cursor.read(1)
  if (first === undefined) {
    return undefined
  }
  if ((first[0] & 0x80) === 0) {
    return first[0]
  }
  const count = first[0] & 0x7f
  // 不定长与超过 4 字节的长度域不出现在密钥结构中
  if (count === 0 || count > 4) {
    return undefined
  }
  const bytes = cursor.read(count)
  if (bytes === undefined) {
    return undefined
  }
  let length = 0
  for (let i = 0; i < count; i++) {
    length = length * 256 + bytes[i]
  }
  return length
}

function readDerElement(cursor: Cursor, tag: number): Uint8Array | undefined {
  const actual = cursor.read(1)
  if (actual === undefined || actual[0] !== tag) {
    return undefined
  }
  const length = readDerLength(cursor)
  return length === undefined ? undefined : cursor.read(length)
}

// PKCS#1 与 PKCS#8 都从顶层 SEQUENCE 开始，取出其载荷游标
function derSequenceBody(der: Uint8Array): Cursor | undefined {
  const element = readDerElement(new Cursor(der), DER_SEQUENCE)
  return element === undefined ? undefined : new Cursor(element)
}

function bytesEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) {
    return false
  }
  for (let i = 0; i < left.length; i++) {
    if (left[i] !== right[i]) {
      return false
    }
  }
  return true
}

// SSH mpint 与 DER INTEGER 同为有符号大端编码，摘要只涉及正数，按无符号累加即可
function unsignedBigint(bytes: Uint8Array): bigint {
  let value = 0n
  for (let i = 0; i < bytes.length; i++) {
    value = (value << 8n) | BigInt(bytes[i])
  }
  return value
}

function bitLength(value: bigint): number {
  let bits = 0
  let rest = value
  while (rest > 0n) {
    rest = rest >> 1n
    bits++
  }
  return bits
}

function inspectOpenSsh(body: string): SshKeyInspection | undefined {
  const cursor = new Cursor(Base64Util.decodeSync(body))
  const magic = cursor.read(OPENSSH_MAGIC.length)
  if (magic === undefined || !bytesEqual(magic, OPENSSH_MAGIC)) {
    return undefined
  }
  // ciphername/kdfname/kdfoptions 内容与摘要无关；容器即使被口令加密，公钥 blob 仍位于明文头部
  for (let i = 0; i < 3; i++) {
    if (!skipSshString(cursor)) {
      return undefined
    }
  }
  if (readUint32(cursor) !== 1) {
    return undefined
  }
  const publicBlob = readSshString(cursor)
  return publicBlob === undefined ? undefined : inspectPublicBlob(publicBlob)
}

function inspectPublicBlob(blob: Uint8Array): SshKeyInspection | undefined {
  const cursor = new Cursor(blob)
  const keyType = readSshString(cursor)
  if (keyType === undefined) {
    return undefined
  }
  if (bytesEqual(keyType, ED25519_KEY_TYPE_BYTES)) {
    const publicKey = readSshString(cursor)
    if (publicKey === undefined || publicKey.length !== ED25519_KEY_SIZE) {
      return undefined
    }
    return {
      algorithm: ED25519_ALGORITHM,
      bits: ED25519_BITS,
      publicKey: `${ED25519_KEY_TYPE} ${Base64Util.encodeToStrSync(blob)}`,
    }
  }
  if (bytesEqual(keyType, RSA_KEY_TYPE_BYTES)) {
    // e 仅用于推进游标，公钥行可直接复用整个 blob
    if (!skipSshString(cursor)) {
      return undefined
    }
    const modulus = readSshString(cursor)
    if (modulus === undefined) {
      return undefined
    }
    return {
      algorithm: RSA_ALGORITHM,
      bits: bitLength(unsignedBigint(modulus)),
      publicKey: `${RSA_KEY_TYPE} ${Base64Util.encodeToStrSync(blob)}`,
    }
  }
  return undefined
}

function inspectPkcs1(der: Uint8Array): SshKeyInspection | undefined {
  const cursor = derSequenceBody(der)
  if (cursor === undefined) {
    return undefined
  }
  // RSAPrivateKey 为 version、modulus、publicExponent，version 仅用于推进游标
  if (readDerElement(cursor, DER_INTEGER) === undefined) {
    return undefined
  }
  const modulus = readDerElement(cursor, DER_INTEGER)
  const exponent = readDerElement(cursor, DER_INTEGER)
  if (modulus === undefined || exponent === undefined) {
    return undefined
  }
  const n = unsignedBigint(modulus)
  const publicBlob = concatBytes([
    sshString(RSA_KEY_TYPE_BYTES),
    sshMpint(unsignedBigint(exponent)),
    sshMpint(n),
  ])
  return {
    algorithm: RSA_ALGORITHM,
    bits: bitLength(n),
    publicKey: `${RSA_KEY_TYPE} ${Base64Util.encodeToStrSync(publicBlob)}`,
  }
}

function inspectPkcs8(der: Uint8Array): SshKeyInspection | undefined {
  const cursor = derSequenceBody(der)
  if (cursor === undefined) {
    return undefined
  }
  // PrivateKeyInfo 为 version、AlgorithmIdentifier、privateKey OCTET STRING
  if (readDerElement(cursor, DER_INTEGER) === undefined) {
    return undefined
  }
  const algorithm = readDerElement(cursor, DER_SEQUENCE)
  if (algorithm === undefined) {
    return undefined
  }
  const oid = readDerElement(new Cursor(algorithm), DER_OID)
  const privateKey = readDerElement(cursor, DER_OCTET_STRING)
  if (oid === undefined || privateKey === undefined) {
    return undefined
  }
  if (bytesEqual(oid, RSA_OID)) {
    return inspectPkcs1(privateKey)
  }
  if (bytesEqual(oid, ED25519_OID)) {
    return inspectEd25519(der)
  }
  return undefined
}

function inspectEd25519(der: Uint8Array): SshKeyInspection | undefined {
  const raw = ed25519RawPublicKey(der)
  if (raw === undefined) {
    return undefined
  }
  const publicBlob = concatBytes([sshString(ED25519_KEY_TYPE_BYTES), sshString(raw)])
  return {
    algorithm: ED25519_ALGORITHM,
    bits: ED25519_BITS,
    publicKey: `${ED25519_KEY_TYPE} ${Base64Util.encodeToStrSync(publicBlob)}`,
  }
}

// 平台只接受完整 PKCS#8 DER，且拒绝该材料时以 17620003/17630001 抛错，此处按契约转成返回值
function ed25519RawPublicKey(der: Uint8Array): Uint8Array | undefined {
  try {
    const keyPair = cryptoFramework.createAsyKeyGenerator(ED25519_ALGORITHM).convertKeySync(null, { data: der })
    const publicKey = keyPair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.ED25519_PK_BN) as bigint
    // 平台给出的是曲线点标量，需还原为 32 字节裸公钥
    return fixedBytes(publicKey, ED25519_KEY_SIZE)
  } catch (error) {
    return undefined
  }
}
