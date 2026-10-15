import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { ItemTemplate } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { ItemTemplateDefinition, TEMPLATE_DEFINITIONS } from '../../model/EntryTemplateCatalog'

// 窄屏一行 2 个，宽屏一行最多 3 个；按组件宽度切档，宽度由列数均分。
const TEMPLATE_CARD_COLUMNS: GridRowColumnOption = {
  xs: 2,
  sm: 2,
  md: 3,
  lg: 3,
  xl: 3,
  xxl: 3,
}
const TEMPLATE_CARD_BREAKPOINTS: string[] = ['320vp', '600vp', '840vp']

// 模板选择是独立半模态：按 4.2 的选择/跳转场景例外，允许在其上再开编辑半模态。
@ComponentV2
export struct EntryTemplatePicker {
  @Param bottomOffset: number = 0
  @Event onPicked: (template: ItemTemplate) => void = () => {
  }
  @Event onClose: () => void = () => {
  }
  private readonly app: AppViewModel = appViewModel
  private readonly closeIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontColor([$r('sys.color.titlebar_icon_color')])

  aboutToAppear(): void {
    this.app.loadRecentTemplates()
  }

  // 单行标题栏实际高度才是内容避让量；titlebar_default_height 含单双行与材质余量，直接用会空出一大截。
  // 与主壳页面一致：正文从标题栏底部再让 padding_level8。
  @Computed
  private get titleBarOffset(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.single_line_titlebar_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level16').id)
    return this.getUIContext().px2vp(titlebarHeightPx + gapPx)
  }

  private menuItems(): HdsNavigationMenuItemOptions[] {
    const close: HdsNavigationIconOptions = {
      icon: this.closeIcon,
      type: IconStyleMode.SMALL,
      label: $r('app.string.close'),
      action: () => this.onClose(),
    }
    return [{ content: close }]
  }

  // 最近使用只加徽标，卡片顺序固定为定义表顺序。
  @Builder
  private templateCard(definition: ItemTemplateDefinition) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: $r('sys.float.padding_level4') }) {
          Image(definition.icon)
            .draggable(false)
            .width($r('app.float.template_icon_size'))
            .height($r('app.float.template_icon_size'))
            .objectFit(ImageFit.Contain)

          Text(definition.name)
            .width('100%')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(definition.description)
            .width('100%')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.app.recentTemplates.includes(definition.template)) {
          Text($r('app.string.recent_used_template'))
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.brand'))
            .padding({
              left: $r('sys.float.padding_level8'),
              right: $r('sys.float.padding_level8'),
              top: $r('sys.float.padding_level2'),
              bottom: $r('sys.float.padding_level2'),
            })
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .borderRadius($r('sys.float.corner_radius_level16'))
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height($r('app.float.template_card_height'))
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .onClick(() => this.onPicked(definition.template))
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          GridRow({
            columns: TEMPLATE_CARD_COLUMNS,
            gutter: { x: $r('sys.float.padding_level8'), y: $r('sys.float.padding_level8') },
            breakpoints: {
              value: TEMPLATE_CARD_BREAKPOINTS,
              reference: BreakpointsReference.ComponentSize,
            },
          }) {
            ForEach(TEMPLATE_DEFINITIONS, (definition: ItemTemplateDefinition) => {
              GridCol({ span: 1 }) {
                this.templateCard(definition)
              }
            }, (definition: ItemTemplateDefinition) => definition.template)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({
          top: this.titleBarOffset,
          bottom: this.bottomOffset,
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
        })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
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
          mainTitle: $r('app.string.new_entry'),
        },
        menu: {
          value: this.menuItems(),
        },
      },
    })
  }
}
