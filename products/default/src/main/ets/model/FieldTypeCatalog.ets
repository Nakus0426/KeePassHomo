import { VaultFieldType } from '@ohos/common'

export interface FieldTypeDefinition {
  type: VaultFieldType;
  label: Resource;
  description: Resource;
  defaultName: string;
  icon: Resource;
  wordBreak: WordBreak;
}

export const FIELD_TYPE_DEFINITIONS: FieldTypeDefinition[] = [
  {
    type: VaultFieldType.Text,
    label: $r('app.string.field_type_text'),
    description: $r('app.string.field_type_text_desc'),
    defaultName: '文本',
    icon: $r('app.media.field_type_text'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Url,
    label: $r('app.string.website'),
    description: $r('app.string.field_type_url_desc'),
    defaultName: '网址',
    icon: $r('app.media.field_type_url'),
    wordBreak: WordBreak.BREAK_ALL,
  },
  {
    type: VaultFieldType.Email,
    label: $r('app.string.field_type_email'),
    description: $r('app.string.field_type_email_desc'),
    defaultName: '邮箱',
    icon: $r('app.media.field_type_email'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Phone,
    label: $r('app.string.field_type_phone'),
    description: $r('app.string.field_type_phone_desc'),
    defaultName: '电话',
    icon: $r('app.media.field_type_phone'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Address,
    label: $r('app.string.field_type_address'),
    description: $r('app.string.field_type_address_desc'),
    defaultName: '地址',
    icon: $r('app.media.field_type_address'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Date,
    label: $r('app.string.field_type_date'),
    description: $r('app.string.field_type_date_desc'),
    defaultName: '日期',
    icon: $r('app.media.field_type_date'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Password,
    label: $r('app.string.password'),
    description: $r('app.string.field_type_password_desc'),
    defaultName: '密码',
    icon: $r('app.media.field_type_password'),
    wordBreak: WordBreak.BREAK_ALL,
  },
  {
    type: VaultFieldType.Custom,
    label: $r('app.string.field_type_custom'),
    description: $r('app.string.field_type_custom_desc'),
    defaultName: '',
    icon: $r('app.media.field_type_custom'),
    wordBreak: WordBreak.BREAK_ALL,
  },
]

// 类型只可能来自 FIELD_TYPE_DEFINITIONS，查不到即枚举与类型表不同步。
export function fieldTypeDefinition(type: VaultFieldType): FieldTypeDefinition {
  return FIELD_TYPE_DEFINITIONS.find((definition: FieldTypeDefinition) => definition.type === type)!
}
