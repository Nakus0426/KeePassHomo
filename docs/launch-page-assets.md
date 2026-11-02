# 启动页整屏图生成

系统启动页与应用首帧共用同一张整屏图，避免换场时标识与应用名位移。

## 资源

| 文件 | 说明 |
| --- | --- |
| `products/default/src/main/resources/base/media/launch_background.png` | 浅色版，底色 `#FFFFFF`，深色方底标识 + 深色应用名 |
| `products/default/src/main/resources/dark/media/launch_background.png` | 深色版，底色 `#0A0C0D`，浅色方底标识 + 浅色应用名 |
| `products/default/src/main/resources/base/media/launch_icon.png` | 启动页/桌面图标源图，脚本读取它合成整屏图 |
| `products/default/src/main/resources/base/profile/start_window.json` | `startWindowBackgroundImage` + `startWindowBackgroundImageFit: Cover` |

## 生成

```powershell
python tools/gen_launch_background.py
```

需要 Pillow。字体默认从 DevEco Studio 安装目录查找 `sdk/default/hms/previewer/resources/fonts/HarmonyOS_Sans_SC.ttf`；其他环境用 `--font <path>` 或环境变量 `HARMONYOS_SANS_FONT` 指定。

## 参数

脚本内常量对应设计稿 390×844vp 画布：

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `LOGO_SIZE_VP` | 86 | 标识方底边长 |
| `LOGO_TOP_VP` | 270 | 标识顶部位置，中心约在窗口高度 37% |
| `NAME_TOP_VP` | 382 | 应用名顶部位置（标识底部 + 26vp） |
| `NAME_SIZE_VP` | 22 | 应用名字号，字重 600 以 1px 描边近似 |
| `SCALE` | 3 | 导出倍率，成品 1170×2532 |

应用名是位图，改名后需重新执行脚本；设计稿改动（标识尺寸、位置、字号）也需同步修改上述常量。

## 多设备

平板等需要独立构图时，在对应限定词目录放同名 `launch_background.png`（如 `resources/tablet/media/`），代码无需改动。深色模式通过 `resources/dark/media/` 覆盖，与现有资源机制一致。
