# 《生态轮回》V1.9 运行与导出

## 直接运行

本项目使用 Godot 4.7.1 制作，不依赖第三方插件。

```bash
godot --editor --path .
```

打开后按 F6/F5，或直接运行：

```bash
godot --path .
```

## 操作

| 功能 | 键鼠 | 触屏 |
|---|---|---|
| 移动 | WASD / 方向键 | 在左侧下半区任意位置按下并拖动摇杆 |
| 冲刺 | Shift | 右下“冲刺” |
| 普通攻击 | 按住鼠标左键 / J | 按住右下“攻击” |
| 主动技能 | 空格 | 右下技能按钮 |
| 进食 | E | 右下“进食” |
| 展开/关闭战报 | 点击顶部战报 / Esc | 触摸顶部战报 / “返回生态战场” |
| 暂停 | Esc | 右上暂停按钮 |

普通攻击只在攻击范围内触发。食草物种吃绿色植物，肉食物种吃尸体，狐狸和熊两者都能吃。

攻击更强物种时不要正面换血：诱导对方把耐力消耗到 20% 以下，或等待其主动技能结束。敌方血条显示金色“可逆袭”后命中，可以部分穿甲、造成百分比生命伤害并继续削减耐力。耐力低于 10% 会力竭，必须恢复到 25% 才能重新冲刺、攻击和释放技能。

小中型物种可以利用地图草丛：走进草丛后停下约 0.72 秒，状态栏显示“伏击就绪”。此时步行离开掩体并用首次普通攻击命中强敌，可以直接发动逆袭。冲刺会立即打断伏击蓄势，巨象等巨型物种不能使用草丛隐蔽。

每种物种还有明确的主场和熟悉区域。在适应区域持续移动约 1.15 秒，状态栏会显示地形反制就绪；把不适应这里的强敌引进同一区域，再用普通攻击命中即可发动逆袭。双方都适应该区域时不会触发，命中后需要重新移动蓄势。

弱物种遭到强敌追击时，还可以观察紫色“生态借力”提示。把追兵带到提示中的第三方附近，并诱使追兵发动一次攻击，第三方会转而接战追兵。成功引战后不要继续站桩，利用混战脱离、等待破绽或争取生态助攻经验。

每次随机成为新物种时，先显示该物种的数值、成长方向与获胜攻略。第一次进入关卡还会显示五步操作教学。教学可跳过，并可在“游戏设置”中重新开启。设置页还提供性能、平衡、高画质三档；手机默认使用平衡档，若出现卡顿建议切换到性能档。

首页“自由模式”可直接选择第 1–10 关和任意 30 种物种。该模式使用零世界威胁，胜负不推进正常战役，也不增加死亡次数；退回首页后可继续原战役。游戏设置页只保留声音、画质、教学与重置选项。

## Web

项目固定使用 Compatibility 渲染器、GDScript 和单线程 Web 预设，避免 `SharedArrayBuffer` 和跨源隔离要求。安装与 Godot 4.7.1 完全匹配的导出模板后：

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

不要双击 `index.html` 直接运行；必须通过 HTTP 服务：

```bash
python3 -m http.server 8000 --directory build/web
```

然后访问 `http://localhost:8000`。

### GitHub Pages 自动发布

仓库包含 `.github/workflows/deploy-web.yml`。推送到 `main` 分支后，GitHub Actions 会使用 Godot 4.7.1 自动导出 Web 版本并发布到 Pages。首次创建仓库后，在仓库的 `Settings → Pages → Build and deployment` 中将 Source 设为 `GitHub Actions`。

发布成功后的地址格式：

```text
https://976971956.github.io/eco-rebirth/
```

本地重新导出可以运行：

```bash
./tools/export_web.sh
```

## Android

需要 JDK 17、Android SDK Platform 35、Build-Tools 35.0.1，以及与 Godot 4.7.1 匹配的 Android 导出模板。调试 APK：

```bash
mkdir -p build/android
godot --headless --path . --export-debug Android build/android/EcoRebirth.apk
```

Google Play 发布应改为 Gradle 构建、AAB 格式，并在 Godot 编辑器设置自己的正式签名。不要把 keystore 或密码提交到项目。

## iOS

iOS 只能在 macOS 上导出，需要 Xcode、Godot 4.7.1 iOS 模板和有效 Apple Developer Team ID。

当前本机真机测试配置使用 Personal Team `BYSMY792J7` 和 Bundle ID `com.jianghu.ecorebirth`。换用其他开发者账号或发布到 App Store 时，需要在 `export_presets.cfg` 中替换成相应的 Team ID 与唯一 Bundle ID。然后：

```bash
mkdir -p build/ios
godot --headless --path . --export-debug iOS build/ios/EcoRebirth
```

导出 Xcode 项目后在 Xcode 中配置签名、真机或 App Store 构建。本项目使用 Compatibility 渲染器，兼容 iOS 模拟器限制。

仓库中的 `build/ios/EcoRebirth.xcodeproj` 已在本机用 Xcode 的通用 iOS Device（arm64、关闭签名）完成编译验证。正式安装仍必须填写自己的 Team ID 并签名。如果当前 Godot iOS 模板缺少适配本机模拟器的原生架构切片，请改用真机目标，或重新安装完整的同版本模板。

## 跨端设计

- 逻辑分辨率 1280×720，UI 使用锚点并允许宽屏扩展；
- 原生移动端支持左右两个横屏方向；手机 Web 竖屏时会暂停并提示旋转；
- Android/iOS HUD 与弹窗读取系统安全显示区域，避开刘海、圆角和底部手势区；
- 小屏触控布局使用更大字号、至少 52 像素的普通按钮和 96–150 像素的主要动作按钮；
- Compatibility 渲染器，可运行于 WebGL 2 和移动端 OpenGL；
- 无线程、无 GDExtension、无桌面专属 API；
- 低多边形程序化动物和森林，场景不依赖大型外部模型；
- 触屏设备自动显示虚拟摇杆和动作按钮；
- `ConfigFile` 存档写入各平台的 `user://` 沙盒；
- 存档带独立数据版本号，并自动兼容、迁移旧格式数据；
- 三档画质会联动阴影、天气粒子、特效可见距离和远景动作降频；
- Android 同时启用 `armeabi-v7a` 与 `arm64-v8a`；iOS 使用 arm64；Web 使用单线程模板。

## 自动验证

检查 30 种物种、解锁、技能和移动域：

```bash
godot --headless --path . --script res://tools/validate_species.gd
```

检查旧存档迁移、画质档位和教学步骤：

```bash
godot --headless --path . --script res://tools/validate_release.gd
```

无画面启动并运行生态模拟：

```bash
godot --headless --path . --quit-after 1200 -- --autoplay
```

该命令会自动跳过菜单、生成森林和 10 个个体，可用于 CI 检查脚本错误和运行时异常。

## 发布前仍需替换的账号信息

- iOS Apple Developer Team ID；
- iOS 唯一 Bundle ID 与签名；
- Android 正式包名（如果 `com.ecorebirth.game` 不属于发布者）；
- Android 发布 keystore；
- 商店隐私政策、截图、年龄分级和元数据。
