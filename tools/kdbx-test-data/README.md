# KDBX 测试数据工具

开发期命令行工具：往**现有** KDBX 保险库批量追加「只有标题和用户名」的测试条目，并只读查看保险库结构与头部参数。用于手测条目列表（懒加载、滚动、标题省略号、首字母头像、收藏、筛选等）。

本目录**不参与 HAP 构建**：`build-profile.json5` 只列出 `products/default`、`common`、`features/*` 这些模块，`tools/`
不在其中，构建不会读到这里。

## 为什么用 npm 依赖

- app 侧 `ohpm` 的 `kdbxweb@2.3.0` 是 HarmonyOS HAR（产物是 `ets/modules.abc`），Node 里跑不了，所以这里用 **npm 同名库**
  `kdbxweb`。
- KDBX4 是标准格式，两边互通。已实测：本工具生成的文件在设备上被 app 解锁后，头部参数（加密算法、压缩、KDF、参数）与 app
  自己写出的库完全一致。
- `kdbxweb` 默认 KDF 是 **Argon2d**，Node 没有内置 Argon2，因此用 WASM 实现 `hash-wasm` 注入给
  `kdbxweb.CryptoEngine.setArgon2Impl`。**注意单位**：`kdbxweb` 传给 Argon2 实现的 `memory` 是 **KiB**（KDBX 头部 `M`
  字段是字节），脚本按此透传，改这段代码前先看 `kdbx-env.js` 的注释。

## 安装

```bash
cd tools/kdbx-test-data
npm install
```

## 用法

### 1. 追加测试条目

```bash
node gen-entries.js <保险库路径> <主密码> [数量] [--out <输出文件>]
```

- `数量` 默认 `100`。
- 默认**就地写回原文件**，写之前会在同目录生成 `<文件名>.backup-<时间戳>.kdbx` 备份。
- 加 `--out <文件>` 则写入新文件，原文件完全不动（不确定时用这个）。
- 写回后会重新加载一次自检，输出 `条目数：N -> M` 与文件大小。
- 只填 `Title` 与 `UserName`，`Password` / `URL` / `Notes` 一律留空；条目追加到库的默认分组（平铺，不建子分组）。

示例（就地追加 100 条，自动备份）：

```bash
node gen-entries.js /storage/media/100/local/files/Docs/Download/个人保险库.kdbx 123
```

示例（不改原文件，写新文件）：

```bash
node gen-entries.js ~/个人保险库.kdbx 123 300 --out ~/个人保险库_测试.kdbx
```

### 2. 只读查看保险库

```bash
node inspect.js <保险库路径> <主密码>
```

输出：文件大小、KDBX 版本、加密算法、压缩方式、KDF 与参数（P/I/M/V）、各分组的条目数、条目总数、前 3 条与末 3
条的标题/用户名。用来确认生成结果，也用来确认从设备拉回来的文件是不是你要的那份。

### 3. 设备侧完整流程（模拟器 / 真机）

```bash
# 1) 从设备取回现有保险库（只读，不动设备文件）
hdc file recv /storage/media/100/local/files/Docs/Download/个人保险库.kdbx ./个人保险库.kdbx

# 2) 本地追加条目（先写新文件，最安全）
node gen-entries.js ./个人保险库.kdbx 123 100 --out ./个人保险库_测试100.kdbx

# 3) 建议先本地复核
node inspect.js ./个人保险库_测试100.kdbx 123

# 4) 覆盖前先备份设备上的原文件，再推回覆盖
hdc file send ./个人保险库.kdbx /storage/media/100/local/files/Docs/Download/个人保险库.backup.kdbx
hdc file send ./个人保险库_测试100.kdbx /storage/media/100/local/files/Docs/Download/个人保险库.kdbx

# 5) 拉回来复核设备上那份
hdc file recv /storage/media/100/local/files/Docs/Download/个人保险库.kdbx ./from-device.kdbx
node inspect.js ./from-device.kdbx 123
```

推回后如果 app 里列表还是旧数据：app 可能仍持有已解锁的内存副本，**锁定再解锁**（或重启 app、或重新选一次该文件）让它从磁盘重读。

## 生成的数据长什么样

| 序号     | 标题                                                    | 用途             |
|--------|-------------------------------------------------------|----------------|
| 1–90   | `测试条目 001` … `测试条目 090`                               | 常规条目，压列表条数     |
| 91–95  | 超长中英混排标题                                              | 标题省略号、单行截断     |
| 96–98  | `AlphaBetaSite` / `GitHubPersonal` / `AmazonShopping` | 无头像时的「标题前两个字母」 |
| 99–100 | 含 emoji 与前后空格（`  🎉 …  `）                             | `trim` 与空标题回退  |
| > 100  | `测试条目 101` …                                          | 继续按序号命名        |

用户名统一为 `user001@example.com` … `user100@example.com`（序号补零到 3 位）。

命名规则集中在 `gen-entries.js` 顶部的 `LONG_TITLES` / `ENGLISH_TITLES` / `EMOJI_TITLES` 与 `titleOf()`，要换文案直接改这几处。

## 注意事项

- **这工具会真的写入 KDBX 文件**，别对生产库跑；默认就地写回会覆盖原文件（因此默认会先备份）。
- 绑定了**密钥文件**的库本工具不支持（需要主密码 + 密钥文件两段凭据），请在 app 里操作。
- 生成、复核、备份文件都是 `*.kdbx`，已被 `.gitignore` 忽略，不会进版本库。
- 端口/序列号不确定时先看 `devecocli device list`；`hdc` 可从 DevEco Studio 的 `sdk/default/openharmony/toolchains/` 直接用。
