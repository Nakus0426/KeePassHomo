import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit'

/**
 * 模块页签的标题栏个性化供给契约：各模块在自己的 *TabChrome.ets 中实现，
 * AppShell 仅聚合渲染；后续新增个性化能力时在此扩展字段。
 */
export interface ModuleTabChrome {
  /**
   * 标题行自定义构建器；提供时整行由其自绘（mainTitle/subTitle 不生效）。
   * 须为 wrapBuilder 封装后的全局 @Builder，由 AppShell 在组件上下文内调用。
   */
  titleRowBuilder?: WrappedBuilder<[]>
  /** 标题栏子标题；未提供则不显示。实现内部读响应式状态以实时刷新。 */
  subtitle?: () => ResourceStr | undefined
  /**
   * 标题栏底部自定义区域构建器；提供时在标题栏下方渲染一行（区域高度由 HDS 决定）。
   * 与 titleRowBuilder 同约束：须为 wrapBuilder 封装后的全局 @Builder，
   * 由 AppShell 在组件上下文内调用。实现内部读响应式状态以实时刷新。
   */
  bottomRowBuilder?: WrappedBuilder<[]>
  /** 标题栏菜单项，追加在全局锁定项之后。 */
  menuItems?: () => HdsNavigationMenuItemOptions[]
}
