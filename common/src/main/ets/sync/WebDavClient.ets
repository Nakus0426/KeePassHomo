import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { rcp } from '@kit.RemoteCommunicationKit'
import { StrUtil } from '@pura/harmony-utils'
import { WebDavProbeError, WebDavProbeErrorCategory } from './WebDavProbe'

export interface WebDavEntry {
  name: string;
  url: string;
  isCollection: boolean;
  size: number;
  modifiedAt: number;
}

type WebDavMethod = 'PROPFIND' | 'GET'

const LIST_BODY: string = '<?xml version="1.0" encoding="utf-8"?>' +
  '<d:propfind xmlns:d="DAV:"><d:prop><d:displayname/><d:resourcetype/>' +
  '<d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>'
const TLS_ERROR_CODES: number[] = [1007900035, 1007900058, 1007900059, 1007900060, 1007900077, 1007900090]
const NETWORK_ERROR_CODES: number[] = [1007900005, 1007900006, 1007900007, 1007900028, 1007900052, 1007900055,
  1007900056]

export class WebDavClient {
  async probe(urlText: string, username: string, password: string): Promise<void> {
    const headers: rcp.RequestHeaders = this.authHeaders(username, password, '0')
    await this.textRequest(urlText, 'PROPFIND', headers, LIST_BODY, 207)
  }

  async list(urlText: string, username: string, password: string): Promise<WebDavEntry[]> {
    const headers: rcp.RequestHeaders = this.authHeaders(username, password, '1')
    const xml: string = await this.textRequest(urlText, 'PROPFIND', headers, LIST_BODY, 207)
    return this.parseEntries(xml, urlText)
  }

  async download(urlText: string, username: string, password: string): Promise<ArrayBuffer> {
    const headers: rcp.RequestHeaders = {}
    if (username.length > 0) {
      headers.authorization = `Basic ${StrUtil.strToBase64(`${username}:${password}`)}`
    }
    const session = rcp.createSession()
    try {
      const response = await session.fetch(new rcp.Request(urlText, 'GET', headers))
      this.assertStatus(response.statusCode, 200)
      if (response.body === undefined) {
        throw new WebDavProbeError(WebDavProbeErrorCategory.Other, 'WebDAV 下载响应为空')
      }
      return response.body
    } catch (error) {
      if (error instanceof WebDavProbeError) {
        throw error
      }
      throw this.classifyTransportError(error as BusinessError)
    } finally {
      session.close()
    }
  }

  private async textRequest(urlText: string, method: WebDavMethod, headers: rcp.RequestHeaders,
    body: string, expected: number): Promise<string> {
    const session = rcp.createSession()
    try {
      const response = await session.fetch(new rcp.Request(urlText, method, headers, body))
      this.assertStatus(response.statusCode, expected)
      if (response.body === undefined) {
        return ''
      }
      const decoder = util.TextDecoder.create('utf-8')
      return decoder.decodeToString(new Uint8Array(response.body)).trim()
    } catch (error) {
      if (error instanceof WebDavProbeError) {
        throw error
      }
      throw this.classifyTransportError(error as BusinessError)
    } finally {
      session.close()
    }
  }

  private authHeaders(username: string, password: string, depth: string): rcp.RequestHeaders {
    const headers: rcp.RequestHeaders = {
      'content-type': 'application/xml',
      'depth': depth,
    }
    if (username.length > 0) {
      headers.authorization = `Basic ${StrUtil.strToBase64(`${username}:${password}`)}`
    }
    return headers
  }

  private parseEntries(xml: string, baseUrl: string): WebDavEntry[] {
    const entries: WebDavEntry[] = []
    const blocks: RegExpMatchArray | null = xml.match(
      /<(?:[\w.-]+:)?response\b[^>]*>[\s\S]*?<\/(?:[\w.-]+:)?response>/gi)
    if (blocks === null) {
      return entries
    }
    const origin: string = this.originOf(baseUrl)
    const basePath: string = this.safeDecode(this.pathOf(baseUrl))
    for (const block of blocks) {
      const href: string = this.tag(block, 'href')
      if (href.length === 0) {
        continue
      }
      const decodedPath: string = this.safeDecode(this.pathOf(href))
      if (this.trimSlash(decodedPath) === this.trimSlash(basePath)) {
        continue
      }
      const isCollection: boolean = /<(?:[\w.-]+:)?collection\b[^>]*>/i.test(block)
      const display: string = this.tag(block, 'displayname')
      const name: string = display.length > 0 ? this.decodeXml(display) : this.lastSegment(decodedPath)
      const sizeText: string = this.tag(block, 'getcontentlength')
      const sizeValue: number = sizeText.length > 0 ? parseInt(sizeText, 10) : 0
      const modifiedText: string = this.tag(block, 'getlastmodified')
      const modifiedValue: number = modifiedText.length > 0 ? Date.parse(modifiedText) : NaN
      entries.push({
        name,
        url: href.startsWith('http') ? href : origin + href,
        isCollection,
        size: isNaN(sizeValue) ? 0 : sizeValue,
        modifiedAt: isNaN(modifiedValue) ? 0 : Math.floor(modifiedValue / 1000),
      })
    }
    entries.sort((left: WebDavEntry, right: WebDavEntry): number => {
      if (left.isCollection !== right.isCollection) {
        return left.isCollection ? -1 : 1
      }
      return left.name.localeCompare(right.name)
    })
    return entries
  }

  private tag(block: string, name: string): string {
    const pattern = new RegExp(`<(?:[\\w.-]+:)?${name}\\b[^>]*>([\\s\\S]*?)<\\/(?:[\\w.-]+:)?${name}>`, 'i')
    const matched: RegExpMatchArray | null = block.match(pattern)
    return matched === null ? '' : matched[1].trim()
  }

  private decodeXml(value: string): string {
    return value.replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&amp;/g, '&')
  }

  private originOf(value: string): string {
    const scheme: number = value.indexOf('://')
    if (scheme < 0) {
      return ''
    }
    const slash: number = value.indexOf('/', scheme + 3)
    return slash < 0 ? value : value.substring(0, slash)
  }

  private pathOf(value: string): string {
    let path: string = value
    const scheme: number = value.indexOf('://')
    if (scheme >= 0) {
      const slash: number = value.indexOf('/', scheme + 3)
      path = slash < 0 ? '/' : value.substring(slash)
    }
    const query: number = path.indexOf('?')
    if (query >= 0) {
      path = path.substring(0, query)
    }
    return path
  }

  private lastSegment(path: string): string {
    const parts: string[] = path.split('/').filter((part: string) => part.length > 0)
    return parts.length === 0 ? '' : parts[parts.length - 1]
  }

  private trimSlash(path: string): string {
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1)
    }
    return path
  }

  private safeDecode(value: string): string {
    try {
      return decodeURIComponent(value)
    } catch (error) {
      return value
    }
  }

  private assertStatus(statusCode: number, expected: number): void {
    if (statusCode === expected) {
      return
    }
    if (statusCode === 401 || statusCode === 403) {
      throw new WebDavProbeError(WebDavProbeErrorCategory.Authentication, `WebDAV 认证失败，HTTP ${statusCode}`)
    }
    if (statusCode === 404) {
      throw new WebDavProbeError(WebDavProbeErrorCategory.NotFound, 'WebDAV 资源不存在，HTTP 404')
    }
    if (statusCode === 405 || statusCode === 501) {
      throw new WebDavProbeError(WebDavProbeErrorCategory.Unsupported, `WebDAV 方法不受支持，HTTP ${statusCode}`)
    }
    if (statusCode >= 500) {
      throw new WebDavProbeError(WebDavProbeErrorCategory.Server, `WebDAV 服务端错误，HTTP ${statusCode}`)
    }
    throw new WebDavProbeError(WebDavProbeErrorCategory.Other, `WebDAV 返回非预期状态，HTTP ${statusCode}`)
  }

  private classifyTransportError(error: BusinessError): WebDavProbeError {
    if (TLS_ERROR_CODES.includes(error.code)) {
      return new WebDavProbeError(WebDavProbeErrorCategory.Tls, `WebDAV TLS 校验失败，错误码：${error.code}`)
    }
    if (NETWORK_ERROR_CODES.includes(error.code)) {
      return new WebDavProbeError(WebDavProbeErrorCategory.Network, `WebDAV 网络连接失败，错误码：${error.code}`)
    }
    return new WebDavProbeError(WebDavProbeErrorCategory.Other, `WebDAV 请求失败，错误码：${error.code}`)
  }
}
