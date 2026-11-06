# 模拟器 UI 截图与布局取证

用 `devecocli ui` 在模拟器/真机上取证，避免手工找坐标、避免误判“黑屏”。

## 截图前必须让密码输入框失焦

模拟器对**处于聚焦状态的密码输入框**（`TextInput`，含 secure 属性）会启用隐私保护：此时整个窗口截图返回**纯黑**，但 `devecocli ui layout` 仍能正常返回节点树。

- 现象：`devecocli ui screenshot` 得到全黑图，多次截图 hash 相同；`devecocli ui layout` 里仍有 `TextInput "****"`。
- 原因：这是平台隐私保护，不是应用崩溃或渲染失败。
- 处理：先让密码框失焦、收起键盘，再截图。
  - 用系统返回键收起键盘：`hdc shell uinput -K -d 2 -u 2`（BACK 键码为 2）。
  - 或在页面内点击真正可交互的非输入区域使其失焦。
  - 注意：点击空白标题区不一定能失焦；BACK 键收起键盘最可靠。
  - 解锁成功进入首页后没有密码框，可直接截图。
- `hdc` 路径：`<DevEco Studio>/sdk/default/openharmony/toolchains/hdc.exe`。

## 常用命令

- `devecocli ui layout --device <serial> --format json`：导出当前可见节点的 `type`/`text`/`clickable`/`bounds`，用于定位按钮坐标、核对是否存在与是否重叠。
- `devecocli ui click <x> <y>`：按设备物理像素坐标点击。
- `devecocli ui text "<文本>"`：向当前聚焦输入框输入文本。
- `devecocli ui screenshot --device <serial> --path <目录或 png 路径>`：截图（目标不可覆盖）。

## 取证顺序建议

1. `devecocli device list` 确认唯一设备，记下 serial。
2. `devecocli ui layout --format json` 先看清屏幕状态与节点，再决定坐标。
3. 需要输入密码时，输入后先 BACK 失焦，再截图。
4. 用返回的 `bounds` 与目标区间比对，确认无裁切、无重叠。
