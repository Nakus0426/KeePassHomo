import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit'

// 各模块在自己的 *TabChrome.ets 中实现，由 AppShell 聚合渲染
export interface ModuleTabChrome {
  // 提供时整行由其自绘（mainTitle/subTitle 不生效）
  // 须为 wrapBuilder 封装后的全局 @Builder
  titleRowBuilder?: WrappedBuilder<[]>
  // 未提供则不显示；实现内部读响应式状态才能实时刷新
  subtitle?: () => ResourceStr | undefined
  // 提供时在标题栏下方渲染一行，区域高度由 HDS 决定
  // 与 titleRowBuilder 同约束：须为 wrapBuilder 封装后的全局 @Builder
  bottomRowBuilder?: WrappedBuilder<[]>
  // 追加在全局锁定项之后
  menuItems?: () => HdsNavigationMenuItemOptions[]
}
