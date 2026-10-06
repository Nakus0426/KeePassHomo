# KeePassHomo

KeePassHomo 是面向 HarmonyOS Phone 和 Tablet 的 KeePass 密码保险库应用，使用 ArkTS、ArkUI、Stage 模型和状态管理 V2 开发。

## 开发环境

- HarmonyOS SDK API 26
- DevEco Studio 及 Hvigor
- ohpm
- devecocli

安装依赖后，可在项目根目录执行：

```shell
ohpm install
devecocli build --product default --build-mode debug
```

## 团队签名

仓库只保留空的 `signingConfigs` 模板，不保存成员本机路径、证书、私钥、Profile 或密码。每位成员首次构建前，登录自己的华为开发者账号，在 DevEco Studio 的 `File > Project Structure > Signing Configs` 中勾选 `Automatically generate signature`（HarmonyOS 工程同时勾选 `Support HarmonyOS`），为本机生成调试签名。

成员各自自动签名适合日常开发。不同成员生成的调试签名不能互相覆盖安装同一个 HAP，也不保证应用数据可直接复用；如确实需要统一测试签名，应通过密码管理器或私有制品库分发材料，放入本地 `signing/` 目录，禁止提交 Git。正式发布签名只由维护者或 CI 持有。

修改签名配置后，在 DevEco Studio 执行 `Sync Now`。如果设备已安装其他签名的应用，先卸载旧应用再运行。

禁止提交以下内容：

- `sign/`、`signing/` 目录及 `.p12`、`.p7b`、`.cer`、`.pem`、`.key`、`.jks`、`.keystore` 文件
- `local.properties`、`.env` 及其他本机配置
- API Token、访问密钥、WebDAV 凭据、真实 KDBX 文件

提交前请检查暂存文件及完整差异：

```shell
git status
git diff --cached
```

## 安全问题

请勿通过公开 Issue 报告安全漏洞。报告方式见 [SECURITY.md](SECURITY.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
