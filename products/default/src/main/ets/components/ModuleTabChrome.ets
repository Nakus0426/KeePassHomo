// 各一级页在自己的 *TabChrome.ets 中实现，由页签根页的 HdsNavigation 直接渲染。
export interface ModuleTabChrome {
  // 提供时整行由其自绘（mainTitle/subTitle 不生效）
  // 须为 wrapBuilder 封装后的全局 @Builder
  titleRowBuilder?: WrappedBuilder<[]>
  // 批量选择态的自绘标题行；提供后由首页在 batchMode 时替换 titleRowBuilder
  selectionRowBuilder?: WrappedBuilder<[]>
  // 提供时在标题栏下方渲染一行，区域高度由 HDS 决定
  // 与 titleRowBuilder 同约束：须为 wrapBuilder 封装后的全局 @Builder
  bottomRowBuilder?: WrappedBuilder<[]>
}
