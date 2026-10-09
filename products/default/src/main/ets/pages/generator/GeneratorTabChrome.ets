import { HdsNavigationMenuItemOptions, IconStyleMode } from '@kit.UIDesignKit'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'
import { generatorContentController } from './GeneratorComponents'

export const generatorTabChrome: ModuleTabChrome = {
  menuItems: (): HdsNavigationMenuItemOptions[] => [{
    content: {
      icon: $r('sys.symbol.doc_text_on_doc_text'),
      type: IconStyleMode.SMALL,
      label: $r('app.string.copy'),
      action: (): void => generatorContentController.copyPassword(),
    },
  }],
}
