# 图标迁移映射表（Material Symbols Outlined）

状态：映射表已确认，POC 已通过。进入全量 TTF 生成与按模块迁移阶段。

## 决策

- 目标：摆脱系统 Symbol 版本依赖，统一为 Material Symbols Outlined。
- 渲染：自定义 Symbol TTF + `symbolRegister`，保留 `SymbolGlyph` / `SymbolGlyphModifier` API。
- 填充态：`FILL=1` 作为独立 glyph，不复用描边 glyph。
- 迁移：按模块分批，先组件层，再 onboarding，再 vault。
- 动画：本阶段只对 `eye / visibility_off` 做形变；其余成对图标先用 `ReplaceSymbolEffect(CROSS_FADE)`。
- POC 先行：先验证 8 个 glyph 的注册、着色、字号和系统组件接线，通过后再生成全量 57 个基础图标。
- `error` / `check_circle` 按设计稿使用 FILL=0；状态强调交给颜色。
- `bank_card` / `card` / `creditcard` 合并为 `credit_card`。
- `upload` 与 `upload_file` 都保留，具体用法以设计稿为准。

## 实测体积

- Material Symbols Outlined 完整可变字体：10.7 MB。
- 固定 `wght=400, opsz=24, FILL=0, GRAD=0` 的全量静态字体：1.4 MB。
- 当前映射 + 设计新增共 57 个基础图标：8.9 KB。
- 加入 6 个 `FILL=1` glyph 后：约 10–12 KB。

## 现有系统 Symbol 映射

| 现有 Symbol | 引用数 | 语义资源键 | Material Symbols | FILL | 说明 |
|---|---:|---|---|---:|---|
| `chevron_forward` | 12 | `symbol_chevron_right` | `chevron_right` | 0 | 列表/卡片前进箭头 |
| `xmark` | 6 | `symbol_close` | `close` | 0 | 关闭/清除 |
| `plus` | 6 | `symbol_add` | `add` | 0 | 新建/添加 |
| `doc_text` | 6 | `symbol_notes` | `description` | 0 | 文本/备注 |
| `square_and_pencil` | 5 | `symbol_edit` | `edit_square` | 0 | 编辑 |
| `eye` | 5 | `symbol_eye` | `visibility` | 0 | 显示密码；morph 起点 |
| `chevron_down` | 5 | `symbol_chevron_down` | `expand_more` | 0 | 展开 |
| `checkmark` | 5 | `symbol_check` | `check` | 0 | 确认 |
| `trash` | 4 | `symbol_delete` | `delete` | 0 | 删除 |
| `lock` | 4 | `symbol_lock` | `lock` | 0 | 锁定/密码 |
| `eye_slash` | 4 | `symbol_eye_off` | `visibility_off` | 0 | 隐藏密码；morph 终点 |
| `exclamationmark_circle_fill` | 4 | `symbol_error` | `error` | 0 | 按设计稿使用描边 |
| `doc_text_on_doc_text` | 4 | `symbol_copy` | `content_copy` | 0 | 复制 |
| `folder` | 4 | `symbol_folder` | `folder` | 0 | 分组 |
| `key` | 3 | `symbol_key` | `key` | 0 | 密钥 |
| `chevron_up` | 3 | `symbol_chevron_up` | `expand_less` | 0 | 收起 |
| `star_fill` | 3 | `symbol_star_filled` | `star` | 1 | 收藏选中 |
| `star` | 3 | `symbol_star` | `star` | 0 | 收藏未选中 |
| `chevron_backward` | 2 | `symbol_chevron_left` | `chevron_left` | 0 | 返回 |
| `person` | 2 | `symbol_person` | `person` | 0 | 用户 |
| `arrow_down_to_line` | 2 | `symbol_download` | `download` | 0 | 下载/导出 |
| `folder_fill` | 2 | `symbol_folder_filled` | `folder` | 1 | 分组选中/强调 |
| `folder_badge_plus` | 2 | `symbol_create_folder` | `create_new_folder` | 0 | 新建分组 |
| `wand_and_stars` | 2 | `symbol_generate` | `auto_awesome` | 0 | 密码生成器 |
| `arrow_left` | 2 | `symbol_arrow_back` | `arrow_back` | 0 | 返回 |
| `arrow_counterclockwise` | 1 | `symbol_refresh` | `refresh` | 0 | 重置/刷新 |
| `square_fill_grid_2x2` | 1 | `symbol_grid_filled` | `grid_view` | 1 | 浏览模式选中 |
| `square_grid_2x2` | 1 | `symbol_grid` | `grid_view` | 0 | 浏览模式 |
| `picture` | 1 | `symbol_image` | `image` | 0 | 头像/图片 |
| `archivebox_fill` | 1 | `symbol_archive_filled` | `archive` | 1 | 归档选中 |
| `upload` | 1 | `symbol_upload_file` | `upload_file` | 0 | 导入密钥文件 |
| `paperclip` | 1 | `symbol_attach_file` | `attach_file` | 0 | 附件 |
| `magnifyingglass` | 1 | `symbol_search` | `search` | 0 | 搜索 |
| `plus_square` | 1 | `symbol_add_square` | `add_box` | 0 | 新建 |
| `label` | 1 | `symbol_label` | `label` | 0 | 标签 |
| `link` | 1 | `symbol_link` | `link` | 0 | 链接 |
| `checkmark_circle_fill` | 1 | `symbol_check_circle` | `check_circle` | 0 | 按设计稿使用描边 |
| `info_circle_fill` | 1 | `symbol_info_filled` | `info` | 1 | 只读提示 |
| `info_circle` | 1 | `symbol_info` | `info` | 0 | 信息 |
| `icloud` | 1 | `symbol_cloud_sync` | `cloud_sync` | 0 | WebDAV/云同步 |
| `arrow_right` | 1 | `symbol_arrow_forward` | `arrow_forward` | 0 | 前进 |
| `arrow_up_right` | 1 | `symbol_open_in_new` | `north_east` | 0 | 打开外链 |
| `arrow_up_to_line` | 1 | `symbol_upload_file` | `upload_file` | 0 | 选择密钥文件 |
| `bank_card` | 1 | `symbol_credit_card` | `credit_card` | 0 | 卡号 |
| `building` | 1 | `symbol_business` | `business` | 0 | 发卡机构 |
| `creditcard` | 1 | `symbol_credit_card` | `credit_card` | 0 | 与 bank_card 共用 glyph |
| `calendar` | 1 | `symbol_calendar` | `calendar_month` | 0 | 有效期 |
| `card` | 1 | `symbol_credit_card` | `credit_card` | 0 | 与 bank_card 共用 glyph |
| `lock_fill` | 1 | `symbol_lock_filled` | `lock` | 1 | 锁定强调 |
| `archivebox` | 1 | `symbol_archive` | `archive` | 0 | 归档 |

## 设计稿新增图标

| Material Symbols | 语义资源键 | FILL | 用途 |
|---|---|---:|---|
| `bolt` | `symbol_bolt` | 0 | 快速操作 |
| `dns` | `symbol_dns` | 0 | 服务器 |
| `fingerprint` | `symbol_fingerprint` | 0 | 生物识别 |
| `folder_open` | `symbol_folder_open` | 0 | 打开本地保险库 |
| `gpp_maybe` | `symbol_security_warning` | 0 | 证书/安全警告 |
| `horizontal_rule` | `symbol_divider` | 0 | 分隔符选择 |
| `keyboard_tab` | `symbol_keyboard_tab` | 0 | Tab 键 |
| `lock_open` | `symbol_lock_open` | 0 | 解锁 |
| `more_horiz` | `symbol_more` | 0 | 更多 |
| `radio_button_checked` | `symbol_radio_selected` | 0 | 单选选中 |
| `radio_button_unchecked` | `symbol_radio_unselected` | 0 | 单选未选中 |
| `remove` | `symbol_remove` | 0 | 减号 |
| `space_bar` | `symbol_space_bar` | 0 | 空格键 |
| `sync` | `symbol_sync` | 0 | 同步 |
| `upload` | `symbol_upload` | 0 | 通用上传 |
| `verified_user` | `symbol_verified_user` | 0 | 安全校验 |

## 已确认

- `error` / `check_circle` 使用 FILL=0，与设计稿一致。
- 卡类图标合并为 `credit_card`。
- `upload` 与 `upload_file` 都保留，具体用法以设计稿为准。
- 语义资源键采用 `symbol_*`，不直接暴露 Material 名称。
- 设计稿未覆盖的现有图标按本表补映射；后续如发现语义不符，再单独调整。

## POC（已通过）

POC 只改 `WelcomePage`，使用 5 个 glyph：

| 语义键 | Material | 接线 |
|---|---|---|
| `symbol_arrow_back` | `arrow_back` | 返回按钮 `SymbolGlyph` |
| `symbol_arrow_forward` | `arrow_forward` | 动作卡右下箭头 `SymbolGlyph` |
| `symbol_add_square` | `add_box` | 新建保险库卡片图标 |
| `symbol_folder` | `folder` | 打开本地保险库卡片图标 |
| `symbol_cloud_sync` | `cloud_sync` | WebDAV 卡片图标 |

POC 验收：WelcomePage 的返回箭头、3 张动作卡图标、3 个卡片右下箭头全部显示；颜色和字号正确；深浅色正常；日志无“自定义 Symbol 注册失败/异常”。

## 全量资源

- `symbol_all.ttf`：10.6 KB，57 个基础图标 + 6 个填充变体
- `symbol_all.json`：3.8 KB
- `string_symbols.json`：63 个语义键，4.8 KB
- `DefaultAbility.onWindowStageCreate` 注册单个合并字体
- 生成脚本：`tools/icon-migration/generate_symbols.py`，映射：`tools/icon-migration/mapping.json`

POC 发现：

- `symbolRegister` 注册成功，5 个图标全部显示，字号与深色模式正常。
- 自定义 `SymbolGlyph` 不响应 `fontColor`：`filled=true` 的新建卡片图标仍使用默认主题文字色，浅色下黑底黑图标、深色下白底白图标。
- `foregroundColor` 可修复颜色：WelcomePage 两处已实测正常。
- 全量迁移约束：所有自定义 `SymbolGlyph` / `SymbolGlyphModifier` 必须同时设置 `fontColor` 与 `foregroundColor`，两者使用同一颜色表达式。
- 填充态按独立 `FILL=1` glyph 处理；本表共 57 个基础图标 + 6 个填充变体。

## TTF 生成约束

- 源文件：`google/material-design-icons` 的 `MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf`，固定 `wght=400, opsz=24, GRAD=0`。
- 每个语义键分配 `0x100000` 以上的 PUA-B codepoint，写入 `app.string.symbol_*`，值为 `0x...`。
- 注册 JSON 采用 `{ version, axes, icons }` 清单；描边与填充字体分别注册。
- 生成脚本和映射表一起提交，保证可重现；生成产物放 `products/default/src/main/resources/rawfile/symbol/`。
- 许可证：Material Symbols Apache-2.0；在关于页保留 Google 署名。
