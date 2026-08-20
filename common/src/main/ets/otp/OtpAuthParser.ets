import { url } from '@kit.ArkTS'

export type OtpAuthType = 'totp' | 'hotp'

export type OtpAlgorithm = 'SHA1' | 'SHA256' | 'SHA512'

export interface OtpAuthConfig {
  type: OtpAuthType;
  label: string;
  issuer: string;
  account: string;
  secret: string;
  algorithm: OtpAlgorithm;
  digits: number;
  period?: number;
  counter?: number;
}

export class OtpAuthParser {
  parse(uriText: string): OtpAuthConfig {
    const uri: url.URL = url.URL.parseURL(uriText)
    if (uri.protocol !== 'otpauth:') {
      throw new Error('二维码不是 otpauth URI')
    }
    if (uri.hostname !== 'totp' && uri.hostname !== 'hotp') {
      throw new Error('仅支持 TOTP 和 HOTP 类型')
    }
    const label = decodeURIComponent(uri.pathname.slice(1))
    const secret = (uri.params.get('secret') ?? '').toUpperCase().replace(/\s/g, '')
    if (label.length === 0 || secret.length === 0 || !this.isBase32(secret)) {
      throw new Error('otpauth URI 的标签或密钥无效')
    }
    const separator = label.indexOf(':')
    const labelIssuer = separator < 0 ? '' : label.slice(0, separator).trim()
    const account = (separator < 0 ? label : label.slice(separator + 1)).trim()
    const issuer = (uri.params.get('issuer') ?? labelIssuer).trim()
    if (account.length === 0) {
      throw new Error('otpauth URI 缺少账户名')
    }
    const algorithmText = (uri.params.get('algorithm') ?? 'SHA1').toUpperCase()
    if (algorithmText !== 'SHA1' && algorithmText !== 'SHA256' && algorithmText !== 'SHA512') {
      throw new Error('otpauth URI 的算法不受支持')
    }
    const digits = this.parseInteger(uri.params.get('digits') ?? '6', '位数')
    if (digits !== 6 && digits !== 8) {
      throw new Error('otpauth URI 的位数必须为 6 或 8')
    }
    const base: OtpAuthConfig = {
      type: uri.hostname,
      label,
      issuer,
      account,
      secret,
      algorithm: algorithmText,
      digits,
    }
    if (base.type === 'totp') {
      const period = this.parseInteger(uri.params.get('period') ?? '30', '周期')
      if (period <= 0) {
        throw new Error('otpauth URI 的周期必须大于 0')
      }
      base.period = period
      return base
    }
    const counterText = uri.params.get('counter')
    if (counterText === null) {
      throw new Error('HOTP URI 缺少计数器')
    }
    const counter = this.parseInteger(counterText, '计数器')
    if (counter < 0) {
      throw new Error('HOTP URI 的计数器不能为负数')
    }
    base.counter = counter
    return base
  }

  private parseInteger(value: string, name: string): number {
    const result = Number(value)
    if (!Number.isInteger(result)) {
      throw new Error(`otpauth URI 的${name}无效`)
    }
    return result
  }

  private isBase32(value: string): boolean {
    for (let index = 0; index < value.length; index++) {
      const character = value[index]
      if ((character < 'A' || character > 'Z') && (character < '2' || character > '7') && character !== '=') {
        return false
      }
    }
    return true
  }
}
