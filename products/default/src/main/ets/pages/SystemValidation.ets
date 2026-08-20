import { common } from '@kit.AbilityKit'
import { picker } from '@kit.CoreFileKit'
import { scanBarcode, scanCore } from '@kit.ScanKit'
import {
  FileVaultRepository,
  ClipboardWriteToken,
  KdbxVaultEngine,
  LocalUnlockMaterialStore,
  Logger,
  OtpAuthConfig,
  OtpAuthParser,
  SecureClipboard,
  StageZeroFileBoundaryVerifier,
  VaultCredential,
  VaultDocument,
  VaultFormat,
  VaultSource,
  VaultSourceType,
  WebDavProbe,
  WebDavProbeResult,
} from '@ohos/common'

const CLIPBOARD_PROBE_TEXT: string = 'KeePassHomo-clipboard-stage-zero'

@Entry
@Component
struct SystemValidation {
  @StorageLink('privacyCovered') privacyCovered: boolean = true
  @State private busy: boolean = false
  @State private status: string = ''
  @State private samplePassword: string = ''
  @State private relocationUri: string = ''
  @State private relocationName: string = ''
  @State private webDavUrl: string = ''
  @State private webDavUsername: string = ''
  @State private webDavPassword: string = ''
  private readonly logger: Logger = new Logger()

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async verifyKdbxCompatibility(): Promise<void> {
    this.busy = true
    this.status = '正在验证 KDBX 3.1/4、组合凭据和错误分类'
    try {
      await new KdbxVaultEngine().selfTest('KeePassHomo-stage-zero-self-test')
      this.status = 'KDBX 3.1/4、受保护字段、附件、历史、回收站、组合凭据和错误分类验证成功'
      this.logger.info('KDBX 兼容性自检成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('KDBX 兼容性自检失败')
    } finally {
      this.busy = false
    }
  }

  private async createVaultSample(): Promise<void> {
    if (this.samplePassword.length === 0) {
      this.status = '请输入新建样本主密码'
      return
    }
    this.busy = true
    this.status = '正在创建、写入并重新解锁 KDBX 样本'
    const credential: VaultCredential = { password: this.samplePassword }
    const engine = new KdbxVaultEngine()
    const repository = new FileVaultRepository(this.context().filesDir)
    try {
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = ['KeePassHomo-stage0.kdbx']
      options.fileSuffixChoices = ['KeePass 数据库|.kdbx']
      const uris: string[] = await new picker.DocumentViewPicker(this.context()).save(options)
      const source: VaultSource = {
        type: VaultSourceType.LocalFile,
        uri: uris[0],
        displayName: 'KeePassHomo-stage0.kdbx',
        readOnly: false,
      }
      await repository.persistAccess(source)
      if (!repository.isWritable(source)) {
        throw new Error('新建 KDBX 文件不可写')
      }
      const document: VaultDocument = await engine.create('KeePassHomo 阶段 0 新建验证', credential)
      const data: ArrayBuffer = await engine.write(document)
      await repository.writeSafely(source, data, async (candidate: ArrayBuffer): Promise<void> => {
        await engine.validate(candidate, credential)
      })
      this.status = 'KDBX 创建、写入、关闭并重新解锁验证成功'
      this.logger.info('本地 KDBX 创建验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('本地 KDBX 创建验证失败')
    } finally {
      this.samplePassword = ''
      this.busy = false
    }
  }

  private async selectRelocationSource(): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    options.fileSuffixFilters = ['KeePass 数据库|.kdbx']
    try {
      const uris: string[] = await new picker.DocumentViewPicker(this.context()).select(options)
      const source: VaultSource = {
        type: VaultSourceType.LocalFile,
        uri: uris[0],
        displayName: decodeURIComponent(uris[0].split('/').pop() as string),
        readOnly: true,
      }
      await new FileVaultRepository(this.context().filesDir).persistAccess(source)
      this.relocationUri = source.uri
      this.relocationName = source.displayName
      this.status = '重新定位源文件已选择'
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('重新定位源文件选择失败')
    }
  }

  private async relocateVault(): Promise<void> {
    if (this.relocationUri.length === 0) {
      this.status = '请先选择待重新定位的 KDBX'
      return
    }
    this.busy = true
    this.status = '正在重新定位并核对文件'
    const source: VaultSource = {
      type: VaultSourceType.LocalFile,
      uri: this.relocationUri,
      displayName: this.relocationName,
      readOnly: true,
    }
    const repository = new FileVaultRepository(this.context().filesDir)
    try {
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = [`relocated-${this.relocationName}`]
      options.fileSuffixChoices = ['KeePass 数据库|.kdbx']
      const uris: string[] = await new picker.DocumentViewPicker(this.context()).save(options)
      const destination: VaultSource = {
        type: VaultSourceType.LocalFile,
        uri: uris[0],
        displayName: `relocated-${this.relocationName}`,
        readOnly: false,
      }
      await repository.persistAccess(destination)
      const original: ArrayBuffer = await repository.read(source)
      const relocated: VaultSource = await repository.relocate(source, destination.uri)
      const copied: ArrayBuffer = await repository.read(relocated)
      if (!this.bytesEqual(original, copied) || new KdbxVaultEngine().identify(copied) === VaultFormat.Unsupported) {
        throw new Error('重新定位后的 KDBX 与源文件不一致')
      }
      this.status = 'KDBX 重新定位、持久授权和数据一致性验证成功'
      this.logger.info('本地 KDBX 重新定位验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('本地 KDBX 重新定位验证失败')
    } finally {
      this.busy = false
    }
  }

  private async verifyFileBoundaries(): Promise<void> {
    this.busy = true
    this.status = '请选择阶段 0 测试 KDBX，不会修改文件内容'
    try {
      const options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.selectMode = picker.DocumentSelectMode.FILE
      options.fileSuffixFilters = ['KeePass 数据库|.kdbx']
      const uris: string[] = await new picker.DocumentViewPicker(this.context()).select(options)
      const source: VaultSource = {
        type: VaultSourceType.LocalFile,
        uri: uris[0],
        displayName: decodeURIComponent(uris[0].split('/').pop() as string),
        readOnly: false,
      }
      const repository = new FileVaultRepository(this.context().filesDir)
      await new StageZeroFileBoundaryVerifier(repository).verify(source)
      this.status = '文件可写、持久授权、只读、空间和授权失效错误分类验证成功'
      this.logger.info('文件系统错误边界验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('文件系统错误边界验证失败')
    } finally {
      this.busy = false
    }
  }

  private async verifyLocalUnlock(): Promise<void> {
    this.busy = true
    this.status = '请完成系统用户认证'
    try {
      await new LocalUnlockMaterialStore().verifyRoute()
      this.status = '系统用户认证与 Asset Store 安全存储验证成功'
      this.logger.info('本机快速解锁材料安全存储路线验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('本机快速解锁材料安全存储路线验证失败')
    } finally {
      this.busy = false
    }
  }

  private async verifyClipboard(): Promise<void> {
    this.busy = true
    this.status = '正在验证剪贴板写入、识别和条件清除'
    try {
      const clipboard = new SecureClipboard()
      const token: ClipboardWriteToken = await clipboard.write(CLIPBOARD_PROBE_TEXT)
      if (await clipboard.clearIfOwned({ changeCount: token.changeCount + 1 })) {
        throw new Error('剪贴板条件清除边界验证失败')
      }
      if (!await clipboard.clearIfOwned(token)) {
        throw new Error('本应用剪贴板内容识别失败')
      }
      this.status = '剪贴板写入、应用标记识别和条件清除验证成功'
      this.logger.info('敏感剪贴板路线验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('敏感剪贴板路线验证失败')
    } finally {
      this.busy = false
    }
  }

  private async verifyWebDav(): Promise<void> {
    if (this.webDavUrl.length === 0) {
      this.status = '请输入 HTTPS KDBX 资源地址'
      return
    }
    this.busy = true
    this.status = '正在验证 WebDAV PROPFIND、TLS 和远端版本标识'
    try {
      const result: WebDavProbeResult = await new WebDavProbe().verify(
        this.webDavUrl, this.webDavUsername, this.webDavPassword)
      this.status = `WebDAV 验证成功：HTTP ${result.statusCode}，版本来源 ${result.versionSource}`
      this.logger.info(`WebDAV 路线验证成功，版本来源：${result.versionSource}`)
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('WebDAV 路线验证失败')
    } finally {
      this.webDavPassword = ''
      this.busy = false
    }
  }

  private async scanOtpAuth(): Promise<void> {
    this.busy = true
    this.status = '正在启动二维码扫描'
    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableMultiMode: false,
      enableAlbum: true,
    }
    try {
      const scanResult: scanBarcode.ScanResult = await scanBarcode.startScanForResult(this.context(), options)
      const config: OtpAuthConfig = new OtpAuthParser().parse(scanResult.originalValue)
      const timing = config.type === 'totp' ? `周期 ${config.period}` : `计数器 ${config.counter}`
      this.status =
        `${config.type.toUpperCase()} · ${config.issuer} · ${config.account} · ${config.algorithm} · ${config.digits} 位 · ${timing}`
      config.secret = ''
      this.logger.info('otpauth 二维码读取和解析验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('otpauth 二维码读取或解析验证失败')
    } finally {
      this.busy = false
    }
  }

  private bytesEqual(left: ArrayBuffer, right: ArrayBuffer): boolean {
    if (left.byteLength !== right.byteLength) {
      return false
    }
    const leftBytes = new Uint8Array(left)
    const rightBytes = new Uint8Array(right)
    for (let index = 0; index < leftBytes.length; index++) {
      if (leftBytes[index] !== rightBytes[index]) {
        return false
      }
    }
    return true
  }

  @Builder
  private sectionTitle(title: Resource) {
    Text(title)
      .width('100%')
      .fontSize($r('app.float.text_heading'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 16 }) {
          Text($r('app.string.system_validation_title'))
            .width('100%')
            .fontSize($r('app.float.text_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Button($r('app.string.back_to_kdbx'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => this.getUIContext().getRouter().back())

          this.sectionTitle($r('app.string.kdbx_compatibility_section'))
          Button($r('app.string.verify_kdbx_compatibility'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.action_primary'))
            .onClick(() => this.verifyKdbxCompatibility())

          this.sectionTitle($r('app.string.local_file_section'))
          TextInput({ placeholder: $r('app.string.sample_password'), text: this.samplePassword })
            .type(InputType.Password)
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .onChange((value: string) => this.samplePassword = value)
          Button($r('app.string.create_kdbx_sample'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.createVaultSample())
          Button(this.relocationName.length === 0 ? $r('app.string.select_relocation_source') : this.relocationName)
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => this.selectRelocationSource())
          Button($r('app.string.relocate_kdbx'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.action_primary'))
            .onClick(() => this.relocateVault())
          Button($r('app.string.verify_file_boundaries'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.action_primary'))
            .onClick(() => this.verifyFileBoundaries())
          this.sectionTitle($r('app.string.security_section'))
          Button($r('app.string.verify_local_unlock'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.verifyLocalUnlock())
          Button($r('app.string.verify_clipboard'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.action_primary'))
            .onClick(() => this.verifyClipboard())

          this.sectionTitle($r('app.string.webdav_section'))
          TextInput({ placeholder: $r('app.string.webdav_url'), text: this.webDavUrl })
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .onChange((value: string) => this.webDavUrl = value)
          TextInput({ placeholder: $r('app.string.webdav_username'), text: this.webDavUsername })
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .onChange((value: string) => this.webDavUsername = value)
          TextInput({ placeholder: $r('app.string.webdav_password'), text: this.webDavPassword })
            .type(InputType.Password)
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .onChange((value: string) => this.webDavPassword = value)
          Button($r('app.string.verify_webdav'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.verifyWebDav())

          this.sectionTitle($r('app.string.otp_section'))
          Button($r('app.string.scan_otpauth'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.action_primary'))
            .onClick(() => this.scanOtpAuth())

          if (this.status.length > 0) {
            Text(this.status)
              .width('100%')
              .fontSize($r('app.float.text_body'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('app.float.space_24'),
          right: $r('app.float.space_24'),
          top: $r('app.float.space_32'),
          bottom: $r('app.float.space_32'),
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      if (this.privacyCovered) {
        Column() {
          Text($r('app.string.privacy_cover'))
            .fontSize($r('app.float.text_heading'))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.ohos_id_color_background'))
      }
    }
  }
}
