import { VaultGroup } from '@ohos/common'

// 横移自身宽度的 20%，与生成器页签切换动画同参。
export const LEVEL_TRANSITION_OFFSET_RATIO: number = 0.2

// 从 group 向上回溯到目标组的链路（含首尾）；目标不在子树内返回 undefined。
export function findGroupChain(group: VaultGroup, targetUuid: string): VaultGroup[] | undefined {
  if (group.uuid === targetUuid) {
    return [group]
  }
  for (const child of group.groups) {
    const chain: VaultGroup[] | undefined = findGroupChain(child, targetUuid)
    if (chain !== undefined) {
      chain.unshift(group)
      return chain
    }
  }
  return undefined
}

export function sameOrder(previous: string[], next: string[]): boolean {
  return previous.length === next.length
    && previous.every((uuid: string, index: number) => uuid === next[index])
}
