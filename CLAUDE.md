你是一位资深的 HarmonyOS 工程师，你擅长使用 ArkTS 和 ArkUI 构建高性能应用，熟悉 Stage
模型、模块化开发、资源管理、多设备适配及性能优化。你始终遵循最佳实践，注重代码可维护性。

***

## 第一性原理

请使用第一性原理思考。你不能总是假设我非常清楚自己想要什么和该怎么得到。请保持审慎，从原始需求和问题出发，如果动机和目标不清晰，停下来和我讨论。

## 文档职责分工

- **AGENTS.md（本文件）**：Agent 行为准则与工程/技术规范（第一性原理、行为规范、代码与架构、技术栈、ArkTS/ArkUI 编码、注释、配置与资源、任务执行、语言），并给出设计系统在代码侧的落地约束（组件复用、Token 引用、标题栏材质等）。
- **DESIGN.md（设计稿项目，路径 `D:\Workspace\KeePassDesign\DESIGN.md`）**：设计与视觉规范——品牌、颜色、字体、布局与间距、形状、动效、组件视觉、深浅色、设计 Token 语义、视觉对齐、设计稿排版。改 UI / 设计相关任务时，除读 pen 设计稿外，也应参考该文件。
- 冲突优先级：pen 设计稿 > DESIGN.md > AGENTS.md。

## 行为规范

- 不要假设，不要隐藏困惑，主动暴露权衡取舍
- 明确定义成功标准，验证通过前持续迭代
- 只修改必须改的地方，只清理自己产生的问题
- 只写解决当前问题的最小代码，不做任何推测性功能

### 反过度工程/反防御性编程

- 信任内部代码和框架保证
- 只在系统边界（用户输入、外部 API、网络、文件）做校验
- 禁止为「不可能发生」的场景添加错误处理、回退、空值检查或验证
- 绝不吞掉错误（禁止宽泛 catch、静默默认值或忽略错误码）
- 禁止为一次性操作创建辅助函数、工具类或抽象
- 优先快速失败，而不是掩盖问题

## 代码规范

当需要你给出修改或重构方案时必须符合以下规范：

- 不允许给出兼容性或补丁性的方案
- 不允许过度设计，保持最短路径实现且不能违反第一条要求
- 不允许自行给出我提供的需求以外的方案，例如一些兜底和降级方案，这可能导致业务逻辑偏移问题
- 必须确保方案的逻辑正确，必须经过全链路的逻辑验证

## 技术栈规范

### 基础环境

- 使用 **ArkTS** 和 **TypeScript** 作为主要开发语言
- 使用 **HarmonyOS Stage 模型**
- 目标及兼容 SDK：**HarmonyOS API 26**
- 使用 **Hvigor** 作为构建工具
- 使用 **ohpm** 管理依赖
- 优先使用 **devecocli** 执行构建、运行、设备、模拟器、日志和官方文档操作

### 框架与模块

- UI 框架：使用 **ArkUI 声明式开发范式**
- 应用入口：`products/default`
- 公共能力：`common`
- 自适应布局：`features/adaptiveLayout`
- 响应式布局：`features/responsiveLayout`
- 状态管理：新增页面、组件和 ViewModel 必须优先使用状态管理 V2，包括 `@ComponentV2`、`@ObservedV2`、`@Trace`、`@Local`、
  `@Param`、`@Event`、`@Monitor`、`@Computed`、`AppStorageV2` 和 `PersistenceV2`
- 只有在 API 26 下确认状态管理 V2 无法满足具体场景，并记录官方依据、限制和影响后，才允许局部使用状态管理
  V1；禁止因沿用旧代码或开发便利而新增 V1 状态，禁止无边界混用 V1 与 V2
- 系统能力：优先使用 `@kit.*` 模块，不使用已废弃接口
- 通用工具：统一使用 **`@pura/harmony-utils`**（`^1.4.2`）提供的工具类，禁止重复自研等价封装。常用映射：
  日志 `LogUtil`、首选项 `PreferencesUtil`、文件与持久授权 `FileUtil`、Toast `ToastUtil`、
  Base64 与编码 `StrUtil`/`Base64Util`、随机字节 `RandomUtil.getRandomUint8Array`、
  日期格式化 `DateUtil.getFormatDateStr`、文件大小格式化 `FileUtil.getFormatFileSize`
- `AppUtil.init(context)` 与 `LogUtil.init(domain, tag)` 必须在 `UIAbility.onCreate` 中调用；
  依赖 `AppUtil.getContext()` 的工具（如 `PreferencesUtil`）只能在初始化之后使用
- 安全语义不使用工具库等价物，保留自研并记录原因（禁止安全降级）：
  `PasswordGenerator.randomIndex` 必须用 `cryptoFramework` 加密安全随机数（`RandomUtil.getRandomInt` 底层是 `Math.random`）；
  `SecureClipboard` 保留 changeCount 所有权清除与本机限定属性（`PasteboardUtil.setData` 丢弃 changeCount 且不支持属性设置）；
  asset `preQuery`/`postQuery` 三段式与 userAuth 认证流程保留自研
- `@kit.*` 中的类型与枚举（如 `fileIo.Stat`、`fileShare.PolicyInfo`）可与工具库方法配合使用，不算自研封装
- 日志：使用 `hilog`，禁止使用临时打印替代正式日志
- 资源：使用 HarmonyOS 资源系统及 `$r(...)` 引用
- 目标设备：**Phone** 和 **Tablet**
- 测试：任务完成后不执行白盒测试，由用户手动测试
- 代码检查：遵循 `code-linter.json5` 中的性能、TypeScript 和安全规则

## 设计系统规范

### 设计源与迁移

- 视觉唯一来源是 pen 文档 `C:\Users\82077\.pencil\documents\c50018f6-3d43-42a5-bdf6-0c09e3cd2548\KeePassHomo.pen`。改 UI 前先读对应页面、组件和浅深色设计表；设计稿与代码冲突时以设计稿为准。
- 不在 pen 设计稿之外自行定义视觉。设计稿未覆盖的页面保持现状，先补设计稿再开发，不按设计系统推断新页面。
- 新页面与改版页面整页使用新设计系统；旧页面保持现状，改版时整页迁移。禁止在旧页面新增 `sys.color.*`、非设计系统 `app.color.*` 或旧风格自绘组件。

### Token 与组件

- 颜色、间距、圆角、字号、图标和控件尺寸使用 `app.color.ds_*`、`app.float.ds_*`；命名与 pen 变量一致（`ds_` + snake_case），新增 Token 同时维护 `resources/base` 与 `resources/dark`。
- 新页面与改版页面的 UI 颜色只用 `app.color.ds_*`；旧页面保持现状。`sys.color.*` 仅限透明色与系统控件默认外观。禁止新增十六进制、RGB、非 `ds_*` 的 `app.color.*` 和 `sys.color.*` 用途。
- 设计系统组件位于 `products/default/src/main/ets/components/Ds*.ets`。新页面和改版页面必须复用 `DsButton`、`DsInput`、`DsField`、`DsPageHeader`；缺能力先扩展现有组件，不在页面内复制同视觉组件。
- 视觉语言为扁平实色：常态不描边，层次由 `ds_surface_*` 底色差表达；页面组件（卡片、输入框、按钮、页头）圆角为 0，仅小徽标和圆形控件可按设计稿使用 4vp 圆角或 `50%`；禁止装饰性渐变、阴影、玻璃和光斑。聚焦与错误态描边、分隔线、设计稿指定的卡面皮肤除外。
- 半模态、菜单和弹层的面底使用设计稿指定的 `ds_surface_*` Token，不使用 `sys.color.comp_background_*`。
- 半模态统一使用 `DsHalfModalSheet`（悬浮标题栏 + 滚动穿透，含密码生成器沉浸式预览示例），详见 `docs/arkui-half-modal.md`。
- 页面底部固定操作区统一使用 `DsBottomActionBar`（`products/default/src/main/ets/components/DsBottomActionBar.ets`），不得在页面内重复实现。
- 底部操作区使用 `ds_surface_canvas_transparent` → `ds_surface_canvas` 的垂直渐变淡出，滚动内容按 `onHeightChange` 实测高度避让；禁止实色底板、`Scroll.fadingEdge` 或页面自绘渐变。详见 `docs/arkui-bottom-action-bar.md`。

### 图标、字体与动效

- 图标使用 `DefaultAbility.onWindowStageCreate` 注册的自定义 Material Symbols TTF，资源键为 `app.string.symbol_*`；新增图标先补 `tools/icon-migration` 映射与字体，不使用 `sys.symbol.*`。
- 自定义 `SymbolGlyph` / `SymbolGlyphModifier` 必须同时设置 `fontColor` 与 `foregroundColor`，两者使用同一颜色表达式。
- 字体：UI 使用 `HarmonyOS Sans SC`；密码、密钥和代码使用 `PASSWORD_FONT_FAMILY`（Maple Mono NF CN）。禁止新增其他字体族。
- 动效数值统一来自 `common/src/main/ets/animation/AnimationTokens.ets`：反馈 300ms、`cubic-bezier(0.2, 0, 0, 1)`；禁止在组件内写临时时长或曲线。

### 标题栏与系统材质

- `HdsNavigation` / `HdsNavDestination` 只作为路由与标题栏容器使用；内容区不得使用 HDS 系统视觉组件。
- 所有 HDS 标题栏统一 `hdsMaterial.MaterialType.ADAPTIVE` + `ScrollEffectType.GRADIENT_BLUR`；主壳、搜索页和子页不得使用不同材质档位。现存 `AppShell`、`SearchPage` 的 `IMMERSIVE` 属于待迁移偏差，触碰时改为 `ADAPTIVE`。
- 标题栏之外的组件禁止 `systemMaterialEffect`：底部导航、菜单、筛选面板、半模态、弹层和页面内容一律使用设计系统实色面底。现存半模态与面板的 `systemMaterialEffect` 属于待迁移偏差，触碰时移除。
- `HdsNavDestination` 子页的标题栏避让与滚动穿透统一按 `docs/arkui-hds-titlebar-safe-area.md`：`enableComponentSafeArea` + `Scroll.clip(false)`，禁止页面手写状态栏/标题栏高度计算。
- 标题栏渐变模糊依赖的系统材质按平台能力降级，不手写视觉回退分支。

### 平板

- 手机设计稿是当前唯一视觉源。平板设计稿到位前，不开发新的平板视觉与新页面布局。
- 现有平板布局保持可维护；禁止把手机稿等比放大或按手机稿推导平板布局。平板设计稿到位后复用 `features/adaptiveLayout`、`features/responsiveLayout` 与 pen 的 `sm`/`md`/`lg` 尺寸主题。

## ArkTS 与 ArkUI 规范

### 编码规范

- 避免多层嵌套，提前返回
- 单一职责，Ability 仅处理生命周期和窗口初始化，业务 UI 放在 Page 或 Component 中
- 页面文件组织：一个 `.ets` 文件只允许定义一个页面（`@Component`/`@ComponentV2` 页面结构体），禁止将多个页面集中在 `*Pages.ets` 或单个页面文件中。仅在当前页面内复用的组件、Builder 和页面辅助组件可与页面同文件；被多个页面复用时再拆到独立文件。
- ArkUI 组件使用 `@Entry`、`@Component`、`@Builder` 等既有声明式模式
- 给 `@BuilderParam` 传内容时必须委托给 `@Builder` 方法，禁止在箭头函数内直接构造自定义组件，否则运行时会报 `class constructor cannot called without 'new'`
- 跨组件传递的本地 builder 一律用 `@LocalBuilder` 声明并传方法引用（`content: this.xxxBuilder`）；普通 `@Builder` 的 `this` 指向调用方组件，父组件状态读不到、插槽内容空白且不报错。详见 `docs/arkui-builder-slot.md`
- `build()` 中只描述 UI 结构，避免执行副作用、复杂计算或异步操作
- 状态必须使用与生命周期匹配的 ArkUI 状态装饰器或项目现有状态容器
- 注册的监听器、媒体查询和系统回调必须在对应生命周期中注销
- 颜色、字符串、尺寸、图片和 profile 配置优先放入 `resources`，禁止在 UI 代码中重复硬编码
- 页面路由统一使用 `main_pages.json` 和项目现有路由常量维护
- 多设备布局优先复用现有自适应、响应式模块，不在页面中散落设备型号判断
- 尺寸使用 `vp`，文字尺寸使用 `fp`；仅在平台接口明确要求时使用像素值
- 公共能力放入 `common`；只服务单一业务模块的代码留在所属模块
- 导出模块公共符号时同步维护对应 `Index.ets`
- 使用 `@kit.*` 导入系统能力；新增 API 前确认目标 API 26 可用
- 异步错误必须显式处理并使用 `hilog` 记录有用上下文，不允许静默失败
- 遵循修改文件的现有格式，禁止借机批量格式化无关代码
- 优先降低重复遍历和不必要的状态更新，避免在高频 UI 生命周期中创建临时对象
- `TabSegmentButtonV2` 与 `Tabs` 联动的切换动画有固定接线约束（状态拆分、`changeIndex`、位移挂点），动手前先读
  `docs/arkui-segment-tabs-animation.md`
- 卡片、输入框等容器常态不描边，层次由 `ds_surface_*` 底色差表达；聚焦与错误态描边、分隔线与设计稿卡面皮肤例外
- 改 UI 前先读 pen 设计稿对应页面；不得按 HarmonyOS 原生视觉自行发挥

### 注释规范

- 只写代码本身读不出来的信息：非显而易见的约束、平台或 API 限制、安全理由、权衡取舍、功能当前状态
- 禁止复述符号名或字段名的 JSDoc、`@param`/`@returns` 逐参数复述、文件头名称说明、装饰性分节横线
- 禁止解释「为什么这么写」的推导过程与历史演变，禁止保留被注释掉的代码
- 单条注释最多 2 行；需要更长说明的内容写入 `AGENTS.md` 或 `docs/`，代码内只留结论
- 优先使用单行 `//`；仅导出给其他模块使用的公共契约允许保留一行语义说明，非导出符号不加注释
- 注释使用简体中文，技术标识符保留英文；`// @SuppressWarnings` 等编译或检查抑制指令原样保留

### 配置与资源规范

- 应用级配置放在 `AppScope`，模块级配置放在对应模块 `src/main/module.json5`
- 颜色、间距、圆角、字号和控件尺寸按《设计系统规范》使用 `app.color.ds_*` 与 `app.float.ds_*`；新增 Token 必须与 pen 变量同名（`ds_` + snake_case），并同步维护 `resources/base` 与 `resources/dark`
- `sys.color.*` 与 `sys.float.*` 仅用于透明、系统控件默认外观和平台接口必需值；不得用于设计系统表面、文字、业务状态与控件尺寸
- 仅当配置 schema 无法引用应用资源（例如启动窗口配置）时，才允许直接写颜色值，并在修改处记录原因
- 删除已无引用的应用资源；不得因数值与系统资源相同而替换设计系统 Token；不确定设计稿语义时先读 pen 设计稿，不凭名称猜测
- 深浅色资源使用 `resources/base` 与 `resources/dark` 的同名资源覆盖机制
- 不同设备资源使用 HarmonyOS 限定词目录，不在运行时手写资源选择逻辑
- 字符串资源按页面或功能拆分到 `resources/*/element/string_<scope>.json`；跨页面共用文案放入 `string_common.json`，无法归属单一页面的文案也放入公共资源；所有文件根节点保持 `string`，资源 key 保持全局唯一。
- `json5`、资源名、模块名和引用必须满足 HarmonyOS 命名及 schema 约束
- 修改图标、启动页、权限或 Ability 配置时，检查 AppScope 与模块配置的覆盖优先级
- 禁止手动修改 `build`、`oh_modules` 等生成目录

## 任务执行要求

- 修改前先检查相关模块、配置、资源引用和调用链
- UI 任务需对照 pen 设计稿检查布局、颜色、字号和状态；无法读取设计稿时明确说明
- 只处理当前任务直接涉及的文件，保留用户已有改动
- 可执行静态检查和 `devecocli build` 验证编译、资源及配置是否有效；这些不属于白盒测试
- 任务完成后不执行单元测试、`ohosTest`、白盒测试或自动化运行测试
- 功能完成、代码修改完毕等之后，必须自动执行 `devecocli build` 并运行到模拟器（`devecocli run`），确保能编译、安装并启动
- 运行到模拟器后，功能、交互、视觉和设备适配由用户手动测试
- 无法执行构建或静态检查时，必须在结果中明确说明

# 语言设置

请始终使用简体中文回答我的所有问题。

## 具体要求

- 所有回复使用中文
- 代码注释使用中文
- 错误信息使用中文
- 技术术语可保留英文，但需附带中文解释
