/**
 * 路由入参定义：仅承载非敏感定位信息，
 * 敏感数据不走路由参数（见开发计划 3.4 节约束）。
 */
export interface WelcomeParam {
  showBack: boolean
}
