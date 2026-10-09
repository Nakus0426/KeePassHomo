# 本地签名材料

此目录只用于本地调试或受控团队测试签名。签名材料包含私钥，禁止提交 Git。

`local-signing.json` 保存本机签名配置，由项目根目录执行 `node tools/signing/local-signing.mjs` 从 `build-profile.json5` 导出，工程级 `hvigorfile.ts` 在构建时读取并注入 `app.signingConfigs`。文件内容为工程级 `signingConfigs` 数组，字段与 `build-profile.json5` 一致（`name`、`type`、`material.certpath`、`material.storeFile`、`material.profile`、`material.keyAlias`、`material.keyPassword`、`material.storePassword`、`material.signAlg`）。

`material` 中的路径可以指向 `C:\Users\<用户>\.ohos\config\` 下的自动签名材料，也可以把 `.p12`、`.p7b`、`.cer` 放入本目录后用相对路径引用；本目录的签名文件已被 `.gitignore` 忽略。

日常开发推荐使用 DevEco Studio 自动签名。团队需要安装同一签名 HAP 时，再由维护者通过密码管理器或私有制品库分发同一套 `.p12`、`.p7b`、`.cer` 和密码；不要通过代码仓库传递。
