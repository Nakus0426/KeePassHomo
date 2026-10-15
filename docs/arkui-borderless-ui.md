# 无边框界面规范（卡片、输入框与视觉分层）

卡片、输入框、头像与按钮容器默认不画描边，组件与背景的分层由底色差表达；描边只留给状态反馈。本文是取值与写法约束，新增或改动这类容器装饰之前先读。

## 常态无边框

以下容器一律不写常态描边：

- 卡片：`EntryCard`、`SshKeyCard`、`WelcomePage` 的数据源卡、`GeneratorComponents` 的三个参数卡与结果卡、`EntryPreviewView` 的四张信息卡、`EntryTemplatePicker` 模板卡、`EntryCustomFields` 字段类型卡
- 输入框容器：`FormTextField`、`FormTextArea`、`EntryAttachmentField` 附件行、`EntryTagEditor` chip 输入
- 头像与圆形控件：`EntryAvatar`、`EntryAvatarPicker` 的头像与其右下角圆形编辑按钮

被禁止的写法就是拿 `sys.color.comp_background_secondary` 当描边色：

```ets
// 禁止：用描边做与背景的分层
.border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
```

## 分层靠底色差

| 层级 | 资源 |
|---|---|
| 页面底 | `sys.color.background_secondary` |
| 卡片与输入底 | `sys.color.comp_background_primary` |
| 半模态内卡片底 | `sys.color.comp_background_tertiary` |

去掉描边后卡片仍可辨，前提是容器底与页底用不同资源；新增页面时不要把两者取成同一个值。圆形头像靠 `sys.color.background_emphasize` 底色与页底区分，不再补圆环。

## 状态描边保留

聚焦与错误态仍要描边，只有常态透明：

- 常态 `Color.Transparent`，聚焦 `sys.color.brand`，校验失败 `sys.color.warning`
- 保留 `width: $r('sys.float.border_width')`，只改颜色；改宽度会同时动布局与边框过渡
- 保留原有 `.animation({...})`，状态切换的过渡依赖它

```ets
.border({
  width: $r('sys.float.border_width'),
  color: this.invalidFieldId === field.id ? $r('sys.color.warning') : Color.Transparent,
})
```

透明底的输入若走下划线式（`.showUnderline(true)`），其下划线是输入区唯一的可见边界，不要与常态描边一起去掉。

## 允许的描边

以下描边不受本规范约束，改动时不要顺手删除：

- 卡面皮肤：`EntryPreviewView` 银行卡片的白色棱边（`width: 1` + `ColorUtil.withAlphaHex($r('sys.color.white'), cardRimOpacity)`，随按压深度提亮）
- 分隔线：`Divider()`、List 的 `.divider({...})`、`.menuItemDivider({...})`、单边 border 冒充分割线（`UnlockPage` 解锁输入区底部线）
- `Search`、`Select` 等系统组件的默认外观，不额外加自定义描边
- 阴影与圆角：`.shadow(...)`、`borderRadius(...)`、`'50%'` 圆形圆角

## 参考实现位置

- 状态描边唯一入口：`products/default/src/main/ets/components/FormTextField.ets` 的 `formFieldBorderColor()`；`FormTextArea` 复用同一函数，改一处即两处生效
- 透明占位写法：`pages/vault/EntryCustomFields.ets`（无效字段 warning）、`pages/vault/EntryTagEditor.ets`（超长标签 warning）
- 允许例外：`pages/vault/EntryPreviewView.ets` 的银行卡片棱边
- 无边框卡片参考：`components/EntryCard.ets`
