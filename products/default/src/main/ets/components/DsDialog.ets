import { promptAction } from '@kit.ArkUI'
import { DsButton, DsButtonTone, DsButtonVariant } from './DsButton'
import { DsControlSize } from './DsControlSize'

// 全项目弹窗统一承载参数：透明壳 + 设计系统遮罩，卡片本身由 DsDialog 绘制。
export function dsDialogOptions(): promptAction.CustomDialogOptions {
  return {
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: 0,
    width: $r('app.float.dialog_width'),
    alignment: DialogAlignment.Center,
    maskColor: $r('app.color.ds_scrim'),
  }
}

export enum DsDialogTone {
  Default,
  Warning,
  Error,
}

// 通用阻断弹窗内容：宿主用 presentCustomDialog 承载，本组件只画实色卡片。
@ComponentV2
export struct DsDialog {
  @Require @Param title: ResourceStr
  @Param message: ResourceStr = ''
  @Param icon: Resource | undefined = undefined
  @Param tone: DsDialogTone = DsDialogTone.Default
  // 缺省为单按钮弹窗。
  @Param cancelLabel: ResourceStr | undefined = undefined
  @Param confirmLabel: ResourceStr = ''
  @Param busy: boolean = false
  @BuilderParam contentBuilder?: () => void
  @Event onCancel: () => void = () => {
  }
  @Event onConfirm: () => void = () => {
  }

  @Computed
  get iconColor(): ResourceColor {
    if (this.tone === DsDialogTone.Warning) {
      return $r('app.color.ds_warning')
    }
    if (this.tone === DsDialogTone.Error) {
      return $r('app.color.ds_error')
    }
    return $r('app.color.ds_text_secondary')
  }

  @Computed
  get confirmTone(): DsButtonTone {
    if (this.tone === DsDialogTone.Warning) {
      return DsButtonTone.Warning
    }
    if (this.tone === DsDialogTone.Error) {
      return DsButtonTone.Error
    }
    return DsButtonTone.Primary
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Column({ space: $r('app.float.ds_space_sm') }) {
            Row({ space: $r('app.float.ds_space_sm') }) {
              if (this.icon !== undefined) {
                SymbolGlyph(this.icon)
                  .fontSize($r('app.float.ds_icon_md'))
                  .fontColor([this.iconColor])
                  .foregroundColor(this.iconColor)
              }

              Text(this.title)
                .fontSize($r('app.float.ds_font_title_md'))
                .fontWeight(600)
                .fontColor($r('app.color.ds_text_primary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            if (this.message !== '') {
              Text(this.message)
                .width('100%')
                .fontSize($r('app.float.ds_font_body'))
                .lineHeight($r('app.float.ds_line_height_body_sm'))
                .fontColor($r('app.color.ds_text_secondary'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          // 标题区、内容槽、底栏共用 16 内边距，三段左缘对齐。
          .padding($r('app.float.ds_gutter'))

          if (this.contentBuilder !== undefined) {
            Column() {
              this.contentBuilder()
            }
            .width('100%')
            .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
          }
        }
        .width('100%')
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .align(Alignment.Top)

      Row({ space: $r('app.float.ds_space_sm') }) {
        if (this.cancelLabel !== undefined) {
          Column() {
            DsButton({
              label: this.cancelLabel ?? '',
              variant: DsButtonVariant.Filled,
              tone: DsButtonTone.Default,
              buttonSize: DsControlSize.Medium,
              fullWidth: true,
              disabled: this.busy,
              onTap: () => this.onCancel(),
            })
          }
          .layoutWeight(1)
        }

        Column() {
          DsButton({
            label: this.confirmLabel,
            variant: DsButtonVariant.Filled,
            tone: this.confirmTone,
            buttonSize: DsControlSize.Medium,
            fullWidth: true,
            disabled: this.busy,
            onTap: () => this.onConfirm(),
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding($r('app.float.ds_gutter'))
    }
    .width($r('app.float.dialog_width'))
    .constraintSize({ maxHeight: '80%' })
    .backgroundColor($r('app.color.ds_surface_lowest'))
    .borderRadius($r('app.float.ds_radius_none'))
  }
}
