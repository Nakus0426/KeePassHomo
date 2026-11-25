// 菜单退场或弹窗关闭后再执行的动作：只保留最后一次登记，执行即清空。
export class DeferredAction {
  private action: (() => void) | undefined = undefined

  defer(action: () => void): void {
    this.action = action
  }

  run(): void {
    const action: (() => void) | undefined = this.action
    this.action = undefined
    if (action !== undefined) {
      action()
    }
  }
}
