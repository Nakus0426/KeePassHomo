# 阶段 0 技术验证记录

基线日期：2026-08-19  
目标：HarmonyOS API 26，Stage 模型，Phone/Tablet

## 结论

KDBX 路线采用 OHPM `kdbxweb` 2.3.0。ArkTS 侧只依赖 `KdbxVaultEngine` 的领域接口，页面不直接引用 KDBX
对象、密码学库或文件流。2026-08-19 至 2026-08-20 已在 API 26 模拟器使用真实 KDBX 4.x 文件完成往返验证，并完成合成
KDBX、文件创建与重新定位、用户认证与安全存储、剪贴板、WebDAV、相机扫码、`otpauth` 解析及文件错误边界人工验收。阶段 0 已完成。

## kdbxweb 评估

| 项目     | 结论                                                                                            |
|--------|-----------------------------------------------------------------------------------------------|
| 包      | `kdbxweb@2.3.0`，OHPM HAR，Bytecode HAR                                                         |
| 许可证    | MIT                                                                                           |
| 维护信息   | OHPM 元数据记录最近更新 2025-12-08；上游仓库为 KeeWeb/kdbxweb                                                |
| API 适配 | 包元数据声明 compatible SDK 17，目标工程 API 26，高于其最低声明                                                  |
| 依赖     | `@xmldom/xmldom@0.9.8`、`@ohos-rs/argon2@0.1.3`、`@ohos/flate2@1.0.0`                           |
| 原生库    | 构建产物包含 arm64-v8a 与 x86_64 的 Argon2、flate2 库                                                   |
| 能力     | KDBX 3/4 读写、升级、ProtectedValue、附件、历史、回收站、合并 API 均有声明                                           |
| 风险     | 构建时存在 Argon2 `module.json` 元数据告警、xmldom 重名代理告警和 source map 告警；当前不阻断编译，真实 ABI/KDF/文件样本已通过模拟器验收 |

采用边界：`KdbxVaultEngine` 负责 KDBX 对象生命周期和错误分类；`VaultDocument` 只暴露业务模型；受保护字段只暴露名称和保护状态，不把明文交给
UI；密钥文件字节在验证流程 `finally` 中清零。

## 已实现

- KDBX 3.1/4.x 签名和版本识别。
- 引擎提供主密码创建、保存、重新解锁和数据一致性自检。
- 引擎提供主密码 + 随机密钥文件组合凭据自检。
- ProtectedValue、附件、历史记录、回收站创建/读取检查。
- KDBX 3.1 只读打开、升级到 4.x、再次解锁检查。
- 错误密码、坏签名、不支持版本和内部内容损坏的分类；验证失败在候选数据校验阶段不会替换原文件。
- 文件选择、持久读写授权、只读判断、应用沙箱临时文件、候选文件重新打开校验、备份和失败恢复。API 26 Beta2 模拟器中，
  `checkPersistentPermission` 在授权前后均返回 `false`，且 `deactivatePermission`、`revokePermission`
  成功后，即使使用从未授权过的外部副本并重启整个模拟器，URI 仍可读取。因此该模拟器不能用于验证授权记录撤销后的访问失效；验证器只依据
  API 26 官方错误码检查授权失效分类，不把上述状态查询或撤销行为作为通过条件。真实设备或后续正式系统镜像发布前必须复验该行为。
- 本地 KDBX 新建与重新解锁、文件重新定位和逐字节一致性验证入口。
- 文件不存在、授权失效、空间不足、配额不足和只读文件系统错误分类；持久授权支持状态检查、重启后激活和撤销。
- User Authentication Kit + Asset Store 的一次性快速解锁材料验证；测试材料读回后清零并删除，主密码不落盘。
- 剪贴板写入使用应用 tag；条件清除使用 API 18 变更计数令牌，不申请受限的 `READ_PASTEBOARD` 权限。
- RCP `PROPFIND` WebDAV 请求、系统 TLS 校验、HTTP/传输错误分类，以及 `ETag`/`Last-Modified` 版本来源验证。
- Scan Kit 默认扫码入口和结构化 `otpauth` TOTP/HOTP URI 解析；界面与日志不显示密钥。
- Ability 仅保留生命周期、窗口隐私模式和全局遮罩协调；移除模板备份扩展和示例路由。
- 正式路由、资源 Token、深色资源、脱敏 `hilog` domain/tag。
- `VaultSource`、`VaultFormat`、`VaultCredential`、`SyncState`、`ConflictResolution`、`ItemTemplate`、`AuditFinding`、
  `VaultEngine`、`VaultRepository`、`VaultSession`、`SyncService`、`SecurityAuditService` 接口。

## 系统能力决策

| 能力        | 路线                                                                                      | 当前状态                                                |
|-----------|-----------------------------------------------------------------------------------------|-----------------------------------------------------|
| 本地文件      | Core File Kit `DocumentViewPicker` + `fileShare.persistPermission`/`activatePermission` | 真实文件选择、创建、持久授权、重启读取、写回和重新定位已通过；可写、只读、空间与授权失效错误分类已通过 |
| 隐私遮罩      | `window.setWindowPrivacyMode(true)` + 前后台 `AppStorage` 遮罩                               | 截图、后台和最近任务人工验收通过                                    |
| 用户认证/快速解锁 | User Authentication Kit；随机短材料使用 Asset Store，主密码不落盘                                      | PIN 认证、材料读回、清零和删除已通过人工验收                            |
| 剪贴板       | Pasteboard 写入时设置应用 tag；以写入后的变更计数作为所有权令牌，计数不匹配时拒绝清除                                      | 写入、错误令牌拒绝清除和正确令牌清除已通过人工验收                           |
| WebDAV    | RCP 发送 `PROPFIND`；TLS 使用系统证书校验；资源版本优先取 `ETag`，缺失时取 `Last-Modified`                      | 坚果云真实 HTTPS 资源已通过人工验收                               |
| 扫码        | Scan Kit 默认扫码入口；结果仅接受并解析 `otpauth` TOTP/HOTP URI                                        | 合成 `otpauth` 二维码扫码和结构化解析已通过人工验收                     |
| 备份        | 不注册 `BackupExtensionAbility`；显式关闭 cloud file/structured data sync                       | 已完成工程配置                                             |

## 已通过的模拟器人工验收

1. 真实 KDBX 4.x 显示库名、格式、分组数、条目数和受保护字段数。
2. 原始 KeePass 工具可重新打开写回后的文件，原条目和密码正确，不存在 `KeePassHomo.Validation` 字段。
3. 应用重启后可再次选择并完成往返验证。
4. 错误密码被拒绝，原文件仍可正常打开。
5. 应用进入后台、截图和最近任务时敏感页面已遮挡。
6. 合成 KDBX 4.x 创建、写入、关闭、重新解锁和数据一致性验证通过。
7. 受保护字段、附件、历史、回收站、组合凭据、KDBX 3.1 只读升级及错误分类验证通过。
8. 本地 KDBX 创建、持久授权、重新定位和逐字节一致性验证通过。
9. 系统 PIN 认证与 Asset Store 一次性材料保存、读回、清零和删除验证通过。
10. 剪贴板应用标记、变更计数所有权和条件清除验证通过。
11. 坚果云 WebDAV `PROPFIND`、TLS 和远端版本标识验证通过。
12. Scan Kit 相机/相册扫码与 `otpauth` TOTP URI 解析验证通过。
13. 文件可写、只读拒绝以及空间不足、配额不足、只读文件系统和授权失效错误码分类验证通过。

真实文件往返验证与合成兼容性自检相互独立，避免合成样本失败阻断真实文件验收，并保留独立错误定位。

## 退出条件结论

真实 KDBX 4.x 文件已完成打开、解锁、读取、修改、安全写回和重新解锁验证，错误流程未损坏原文件。阶段 0 的技术路线均已有明确结论，不存在阻断阶段
1 的未知项。API 26 Beta2 模拟器的 FileShare 状态查询与撤销行为属于已知平台验证限制，不改变仓储依据官方错误码处理授权失效的实现，但必须在真实设备或后续正式系统镜像上复验。对系统文件选择器返回的单文件
URI，当前仓储采用“沙箱候选 + 备份 + 校验后覆盖 + 失败恢复”，不宣称具备断电级原子提交。
