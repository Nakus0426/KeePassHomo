import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'
import { generatorContentController } from './GeneratorComponents'

/** 生成器页签的标题栏供给：菜单提供复制当前密码入口。 */
export const generatorTabChrome: ModuleTabChrome = {
  menuItems: (): HdsNavigationMenuItemOptions[] => [{
    content: {
      icon: $r('sys.symbol.doc_text_on_doc_text'),
      label: $r('app.string.copy'),
      action: (): void => generatorContentController.copyPassword(),
    },
  }],
}
