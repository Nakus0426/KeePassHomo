import { AnimationTokens, ItemTemplate } from '@ohos/common'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import {
  definitionFor,
  ItemTemplateDefinition,
  TEMPLATE_DEFINITIONS,
} from '../../model/EntryTemplateCatalog'
import { DsButton, DsButtonVariant } from '../../components/DsButton'
import { DsTag, DsTagSize, DsTagTone } from '../../components/DsTag'
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

// 模板卡：图标独占首行，标题 / 说明 / 字段摘要在图标下方占满卡片宽度。
@ComponentV2
struct TemplateCard {
  @Require @Param definition: ItemTemplateDefinition
  @Param recent: boolean = false
  @Event onPick: (template: ItemTemplate) => void = () => {
  }

  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  private cardColor(): ResourceColor {
    if (this.pressed) {
      return $r('app.color.ds_surface_highest')
    }
    return this.hovered ? $r('app.color.ds_surface_high') : $r('app.color.ds_surface_low')
  }

  build() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        Image(this.definition.icon)
          .draggable(false)
          .width($r('app.float.ds_template_icon_size'))
          .height($r('app.float.ds_template_icon_size'))
          .objectFit(ImageFit.Contain)

        Blank()

        if (this.recent) {
          DsTag({
            tone: DsTagTone.Default,
            tagSize: DsTagSize.Medium,
            text: $r('app.string.template_recent_badge'),
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(this.definition.name)
        .width('100%')
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.definition.description)
        .width('100%')
        .fontSize($r('app.float.ds_font_body_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.definition.summary)
        .width('100%')
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.cardColor())
    .borderRadius($r('app.float.ds_radius_none'))
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => this.onPick(this.definition.template))
  }
}

// 模板选择是独立半模态：按 4.2 的选择/跳转场景例外，允许在其上再开编辑半模态。
@ComponentV2
export struct EntryTemplatePicker {
  @Param bottomOffset: number = 0
  @Event onPicked: (template: ItemTemplate) => void = () => {
  }
  // 空白条目由宿主决定对应的模板与是否计入最近使用，选择器只发意图。
  @Event onStartBlank: () => void = () => {
  }
  @Event onClose: () => void = () => {
  }
  private readonly app: AppViewModel = appViewModel
  // 绑定给标题栏渐变模糊：未绑定滚动容器时材质会常驻，内容还没上移就出现模糊带。
  private readonly scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.app.loadRecentTemplates()
  }

  private templateActions(): DsPageHeaderAction[] {
    return [{ icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.onClose() }]
  }

  // 最近使用排在最前（按使用时间倒序），其余保持定义表顺序。
  @Computed
  private get orderedDefinitions(): ItemTemplateDefinition[] {
    const recents: ItemTemplate[] = this.app.recentTemplates
    return recents.map((template: ItemTemplate) => definitionFor(template))
      .concat(TEMPLATE_DEFINITIONS.filter((definition: ItemTemplateDefinition) =>
      !recents.includes(definition.template)))
  }

  private isRecent(template: ItemTemplate): boolean {
    return this.app.recentTemplates.includes(template)
  }

  @LocalBuilder
  private bodyContent() {
    Scroll(this.scroller) {
      Column({ space: $r('app.float.ds_space_lg') }) {
        GridRow({
          columns: TEMPLATE_CARD_COLUMNS,
          gutter: { x: $r('app.float.ds_space_sm'), y: $r('app.float.ds_space_sm') },
          breakpoints: {
            value: TEMPLATE_CARD_BREAKPOINTS,
            reference: BreakpointsReference.ComponentSize,
          },
        }) {
          ForEach(this.orderedDefinitions, (definition: ItemTemplateDefinition) => {
            GridCol({ span: 1 }) {
              TemplateCard({
                definition: definition,
                recent: this.isRecent(definition.template),
                onPick: this.onPicked,
              })
            }
          }, (definition: ItemTemplateDefinition) =>
          `${definition.template}-${this.isRecent(definition.template) ? 'r' : ''}`)
        }
        .width('100%')

        DsButton({
          label: $r('app.string.start_blank_entry'),
          variant: DsButtonVariant.Text,
          fullWidth: true,
          onTap: () => this.onStartBlank(),
        })
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('app.float.ds_space_16'),
        bottom: this.bottomOffset > 0 ? this.bottomOffset : $r('app.float.ds_space_16'),
        left: $r('app.float.ds_space_16'),
        right: $r('app.float.ds_space_16'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    // alwaysEnabled：内容不足一屏时也由滚动容器接管竖向手势，避免上下滑动拖动整个半模态。
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .align(Alignment.Top)
    .clip(false)
  }

  build() {
    DsHalfModalSheet({
      title: $r('app.string.new_entry'),
      actions: this.templateActions(),
      scrollableScroller: this.scroller,
      bodyBuilder: this.bodyContent,
    })
  }
}
