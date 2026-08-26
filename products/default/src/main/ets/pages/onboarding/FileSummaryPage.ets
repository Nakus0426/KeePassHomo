import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ROUTE_FILE_SUMMARY } from '../../constants/RouteConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'
import { uiMaterial } from '@kit.ArkUI'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { Cell } from '../../components/Cell'
import { Tag, TagType } from '../../components/Tag'
import { ColorUtil } from '@ohos/common'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'

const READ_ONLY_BANNER_OPACITY: number = 0.2

@ComponentV2
export struct FileSummaryPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private colorMode: ColorModeState = colorModeState

  @Computed
  get bottomAvoidAreaHeight() {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get topAvoidAreaHeight() {
    let res: number = 0
    try {
      const titlebarDefaultHeightPx =
        ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
      const paddingTopPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
      res =
        this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarDefaultHeightPx + paddingTopPx)
    } catch (error) {
      LogUtil.error(error.message)
    }

    return res
  }

  @Computed
  get fileSummaryReadOnly(): boolean {
    return this.viewModel.fileSummary?.readOnly ?? false
  }

  @Computed
  get readOnlyBannerBackground(): number {
    this.colorMode.isDark
    return ColorUtil.withAlpha($r('sys.color.alert'), READ_ONLY_BANNER_OPACITY)
  }

  @Builder
  fileStatusBuilder() {
    Tag({ type: this.fileSummaryReadOnly ? TagType.Alert : TagType.Confirm }) {
      Text(this.fileSummaryReadOnly ? $r('app.string.read_only') : $r('app.string.writable'))
        .fontSize($r('sys.float.Body_M'))
    }
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Scroll() {

          Column({ space: $r('sys.float.padding_level6') }) {
            if (this.viewModel.fileSummary !== undefined) {
              Column({ space: $r('sys.float.padding_level8') }) {
                Row({ space: $r('sys.float.padding_level8') }) {
                  Stack() {
                    SymbolGlyph($r('sys.symbol.folder_fill'))
                      .fontSize($r('sys.float.Display_S'))
                      .fontColor([$r('sys.color.brand')])
                  }
                  .padding($r('sys.float.padding_level8'))
                  .borderRadius($r('sys.float.corner_radius_level8'))
                  .backgroundColor($r('sys.color.comp_background_tertiary'))

                  Text(this.viewModel.fileSummary.name)
                    .layoutWeight(1)
                    .fontSize($r('sys.float.Title_S'))
                    .fontColor($r('sys.color.font_primary'))
                    .fontWeight(FontWeight.Medium)
                    .textOverflow({ overflow: TextOverflow.MARQUEE })
                    .marqueeOptions({ start: true, fadeout: true })
                }
                .alignItems(VerticalAlign.Center)

                List() {
                  Cell({
                    label: $r('app.string.file_format'),
                    value: this.viewModel.formatName(this.viewModel.fileSummary.format),
                    clickable: false,
                  })
                  Cell({
                    label: $r('app.string.file_size'),
                    value: this.viewModel.formatSize(this.viewModel.fileSummary.size),
                    clickable: false,
                  })
                  Cell({
                    label: $r('app.string.last_modified'),
                    value: this.viewModel.formatTime(this.viewModel.fileSummary.modifiedAt * 1000),
                    clickable: false,
                  })
                  Cell({
                    label: $r('app.string.file_status'),
                    valueBuilder: this.fileStatusBuilder,
                    onCellClick: () => LogUtil.debug(JSON.stringify(this.viewModel.fileSummary)),
                  })
                }
                .width('100%')
                .height('auto')
                .padding({ left: 0, right: 0 })
                .backgroundColor(Color.Transparent)
                .divider({
                  strokeWidth: 1,
                  color: $r('sys.color.grid_menu_divider_color'),
                })
                .scrollBar(BarState.Off)
              }
              .backgroundColor($r('sys.color.comp_background_primary'))
              .padding({
                top: $r('sys.float.padding_level8'),
                right: $r('sys.float.padding_level8'),
                bottom: 0,
                left: $r('sys.float.padding_level8'),
              })
              .borderRadius($r('sys.float.corner_radius_level10'))
              .alignItems(HorizontalAlign.Start)

            }

            if (this.fileSummaryReadOnly) {
              Row({ space: $r('sys.float.padding_level4') }) {
                SymbolGlyph($r('sys.symbol.info_circle_fill'))
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontColor([$r('sys.color.alert')])

                Text($r('app.string.read_only_explanation'))
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.alert'))
                  .layoutWeight(1)
              }
              .padding($r('sys.float.padding_level8'))
              .borderRadius($r('sys.float.corner_radius_level10'))
              .backgroundColor(this.readOnlyBannerBackground)
              .alignItems(VerticalAlign.Top)
            }

          }

        }
        .height('100%')
        .width('100%')
        .align(Alignment.TopStart)
        .padding({
          top: this.topAvoidAreaHeight,
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
        })
        .edgeEffect(EdgeEffect.Spring)

        Row({ space: $r('sys.float.padding_level6') }) {
          Button($r('app.string.reselect_file'), { stateEffect: true })
            .layoutWeight(1)
            .systemMaterial(new uiMaterial.ImmersiveMaterial({
              style: uiMaterial.ImmersiveStyle.REGULAR,
              lightEffect: { color: undefined },
              colorInvert: true,
              interactive: true,
            }))
            .fontColor($r('sys.color.font_secondary'))
            .onClick(() => this.viewModel.chooseLocalVault())
          Button($r('app.string.continue_action'), { stateEffect: true })
            .layoutWeight(1)
            .systemMaterial(new uiMaterial.ImmersiveMaterial({
              style: uiMaterial.ImmersiveStyle.REGULAR,
              lightEffect: { color: $r('sys.color.brand') },
              colorInvert: true,
              interactive: true,
            }))
            .backgroundColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.openUnlock())
        }
        .width('100%')
        .position({ bottom: this.bottomAvoidAreaHeight })
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
        })
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.file_summary'),
        },
      },
    })
    .hideBackButton(false)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_FILE_SUMMARY))
  }
}
