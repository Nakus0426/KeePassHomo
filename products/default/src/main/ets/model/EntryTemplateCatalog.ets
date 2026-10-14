import { ItemTemplate, VaultFieldType } from '@ohos/common'
import { SSH_KEYS_FIELD } from './SshKeyPayload'

export interface TemplateFieldOption {
  value: string;
  icon: Resource;
}

export interface TemplateFieldDefinition {
  key: string;
  label: Resource;
  icon: Resource;
  type: VaultFieldType;
  protected: boolean;
  multiline: boolean;

  // 非空表示该行读写 KDBX 保留字段（VaultEntryInput 的固定字段），不由自定义字段承载。
  reservedField: string;

  // 非空表示该行提供固定取值菜单。
  options: TemplateFieldOption[];

  // 附件行：取值不在字段里，而是条目的 KDBX 附件。
  attachments: boolean;

  // SSH 密钥行：字段值是多条密钥的 JSON，由专用卡片列表渲染。
  sshKeys: boolean;
}

export interface ItemTemplateDefinition {
  template: ItemTemplate;
  name: Resource;
  description: Resource;
  icon: Resource;
  fields: TemplateFieldDefinition[];
}

function reservedField(key: string, label: Resource, icon: Resource, protectedValue: boolean,
  multiline: boolean): TemplateFieldDefinition {
  return {
    key,
    label,
    icon,
    type: protectedValue ? VaultFieldType.Password : VaultFieldType.Text,
    protected: protectedValue,
    multiline,
    reservedField: key,
    options: [],
    attachments: false,
    sshKeys: false,
  }
}

function customField(key: string, label: Resource, icon: Resource, protectedValue: boolean,
  multiline: boolean = false, options: TemplateFieldOption[] = []): TemplateFieldDefinition {
  return {
    key,
    label,
    icon,
    type: protectedValue ? VaultFieldType.Password : VaultFieldType.Text,
    protected: protectedValue,
    multiline,
    reservedField: '',
    options,
    attachments: false,
    sshKeys: false,
  }
}

// 附件行不承载字段值，只承载条目的 KDBX 附件。
function attachmentField(label: Resource, icon: Resource): TemplateFieldDefinition {
  return {
    key: 'Attachments',
    label,
    icon,
    type: VaultFieldType.Text,
    protected: false,
    multiline: false,
    reservedField: '',
    options: [],
    attachments: true,
    sshKeys: false,
  }
}

// SSH 密钥行的字段值是多条密钥的 JSON，卡片列表由专用组件渲染。
function sshKeysField(label: Resource, icon: Resource): TemplateFieldDefinition {
  return {
    key: SSH_KEYS_FIELD,
    label,
    icon,
    type: VaultFieldType.Password,
    protected: true,
    multiline: false,
    reservedField: '',
    options: [],
    attachments: false,
    sshKeys: true,
  }
}

// 卡类型取值来自需求枚举；字段值仍是自由文本，菜单只是快捷填入。
// 图标为 128x128 方画布 PNG，深色词标另在 resources/dark 同名覆盖。
const CARD_TYPE_OPTIONS: TemplateFieldOption[] = [
  { value: '银联', icon: $r('app.media.card_type_unionpay') },
  { value: 'Visa', icon: $r('app.media.card_type_visa') },
  { value: 'Mastercard', icon: $r('app.media.card_type_mastercard') },
  { value: 'American Express', icon: $r('app.media.card_type_amex') },
  { value: 'JCB', icon: $r('app.media.card_type_jcb') },
  { value: 'Discover', icon: $r('app.media.card_type_discover') },
]

const LOGIN: ItemTemplateDefinition = {
  template: ItemTemplate.Login,
  name: $r('app.string.login_template'),
  description: $r('app.string.login_template_description'),
  icon: $r('app.media.layout_type_login'),
  fields: [
    reservedField('UserName', $r('app.string.username'), $r('sys.symbol.person'), false, false),
    reservedField('Password', $r('app.string.password'), $r('sys.symbol.lock'), true, false),
    reservedField('URL', $r('app.string.website'), $r('sys.symbol.link'), false, false),
    reservedField('Notes', $r('app.string.notes'), $r('sys.symbol.doc_text'), false, true),
  ],
}

const SECURE_NOTE: ItemTemplateDefinition = {
  template: ItemTemplate.SecureNote,
  name: $r('app.string.secure_note_template'),
  description: $r('app.string.secure_note_template_description'),
  icon: $r('app.media.layout_type_secure_note'),
  fields: [
    reservedField('Notes', $r('app.string.notes'), $r('sys.symbol.doc_text'), false, true),
  ],
}

const CREDIT_CARD: ItemTemplateDefinition = {
  template: ItemTemplate.CreditCard,
  name: $r('app.string.credit_card_template'),
  description: $r('app.string.credit_card_template_description'),
  icon: $r('app.media.layout_type_credit_card'),
  fields: [
    customField('CardNumber', $r('app.string.card_number'), $r('sys.symbol.creditcard'), true),
    customField('Issuer', $r('app.string.card_issuer'), $r('sys.symbol.building'), false),
    customField('CardType', $r('app.string.card_type'), $r('sys.symbol.card'), false, false, CARD_TYPE_OPTIONS),
    customField('CardHolderName', $r('app.string.card_holder'), $r('sys.symbol.person'), false),
    customField('Expiry', $r('app.string.card_expiry'), $r('sys.symbol.calendar'), false),
    reservedField('Notes', $r('app.string.notes'), $r('sys.symbol.doc_text'), false, true),
  ],
}

const PASSWORD: ItemTemplateDefinition = {
  template: ItemTemplate.Password,
  name: $r('app.string.password_template'),
  description: $r('app.string.password_template_description'),
  icon: $r('app.media.layout_type_password'),
  fields: [
    reservedField('Password', $r('app.string.password'), $r('sys.symbol.lock'), true, false),
    reservedField('Notes', $r('app.string.notes'), $r('sys.symbol.doc_text'), false, true),
  ],
}

const SSH_KEY: ItemTemplateDefinition = {
  template: ItemTemplate.SshKey,
  name: $r('app.string.ssh_key_template'),
  description: $r('app.string.ssh_key_template_description'),
  icon: $r('app.media.layout_type_ssh_key'),
  fields: [
    sshKeysField($r('app.string.ssh_key_add'), $r('sys.symbol.key')),
    reservedField('Notes', $r('app.string.notes'), $r('sys.symbol.doc_text'), false, true),
  ],
}

const ATTACHMENT: ItemTemplateDefinition = {
  template: ItemTemplate.Attachment,
  name: $r('app.string.attachment_template'),
  description: $r('app.string.attachment_template_description'),
  icon: $r('app.media.layout_type_attachment'),
  fields: [
    attachmentField($r('app.string.attachment_file'), $r('sys.symbol.paperclip')),
    reservedField('Notes', $r('app.string.notes'), $r('sys.symbol.doc_text'), false, true),
  ],
}

export const TEMPLATE_DEFINITIONS: ItemTemplateDefinition[] = [
  LOGIN,
  SECURE_NOTE,
  CREDIT_CARD,
  SSH_KEY,
  ATTACHMENT,
  PASSWORD,
]

// 未标记类型或类型暂未接入定义表时按通用模板渲染。
export function definitionFor(template: ItemTemplate | undefined): ItemTemplateDefinition {
  return TEMPLATE_DEFINITIONS.find((definition: ItemTemplateDefinition) =>
  definition.template === template) ?? LOGIN
}

export function isTemplateFieldKey(template: ItemTemplate | undefined, key: string): boolean {
  return definitionFor(template).fields.some((field: TemplateFieldDefinition) =>
  field.reservedField.length === 0 && field.key === key)
}
