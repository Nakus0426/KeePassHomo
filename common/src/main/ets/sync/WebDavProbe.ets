import { url } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { rcp } from '@kit.RemoteCommunicationKit'
import { StrUtil } from '@pura/harmony-utils'

export enum WebDavProbeErrorCategory {
  InvalidInput = 'invalid_input',
  Authentication = 'authentication',
  NotFound = 'not_found',
  Unsupported = 'unsupported',
  Tls = 'tls',
  Network = 'network',
  Server = 'server',
  MissingVersion = 'missing_version',
  Other = 'other'
}

export class WebDavProbeError extends Error {
  readonly category: WebDavProbeErrorCategory

  constructor(category: WebDavProbeErrorCategory, message: string) {
    super(message)
    this.name = 'WebDavProbeError'
    this.category = category
  }
}

export interface WebDavProbeResult {
  statusCode: number;
  versionSource: 'ETag' | 'Last-Modified';
  version: string;
}

const PROPFIND_BODY: string = '<?xml version="1.0" encoding="utf-8"?>' +
  '<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/><d:getlastmodified/></d:prop></d:propfind>'
const TLS_ERROR_CODES: number[] = [1007900035, 1007900058, 1007900059, 1007900060, 1007900077, 1007900090]
const NETWORK_ERROR_CODES: number[] = [1007900005, 1007900006, 1007900007, 1007900028, 1007900052, 1007900055,
  1007900056]

export class WebDavProbe {
  async verify(urlText: string, username: string, password: string): Promise<WebDavProbeResult> {
    let targetUrl: url.URL
    try {
      targetUrl = url.URL.parseURL(urlText)
    } catch (error) {
      throw new WebDavProbeError(WebDavProbeErrorCategory.InvalidInput, 'WebDAV 地址无效')
    }
    if (targetUrl.protocol !== 'https:') {
      throw new WebDavProbeError(WebDavProbeErrorCategory.InvalidInput, 'WebDAV 地址必须使用 HTTPS')
    }
    const headers: rcp.RequestHeaders = {
      'content-type': 'application/xml',
      'depth': '0',
    }
    if (username.length > 0) {
      headers.authorization = `Basic ${StrUtil.strToBase64(`${username}:${password}`)}`
    }

    try {
      const session = rcp.createSession()
      try {
        const propfind = new rcp.Request(urlText, 'PROPFIND', headers, PROPFIND_BODY)
        const propfindResponse = await session.fetch(propfind)
        this.assertStatus(propfindResponse.statusCode, 207)

        const headHeaders: rcp.RequestHeaders = {}
        if (headers.authorization !== undefined) {
          headHeaders.authorization = headers.authorization
        }
        const headResponse = await session.fetch(new rcp.Request(urlText, 'HEAD', headHeaders))
        this.assertStatus(headResponse.statusCode, 200)
        const etag = this.firstHeader(headResponse.headers.etag)
        if (etag.length > 0) {
          return { statusCode: propfindResponse.statusCode, versionSource: 'ETag', version: etag }
        }
        const lastModified = this.firstHeader(headResponse.headers['last-modified'])
        if (lastModified.length > 0) {
          return { statusCode: propfindResponse.statusCode, versionSource: 'Last-Modified', version: lastModified }
        }
        throw new WebDavProbeError(WebDavProbeErrorCategory.MissingVersion,
          'WebDAV 资源未提供 ETag 或 Last-Modified 版本标识')
      } finally {
        session.close()
      }
    } catch (error) {
      if (error instanceof WebDavProbeError) {
        throw error
      }
      throw this.classifyTransportError(error as BusinessError)
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

  private firstHeader(value: string | string[] | undefined): string {
    if (value === undefined) {
      return ''
    }
    return typeof value === 'string' ? value : value[0]
  }
}
