import { DateUtil, LogUtil } from '@pura/harmony-utils'

// 一个条目内的多条 SSH 密钥序列化进受保护字段 SshKeys；键名与模板定义一致。
export const SSH_KEYS_FIELD: string = 'SshKeys'

const PAYLOAD_VERSION: number = 1
const UNKNOWN_DATE: string = '—'

let nextSshKeyId: number = 1

@ObservedV2
export class SshKeyDraft {
  readonly id: number = nextSshKeyId++
  @Trace name: string = ''
  // 无法识别的格式留空，卡片只显示名称与日期。
  @Trace algorithm: string = ''
  @Trace bits: number = 0
  @Trace addedAt: number = 0
  @Trace privateKey: string = ''
  @Trace publicKey: string = ''
  // 已入库的密钥显示「已添加」，本次编辑会话新增的显示「待保存」。
  @Trace persisted: boolean = false
}

interface SshKeyPayloadItem {
  name: string
  algorithm: string
  bits: number
  addedAt: number
  privateKey: string
  publicKey: string
}

interface SshKeyPayload {
  version: number
  keys: SshKeyPayloadItem[]
}

// 字段值可能被其他客户端改成任意文本，解析失败按空列表处理，不阻断条目编辑。
export function parseSshKeys(json: string): SshKeyDraft[] {
  if (json.length === 0) {
    return []
  }
  let payload: SshKeyPayload
  try {
    payload = JSON.parse(json) as SshKeyPayload
  } catch (error) {
    LogUtil.error(`SSH 密钥字段解析失败，错误信息=${(error as Error).message}`)
    return []
  }
  if (payload === null || payload.keys === undefined) {
    return []
  }
  return payload.keys.map((item: SshKeyPayloadItem): SshKeyDraft => {
    const draft: SshKeyDraft = new SshKeyDraft()
    draft.name = item.name ?? ''
    draft.algorithm = item.algorithm ?? ''
    draft.bits = item.bits ?? 0
    draft.addedAt = item.addedAt ?? 0
    draft.privateKey = item.privateKey ?? ''
    draft.publicKey = item.publicKey ?? ''
    draft.persisted = true
    return draft
  })
}

// 空列表序列化为空串，沿用「模板字段留空即不写入 KDBX」的规则。
export function serializeSshKeys(keys: SshKeyDraft[]): string {
  if (keys.length === 0) {
    return ''
  }
  const payload: SshKeyPayload = {
    version: PAYLOAD_VERSION,
    keys: keys.map((key: SshKeyDraft): SshKeyPayloadItem => {
      return {
        name: key.name,
        algorithm: key.algorithm,
        bits: key.bits,
        addedAt: key.addedAt,
        privateKey: key.privateKey,
        publicKey: key.publicKey,
      }
    }),
  }
  return JSON.stringify(payload)
}

// 卡片摘要：算法 · 位数 · 加入日期，缺失项跳过。
export function sshKeySummary(key: SshKeyDraft): string {
  const parts: string[] = []
  if (key.algorithm.length > 0) {
    parts.push(key.bits > 0 ? `${key.algorithm} · ${key.bits} 位` : key.algorithm)
  }
  parts.push(key.addedAt > 0 ? DateUtil.getFormatDateStr(key.addedAt, 'yyyy-MM-dd') : UNKNOWN_DATE)
  return parts.join(' · ')
}
