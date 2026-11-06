import { StrengthLevel } from '@ohos/common'

export const ENTRY_FIELD_USERNAME: string = 'UserName'
export const ENTRY_FIELD_NOTES: string = 'Notes'
export const ENTRY_FIELD_PASSWORD: string = 'Password'
export const ENTRY_FIELD_CARD_TYPE: string = 'CardType'
export const ENTRY_FIELD_CARD_NUMBER: string = 'CardNumber'

export function strengthLabel(level: StrengthLevel): ResourceStr {
  switch (level) {
    case StrengthLevel.VeryWeak:
      return $r('app.string.password_strength_very_weak')
    case StrengthLevel.Weak:
      return $r('app.string.password_strength_weak')
    case StrengthLevel.Medium:
      return $r('app.string.password_strength_medium')
    case StrengthLevel.Strong:
      return $r('app.string.password_strength_strong')
    case StrengthLevel.VeryStrong:
      return $r('app.string.password_strength_very_strong')
    default:
      return ''
  }
}
