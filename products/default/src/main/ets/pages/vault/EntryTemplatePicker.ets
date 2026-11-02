import { ItemTemplate } from '@ohos/common'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { ItemTemplateDefinition, TEMPLATE_DEFINITIONS } from '../../model/EntryTemplateCatalog'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsPageHeaderAction } from '../../components/DsPageHeader'

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

  aboutToAppear(): void {
    this.app.loadRecentTemplates()
  }

  private templateActions(): DsPageHeaderAction[] {
    return [{ icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.onClose() }]
  }

  // 最近使用只加徽标，卡片顺序固定为定义表顺序。
  @Builder
  private templateCard(definition: ItemTemplateDefinition) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: $r('app.float.ds_space_xs') }) {
          Image(definition.icon)
            .draggable(false)
            .width($r('app.float.template_icon_size'))
            .height($r('app.float.template_icon_size'))
            .objectFit(ImageFit.Contain)

          Text(definition.name)
            .width('100%')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(definition.description)
            .width('100%')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.app.recentTemplates.includes(definition.template)) {
          Text($r('app.string.recent_used_template'))
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('app.color.ds_primary'))
            .padding({
              left: $r('app.float.ds_space_sm'),
              right: $r('app.float.ds_space_sm'),
              top: $r('app.float.ds_space_2'),
              bottom: $r('app.float.ds_space_2'),
            })
            .backgroundColor($r('app.color.ds_surface_high'))
            .borderRadius($r('sys.float.corner_radius_level16'))
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height($r('app.float.template_card_height'))
    .padding($r('app.float.ds_space_sm'))
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
    .onClick(() => this.onPicked(definition.template))
  }

  @LocalBuilder
  private bodyContent() {
    Scroll() {
      Column() {
        GridRow({
          columns: TEMPLATE_CARD_COLUMNS,
          gutter: { x: $r('app.float.ds_space_sm'), y: $r('app.float.ds_space_sm') },
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
        top: $r('app.float.ds_space_lg'),
        bottom: this.bottomOffset,
        left: $r('app.float.ds_space_sm'),
        right: $r('app.float.ds_space_sm'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    .clip(false)
  }

  build() {
    DsHalfModalSheet({
      title: $r('app.string.new_entry'),
      actions: this.templateActions(),
      bodyBuilder: this.bodyContent,
    })
  }
}
