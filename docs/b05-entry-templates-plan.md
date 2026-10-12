# B05/B07 六类条目模板与动态编辑/预览 — 实施计划

> 临时文档：本文件用于实施期间防止上下文偏移，人工验收通过后删除。
> 主计划：`docs/keepass-harmonyos-development-plan.md`（7.2.3 B05/B07）
> 基线日期：2026-10-10 代码现状

## 1. 目标

把 `ItemTemplate` 的六类模板从"零引用枚举"变成可用能力：新建条目时选择模板，条目编辑页与预览页按模板类型动态渲染字段。

六类：登录信息、安全备注、银行卡、SSH 密钥、附件、密码。

## 2. 已确认决策

| 编号  | 决策                                                                                                                                                                                                                                                           |
|-----|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| D1  | 类型存条目 customData，键 `KPEX_LayoutType`（跨客户端草案键名），值 `Login`/`SecureNote`/`CreditCard`/`SshKey`/`Attachment`/`Password`（PascalCase，与文件内 camelCase 风格不同，记入主计划 18 章）                                                                                               |
| D2  | 类型仅在新建时写入；`updateEntry` 不接收类型。打开无类型条目走通用模板（登录信息），保存不回写类型                                                                                                                                                                                                     |
| D3  | SSH 私钥存受保护字段 `PrivateKey`（`VaultFieldType.Password`），公钥存字段 `PublicKey`（明文）。不采用 KeePassXC 的"私钥放附件"约定                                                                                                                                                          |
| D4  | 生成密钥时同时写入公钥                                                                                                                                                                                                                                                  |
| D5  | RSA 档位 2048/3072/4096，默认 3072；Ed25519 固定 256 位；私钥不加密（OpenSSH 容器 cipher none，无口令）                                                                                                                                                                             |
| D6  | 单附件上限 10 MB，超限拒绝；保存前提示整库体积变化                                                                                                                                                                                                                                 |
| D7  | 附件键名 = 原文件名，同条目内重名自动加序号                                                                                                                                                                                                                                      |
| D8  | 模板字段值为空则不写入；已有值被清空即删除该字段                                                                                                                                                                                                                                     |
| D9  | 卡号 `protected=true`；发卡行/卡类型/持卡人/有效期明文                                                                                                                                                                                                                        |
| D10 | 有效期用文本 `MM/YY`，不做日期选择器                                                                                                                                                                                                                                       |
| D11 | 「最近使用」只在模板卡片上显示徽标，最多 3 项，顺序不变                                                                                                                                                                                                                                |
| D12 | 模板选择器为独立半模态，由 `VaultHomePage` 承载；`EntrySheet` 不新增形态                                                                                                                                                                                                          |
| D17 | 徽标底色 `sys.color.comp_emphasize_secondary`、文字 `sys.color.brand`，不新增颜色资源                                                                                                                                                                                       |
| D18 | 模板类型不可切换（新建即定死）；不属于当前模板的自定义字段显示在「其他」区                                                                                                                                                                                                                        |
| D19 | 模板选择器按设计稿：原生 HDS 标题栏（标题「新建条目」+ 关闭项），无副标题；卡片纯色底 `comp_background_primary` + 灰边框 `comp_background_secondary` + 圆角 `corner_radius_level10`；2 列网格                                                                                                                |
| D20 | 图标 `layout_type_*`（1024×1024，6 张合计约 956 KB）直接使用，不缩放                                                                                                                                                                                                          |
| D21 | 模板选择器排版：`GridRow` + `GridCol`，按组件宽度切档（`BreakpointsReference.ComponentSize`），一行 2 个（xs/sm）最多 3 个（md/lg/xl/xxl）；卡片宽度按列数均分，高度固定 `app.float.template_card_height`（144vp）；半模态左右边距、卡片间距、卡片内边距统一 `sys.float.padding_level8`；图标 `app.float.template_icon_size`（48vp） |
| D22 | SSH 模板改为**多密钥**：一个条目内不限条数，全部密钥序列化进**一个受保护自定义字段** `SshKeys`（JSON：name/algorithm/bits/addedAt/privateKey/publicKey），删除原独立的「公钥」行；卡片摘要＝名称 + 算法 · 位数 · 加入日期；徽标区分「待保存/已添加」                                                                                         |
| D23 | 密钥动作走**长按卡片**（`bindContextMenu` + `ResponseType.LongPress`）：复制私钥、复制公钥、导出私钥、（编辑页）重命名、删除；点按卡片＝复制私钥。预览页只保留复制私钥/复制公钥，只读                                                                                                                                          |
| D24 | 上传/粘贴/生成三个入口收进「添加密钥」下拉菜单（生成密钥为二级菜单选算法）；**粘贴**因安全控件限制改为两步：选「粘贴」后行内出现 `PasteButton`，由用户点它完成授权与取值                                                                                                                                                               |
| D25 | 单条密钥文本上限 64 KB，条目内密钥数不设上限；导入密钥用 `inspectSshPrivateKey` 解析算法与位数并补出 OpenSSH 公钥行（OpenSSH 容器、RSA PKCS#1/PKCS#8 PEM）                                                                                                                                              |

## 3. 分层改动

### 3.1 common（数据与引擎）

`common/src/main/ets/vault/VaultContracts.ets`

- `ItemTemplate` 六值替换。
- 新增 `LAYOUT_TYPE_KEY = 'KPEX_LayoutType'`。
- `VaultEntry` 增 `template: ItemTemplate | undefined`。
- `VaultEntryInput` 增 `template?: ItemTemplate`（仅创建消费）。

`common/src/main/ets/vault/KdbxVaultEngine.ets`

- `toItemTemplate(value)`：字符串 → 枚举，非法值返回 `undefined`。
- `mapEntry`：读 `customData.get(LAYOUT_TYPE_KEY)`。
- `createEntry`：写该键（`{value, lastModified}`）。
- `updateEntry`：不触碰该键。

`common/Index.ets`：导出 `LAYOUT_TYPE_KEY`。

### 3.2 产品层模板定义表（单一定义源）

`products/default/src/main/ets/model/EntryTemplateCatalog.ets`（新建）

```ts
export interface TemplateFieldDefinition {
  key: string;            // KDBX 字段名，模板行固定不可改名
  label: Resource;
  icon: Resource;         // 预览行图标
  type: VaultFieldType;
  protected: boolean;
  multiline: boolean;
  reservedField: string;  // 非空表示读写 KDBX 保留字段
  options: string[];      // 非空表示提供固定取值菜单（卡类型）
}
export interface ItemTemplateDefinition {
  template: ItemTemplate;
  name: Resource;
  description: Resource;
  icon: Resource;
  fields: TemplateFieldDefinition[];
}
```

字段清单：

| 模板              | 模板区行                                                                                            | 落点                                       |
|-----------------|-------------------------------------------------------------------------------------------------|------------------------------------------|
| Login           | 用户名、密码、网址、备注                                                                                    | 保留字段 `UserName`/`Password`/`URL`/`Notes` |
| SecureNote      | 备注                                                                                              | `Notes`                                  |
| CreditCard      | 卡号 `CardNumber`(protected)、发卡行 `Issuer`、卡类型 `CardType`(菜单)、持卡人 `CardHolderName`、有效期 `Expiry`、备注 | 自定义字段 + `Notes`                          |
| SshKey（批 2）     | 密钥 `PrivateKey`(protected)、公钥 `PublicKey`、备注                                                    | 自定义字段 + `Notes`                          |
| Attachment（批 2） | 文件（KDBX 二进制）、备注                                                                                 | `entry.binaries` + `Notes`               |
| Password        | 密码、备注                                                                                           | `Password`/`Notes`                       |

六类共同：头像、标题、分组、自定义字段（「其他」区）、标签。

导出：`TEMPLATE_DEFINITIONS`、`definitionFor(template)`（未命中回落 Login 定义）、`isTemplateFieldKey(template, key)`。

**批 1 定义表只含 4 类**（登录信息、安全备注、银行卡、密码），不显示灰色占位；批 2 加入 SSH 密钥与附件。

### 3.3 ViewModel

`EntryEditorViewModel`

- `EntryFieldEditor` 增 `readonly templateKey: string`（构造参数，空串=用户自定义字段）。
- `EntryEditorViewModel` 增 `@Trace template: ItemTemplate`。
- `removeField`/`renameField`/`setFieldValue` 改为接收字段对象（去掉索引参数，避免过滤后索引错位）。
- `fieldInputs()`：`templateKey` 非空且值为空 → 不提交（D8）。
- `currentValue()`：纳入 `templateKey`。
- `reset()`：`template` 复位 Login。

`AppViewModel`

- `loadNewEntry(editor, template)`：按定义表补齐模板字段空项。
- `loadEntryForEdit`：`template = entry.template ?? Login`；读入全部非保留字段（现状）；补齐缺失的模板自定义字段为空项（只在草稿）。
- `saveEntry`：`input.template` 仅新建时传。
- 最近使用：`@Trace recentTemplates: ItemTemplate[]` + `markTemplateUsed`，存 `PreferencesUtil`（非敏感，
  `PREFERENCES_NAME = 'entry_templates'`）。

`EntrySheetViewModel`

- `openNew(template)`（改签名，删除无参重载）、`@Trace newEntryTemplate`。
- 预览增 `@Computed get template()`。

### 3.4 View

| 文件                                       | 改动                                                                                                                   |
|------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `pages/vault/EntryTemplatePicker.ets`（新） | 独立半模态内容：`HdsNavigation` + `titleMode(MODAL)` + `titleBar`（`mainTitle: 新建条目`、菜单项关闭）；`Grid` 2 列白卡；卡片含图标/名称/描述 + 最近使用徽标 |
| `pages/vault/VaultHomePage.ets`          | 承载选择器半模态；两处新建入口改为先开选择器；`pendingTemplate` + `onDisappear` 里再开编辑半模态                                                    |
| `pages/vault/EntryEditorView.ets`        | 按 `editor.template` 渲染模板区；「其他」区沿用 `EntryCustomFields`                                                                |
| `pages/vault/EntryCustomFields.ets`      | 只渲染 `templateKey === ''` 的字段                                                                                         |
| `pages/vault/EntryPreviewView.ets`       | 按模板渲染行；「其他」= 非保留且非本模板字段；受保护行共用一套显隐倒计时                                                                                |

### 3.5 资源

`products/default/src/main/resources/base/element/string_vault.json`

- 替换/补齐模板名与描述：`login_template`(+desc)、`secure_note_template`(+desc)、`credit_card_template`(+desc)、
  `ssh_key_template`(+desc)、`attachment_template`(+desc)、`password_template`(+desc)
- 删除：`identity_template`、`wifi_template`、`license_template`
- 新增：`recent_used_template`、`card_number`、`card_issuer`、`card_type`、`card_holder`、`card_expiry`、`ssh_private_key`、
  `ssh_public_key`、`attachment_file`
- 图标：`app.media.layout_type_login` / `_secure_note` / `_credit_card` / `_ssh_key` / `_attachment` / `_password`

## 4. 批次

**批 1**：契约 → 引擎 → 定义表 → ViewModel → 选择器 → 编辑页 → 预览页 → 资源 → 主计划文档 → 构建验证。
**批 2**：引擎附件接口（`loadAttachment`/`addAttachment`/`removeAttachment`，二进制必须经 `kdbx.createBinary` 入池，保存前
`cleanup({binaries:true})`）→ 附件模板 UI（上传/删除/导出，导出前再认证，体积提示）→ SSH 编码模块（新
`common/src/main/ets/ssh/SshKeyEncoder.ets`：SSH wire format、mpint、Base64、OpenSSH 私钥容器 cipher none、公钥行；RSA 私钥走
`getEncodedPem('PKCS8')`）→ SSH 三动作（上传文件 / `PasteButton` 粘贴 / 生成）→ 资源 → 文档 → 构建验证。

### 批 2 实际实现（与计划的差异）

- 引擎附件接口落在 `VaultEngine`：`loadAttachment`/`addAttachment`/`removeAttachment`；`VaultEntry.attachments` 提供名字与体积；
  `VaultEntryInput` 不承载附件。
- **未使用 `kdbx.cleanup({binaries:true})`**：该调用会顺带按 `meta.historyMaxItems` 裁剪历史，属于静默数据变更。改为引擎内自研
  `removeUnreferencedBinaries`，只回收无引用二进制（含历史条目引用判定）。
- SSH 编码模块拆为 `common/src/main/ets/ssh/SshKeyFormat.ets` + `SshWireFormat.ets`。
- 再认证界面用 `promptAction.presentCustomDialog`（4.2 的「确认弹窗」行列），不开第二个半模态；不新增 4.2 例外。
- 附件导出入口只在编辑页；预览页附件只读展示名字与体积（B04 的展示要求，导出仍在编辑页）。
- 附件单文件上限 10 MB（`ATTACHMENT_MAX_BYTES`），超限跳过并提示。

## 5. 明确不做

模板搜索、模板类型切换、多用户名/多网址/TOTP、SSH 口令字段（结构上预留）、KeePassXC SSH agent 兼容、第三方模板组识别、附件总大小硬上限。

## 6. 验证

1. 静态检查与 `devecocli build --product default --modules default@default --build-mode debug`。
2. 用户手动验收：六类新建、类型落盘（`KPEX_LayoutType`）、「其他」区不丢第三方字段、空模板字段不落盘、最近使用徽标、编辑/预览按模板渲染。
3. 批 2 追加：附件增删导出、生成的 Ed25519 私钥能被 `ssh-keygen -l -f` 与 `ssh -i` 正常读取。

### 已完成

- 批 1 与批 2 代码均已完成，`devecocli build --product default --modules default@default --build-mode debug` 通过（BUILD
  SUCCESSFUL）。
- SSH 私钥 `openssh-key-v1` 容器布局已用本机 `ssh-keygen -t ed25519 -N ""` 生成的真实私钥（`cipher=none`/`kdf=none`
  ）逐字节核对：magic、cipher/kdf 名、kdfoptions 长度、nkeys=1、51 字节公钥 blob、私钥段 8 字节对齐、checkint 两次相同、keytype、段内公钥与
  blob 公钥一致、64 字节 `seed || pub`、comment 空、padding 从 0x01 递增、Base64 70 列与末尾换行，全部一致；RSA 侧用
  `RSA_PK_BN`（SDK 无 `RSA_E_BN`）取 e，mpint 编码与 `ssh-keygen -t rsa` 的 .pub 逐字节一致。
- `fixedBytes` 增加长度守卫：密钥参数超出目标长度直接抛错，避免平台语义不符时静默截断产出不可用密钥。
- 新增/改动文件：
    - `common`：`VaultContracts.ets`（六类枚举、`LAYOUT_TYPE_KEY`、`itemTemplateFrom`、`VaultEntry.template/attachments`、
      `VaultAttachmentMeta/Change`、`VaultEngine` 附件方法）、`KdbxVaultEngine.ets`（类型读写、附件增删读、未引用二进制回收）、
      `ssh/SshKeyFormat.ets` + `ssh/SshWireFormat.ets`、`Index.ets`。
    - 产品层：`model/EntryTemplateCatalog.ets`（新增）、`model/StageOneVaultStore.ets`（附件变更与保存）、
      `viewmodel/EntryEditorViewModel.ets`（模板字段、附件草稿）、`viewmodel/EntrySheetViewModel.ets`、
      `viewmodel/AppViewModel.ets`（模板装载、最近使用、SSH 生成、附件读取）、`pages/vault/EntryTemplatePicker.ets`（新增）、
      `EntryAttachmentField.ets`（新增）、`EntrySshKeyField.ets`（新增）、`EntryEditorView.ets`、`EntryPreviewView.ets`、
      `EntryCustomFields.ets`、`VaultHomePage.ets`、`resources/base/element/string_vault.json`、
      `resources/base/element/float.json`。

### 待用户手动验收（构建无法覆盖）

| 项              | 说明                                                                                             |
|----------------|------------------------------------------------------------------------------------------------|
| 六类模板新建与渲染      | 选择器六张卡片、类型落盘、编辑/预览按模板显示字段                                                                      |
| 「其他」区          | 打开带旧自定义字段（含银行卡字段出现在登录条目）的库，字段不丢                                                                |
| 空模板字段不落盘       | 保存后用 KeePassXC 或 XML dump 确认没有空 `<String>`                                                     |
| 附件             | 上传（含 >10 MB 拒绝）、删除、导出（再认证弹窗）、体积提示                                                              |
| 生成的 Ed25519 私钥 | 用 `ssh-keygen -l -f` 与 `ssh -i` 读取；RSA 用 PKCS#8 PEM                                            |
| 粘贴控件           | 编辑半模态内 PasteButton 的授权是否生效（官方文档未说明半模态场景，构建期仅有一条 `READ_PASTEBOARD` 静态警告，属官方"使用粘贴控件无需申请权限"的已知误报） |
| 两个半模态交接        | 模板选择器收起后再开编辑半模态，无叠加、无闪烁                                                                        |
| 深浅色与图标解码       | 白卡灰边在深色模式下的层级；6 张 1024² 图标同屏流畅度                                                                |

## 7. 风险

| 风险                                                   | 处置                                                                                                                                                    |
|------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| kdbxweb `writeBinaries` 遇池外二进制提前 return，静默丢弃后续附件     | 二进制一律经 `kdbx.createBinary` 入池                                                                                                                         |
| Ed25519 `getEncodedPem` 文档未列举（可能抛 801）               | 不依赖：OpenSSH 容器自建，DER 用 `getEncoded()`                                                                                                                 |
| 模板字段补齐给未填字段写空值污染库                                    | D8 过滤空值 + 引擎 obsolete 删除实现"清空即删除"                                                                                                                     |
| `PasteButton` 精确签名与临时授权范围未核实                         | 批 2 实现前查官方文档                                                                                                                                          |
| 两个半模态交接时序                                            | picker `onDisappear` 里再开编辑半模态                                                                                                                         |
| 1024² 图标同屏解码内存（最坏约 24 MB）                            | 真机验收滚动流畅度，异常再缩到 256                                                                                                                                   |
| 卡片白底与内容面同色                                           | 灰边框提供边界；真机对比深色模式                                                                                                                                      |
| 自定义组件直接写在 `contentBuilder: () => { Xxx({...}) }` 箭头里 | 编译通过但运行时报 `class constructor cannot called without 'new'`（组件创建没进 `@Builder` 作用域）；组件必须在 `@Builder`/`@LocalBuilder` 方法体内创建，再按引用或经方法调用交给 `@BuilderParam` |
