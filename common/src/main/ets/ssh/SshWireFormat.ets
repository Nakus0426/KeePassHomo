// SSH 线格式编码原语，字节布局依据 RFC 4251（RFC 4253 公钥格式、OpenSSH PROTOCOL.key）

import { Base64Util } from '@pura/harmony-utils'

export function asciiBytes(text: string): Uint8Array {
  // 本模块只编码 ASCII 常量，charCode 与 UTF-8 字节一致
  const bytes = new Uint8Array(text.length)
  for (let i = 0; i < text.length; i++) {
    bytes[i] = text.charCodeAt(i) & 0xff
  }
  return bytes
}

export function concatBytes(parts: Uint8Array[]): Uint8Array {
  let total = 0
  for (const part of parts) {
    total += part.length
  }
  const merged = new Uint8Array(total)
  let offset = 0
  for (const part of parts) {
    merged.set(part, offset)
    offset += part.length
  }
  return merged
}

export function sshString(payload: Uint8Array): Uint8Array {
  return concatBytes([sshUint32(payload.length), payload])
}

export function sshUint32(value: number): Uint8Array {
  const bytes = new Uint8Array(4)
  bytes[0] = (value >>> 24) & 0xff
  bytes[1] = (value >>> 16) & 0xff
  bytes[2] = (value >>> 8) & 0xff
  bytes[3] = value & 0xff
  return bytes
}

// bigint 转大端字节并按指定长度左补零，用于定长的 Ed25519 公钥与私钥种子
export function fixedBytes(value: bigint, length: number): Uint8Array {
  if (value < 0n) {
    throw new Error('密钥参数不能为负')
  }
  let probe: bigint = value
  let size: number = 0
  while (probe > 0n) {
    probe = probe >> 8n
    size++
  }
  // 平台返回超出目标长度说明密钥参数语义与预期不符：静默截断会产出不可用密钥，直接失败
  if (size > length) {
    throw new Error(`密钥参数长度超出预期：${size} 字节 > ${length} 字节`)
  }
  const bytes = new Uint8Array(length)
  let rest: bigint = value
  for (let i = length - 1; i >= 0; i--) {
    bytes[i] = Number(rest & 0xffn)
    rest = rest >> 8n
  }
  return bytes
}

// mpint 按 RFC 4251 作为有符号大整数编码，故最高位为 1 时必须前置 0x00
export function sshMpint(value: bigint): Uint8Array {
  const magnitude: number[] = []
  let rest = value
  while (rest > 0n) {
    magnitude.unshift(Number(rest & 0xffn))
    rest = rest >> 8n
  }
  if (magnitude.length > 0 && (magnitude[0] & 0x80) !== 0) {
    magnitude.unshift(0)
  }
  return sshString(new Uint8Array(magnitude))
}

export function base64Lines(data: Uint8Array, lineLength: number): string[] {
  const text = Base64Util.encodeToStrSync(data)
  const lines: string[] = []
  for (let start = 0; start < text.length; start += lineLength) {
    lines.push(text.substring(start, start + lineLength))
  }
  return lines
}
