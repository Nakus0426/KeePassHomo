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

## 本地签名

仓库不提供签名证书、私钥、Profile 或密码。需要签名产物时，请通过 DevEco Studio 为本机生成或配置签名，并确保签名配置和材料仅保存在本地。

禁止提交以下内容：

- `sign/` 目录及 `.p12`、`.p7b`、`.cer`、`.pem`、`.key`、`.jks`、`.keystore` 文件
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
