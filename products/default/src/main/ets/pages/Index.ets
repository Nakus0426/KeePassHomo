import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { picker } from '@kit.CoreFileKit'
import {
  KdbxVerificationResult,
  FileVaultRepository,
  Logger,
  StageZeroKdbxVerifier,
  VaultSource,
  VaultSourceType,
} from '@ohos/common'
import { SYSTEM_VALIDATION_ROUTE } from '../constants/RouteConstants'

@Entry
@Component
struct Index {
  @StorageLink('privacyCovered') privacyCovered: boolean = true
  @State private selectedUri: string = ''
  @State private selectedName: string = ''
  @State private keyFileUri: string = ''
  @State private keyFileName: string = ''
  @State private password: string = ''
  @State private busy: boolean = false
  @State private status: string = ''
  @State private result: KdbxVerificationResult | undefined = undefined
  private readonly logger: Logger = new Logger()

  private async selectVault(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    options.fileSuffixFilters = ['KeePass 数据库|.kdbx']
    const documentPicker = new picker.DocumentViewPicker(context)
    try {
      const uris: string[] = await documentPicker.select(options)
      const source: VaultSource = {
        type: VaultSourceType.LocalFile,
        uri: uris[0],
        displayName: decodeURIComponent(uris[0].split('/').pop() as string),
        readOnly: false,
      }
      await new FileVaultRepository(context.filesDir).persistAccess(source)
      this.selectedUri = uris[0]
      this.selectedName = source.displayName
      this.status = $r('app.string.stage_zero_file_ready').toString()
      this.result = undefined
    } catch (error) {
      const businessError = error as BusinessError
      this.status = `文件选择或持久授权失败，错误码：${businessError.code}`
      this.logger.error(`文件选择或持久授权失败，错误码：${businessError.code}`)
    }
  }

  private async verifyVault(): Promise<void> {
    if (this.selectedUri.length === 0 || this.password.length === 0) {
      this.status = $r('app.string.stage_zero_input_required').toString()
      return
    }
    this.busy = true
    this.result = undefined
    this.status = $r('app.string.stage_zero_running').toString()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const verifier = new StageZeroKdbxVerifier(context.filesDir)
    const source: VaultSource = {
      type: VaultSourceType.LocalFile,
      uri: this.selectedUri,
      displayName: this.selectedName,
      readOnly: false,
    }
    const keyFileSource: VaultSource | undefined = this.keyFileUri.length === 0 ? undefined : {
      type: VaultSourceType.LocalFile,
      uri: this.keyFileUri,
      displayName: this.keyFileName,
      readOnly: true,
    }
    try {
      this.result = await verifier.verify(source, this.password, keyFileSource)
      this.status = $r('app.string.stage_zero_success').toString()
      this.logger.info('KDBX 阶段 0 往返验证成功')
    } catch (error) {
      this.status = (error as Error).message
      this.logger.error('KDBX 阶段 0 往返验证失败')
    } finally {
      this.password = ''
      this.busy = false
    }
  }

  private async selectKeyFile(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.selectMode = picker.DocumentSelectMode.FILE
    const documentPicker = new picker.DocumentViewPicker(context)
    try {
      const uris: string[] = await documentPicker.select(options)
      const source: VaultSource = {
        type: VaultSourceType.LocalFile,
        uri: uris[0],
        displayName: decodeURIComponent(uris[0].split('/').pop() as string),
        readOnly: true,
      }
      await new FileVaultRepository(context.filesDir).persistAccess(source)
      this.keyFileUri = uris[0]
      this.keyFileName = source.displayName
    } catch (error) {
      const businessError = error as BusinessError
      this.status = `密钥文件选择或持久授权失败，错误码：${businessError.code}`
      this.logger.error(`密钥文件选择或持久授权失败，错误码：${businessError.code}`)
    }
  }

  @Builder
  private verificationResult() {
    if (this.result !== undefined) {
      Column({ space: 8 }) {
        Text(`${this.result.vaultName} · ${this.result.format}`)
          .fontSize($r('app.float.text_body'))
          .fontWeight(FontWeight.Medium)
        Text(`分组 ${this.result.groupCount} · 条目 ${this.result.entryCount}`)
        Text(
          `受保护字段 ${this.result.protectedFieldCount} · 附件 ${this.result.attachmentCount} · 历史 ${this.result.historyCount}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding($r('app.float.space_16'))
      .backgroundColor($r('app.color.surface_secondary'))
      .borderRadius($r('app.float.radius_8'))
    }
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 8 }) {
            Text($r('app.string.app_title'))
              .fontSize($r('app.float.text_title'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.stage_zero_title'))
              .fontSize($r('app.float.text_heading'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Button($r('app.string.select_kdbx'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.selectVault())

          if (this.selectedName.length > 0) {
            Text(this.selectedName)
              .width('100%')
              .fontSize($r('app.float.text_body'))
              .fontColor($r('app.color.text_secondary'))
          }

          TextInput({ placeholder: $r('app.string.master_password'), text: this.password })
            .type(InputType.Password)
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .onChange((value: string) => this.password = value)

          Button(this.keyFileName.length === 0 ? $r('app.string.select_key_file') : this.keyFileName)
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => this.selectKeyFile())

          Button(this.busy ? $r('app.string.verifying') : $r('app.string.run_verification'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.busy)
            .backgroundColor($r('app.color.action_primary'))
            .onClick(() => this.verifyVault())

          if (this.status.length > 0) {
            Text(this.status)
              .width('100%')
              .fontSize($r('app.float.text_body'))
              .fontColor($r('app.color.text_secondary'))
          }
          this.verificationResult()

          Button($r('app.string.open_system_validation'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: SYSTEM_VALIDATION_ROUTE })
            })
        }
        .width('100%')
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
