

这是一份巨魔项目代码，拷贝自开源项目TrollSpeed，现在命名为TrollMemo。
TrollSpeed可以正常打包ipa并使用巨魔商店安装
TrollMemo打包ipa后，却没法通过巨魔商店安装。
目前这个项目版本回退到了最初始的状态。
而@examples\TrollMemo 里面是之前失败的改造代码。
@examples\TrollMemo里面的改造，参考的一个非开源的ipa包：XLsnowState.ipa，但是它的进程控制与桌面文字显示，总是被后台杀掉了。没有TrollSpeed.ipa显示的那么稳定。
打包方式是使用的：@examples\TrollMemo\.github\workflows\build-manual.yml 在github里打包的。
这几个是XLsnowState.ipa的界面参考：@examples\20260616104839_1_84.jpg，@examples\20260616104840_2_84.jpg，@examples\20260616104841_3_84.jpg，红色的字就是固定在界面保持不动的，类似TrollSpeed的流量显示。但是我只需要文字。
现在的问题是：
1. TrollSpeed只能在桌面显示流量，但是我需要的是文字，而且这个的进程非常稳定，不会被杀进程。
2. XLsnowState可以在桌面显示文字，但是进程不稳定，容易被杀掉，而且这个闭源，没法找到源码改造。
3. 我做的@examples\TrollMemo可以说已经做完了，但是无法正常打包，也不知道原因。
4. 如果能分析出具体原因，则继续在@examples\TrollMemo里面改造。
5. 如果确实搞不定，想在这个项目上重新开发，只能推倒旧的@examples\TrollMemo，重新在这份代码里面开发改造，开发的界面仍然参考：@examples\20260616104839_1_84.jpg，@examples\20260616104840_2_84.jpg，@examples\20260616104841_3_84.jpg。

---

## 优化记录（2026-06-16 分析结论）

**建议路线：继续在 @examples\TrollMemo 上改造，不必推倒重来。**
TrollSpeed 的稳定 HUD 底层（root spawn、entitlements、全局窗口）应完整保留，只改显示层（网速 → 自定义文字）。

### P0 — 打包 / 安装（优先修，很可能导致巨魔商店装不上）

- [ ] 修复 `examples\TrollMemo\.github\workflows\build-manual.yml`：checkout 路径写的是 `TrollSpeed`，但 `cd` 的是 `TrollMemo`，路径不一致会导致构建失败或产物异常
- [ ] 对齐 TrollSpeed 的 `Makefile` `after-package` 步骤：恢复随机化 `CFBundleVersion`、处理 `CFBundleIconName`（TrollMemo 里这两步被注释掉了）
- [ ] 确认产物结构正确：`Payload/TrollMemo.app/`，且 `ldid -Sentitlements.plist` 签名后 `application-identifier` 与 `CFBundleIdentifier`（`ch.better.hudapp`）一致
- [ ] 安装失败时记录巨魔商店具体报错（解析失败 / 无法安装 / 同 bundle 冲突等），便于进一步定位

### P1 — 功能逻辑（文字显示未完成）

- [ ] 统一配置存储：`EditTextSettingsViewController` 和 `HUDRootViewController.applyTextSettings` 目前用 `[NSUserDefaults standardUserDefaults]`，应改为与主 App 一致的 `GetStandardUserDefaults()` 或 `USER_DEFAULTS_PATH` plist（`/var/mobile/Library/Preferences/ch.better.hudapp.plist`），否则 HUD 读不到保存的文字
- [ ] 删除 / 禁用网速定时器：`resetLoopTimer` 仍每秒调用 `updateSpeedLabel`，会把自定义文字覆盖成网速数据
- [ ] 清理网速相关代码：`getifaddrs`、`formattedSpeed`、`getUpDownBytes` 等 NetworkSpeed13 逻辑可移除或改为纯文字刷新
- [ ] 修复 `applyTextSettings` bug：先设置 `textAlpha`，又被 `backgroundAlpha` 覆盖到 `hudTextView.alpha`
- [ ] `reloadUserDefaults` 时应调用 `applyTextSettings`，确保 NOTIFY_RELOAD_HUD 后 HUD 立即刷新文字样式

### P2 — 工程完整性

- [ ] 将 `EditTextSettingsViewController.m` 加入 `TrollMemo.xcodeproj`（theos 的 `sources/*.m` 能编到，但 `build.sh` 走 Xcode 路径会漏掉）
- [ ] 清理冗余文件：`layout\Library\LaunchDaemons\ch.xxtou.hudservices.plist` 与 `ch.better.hudservices.plist` 并存，确认只保留 `ch.better` 版本
- [ ] `memory_pressure` 子模块确认已初始化（根仓库 submodule 状态为未检出）

### P3 — UI 对标 XLsnowState（后续迭代）

- [ ] 文字内容编辑（已有基础）
- [ ] 文字颜色、大小、对齐、透明度（已有基础，需修通数据流）
- [ ] 背景颜色、背景透明度（已有基础）
- [ ] 水平 / 垂直位置、横竖屏 X/Y 偏移（参考截图，尚未实现）
- [ ] 字体选择（参考截图，尚未实现）
- [ ] 粗体 / 斜体开关（参考截图，尚未实现）
- [ ] 显示模式：竖屏 / 横屏 / 两者（参考截图，尚未实现）

### 稳定性原则（来自 TrollSpeed，改造时不可破坏）

- root 权限 `posix_spawn -hud`，且不对 HUD 进程阻塞 `waitpid`
- 保留 `assistivetouchd` 级别 entitlements（`supports\entitlements.plist`）
- 保留 `SBSAccessibilityWindowHostingController` 全局窗口注册
- 保留锁屏隐藏 / 解锁恢复逻辑
- **不要参考 XLsnowState 的进程模型**，只参考其 UI 交互

---

## 补充优化记录（2026-06-16 二次分析）

### P0.5 — 打包流程补全

- [ ] `build-manual.yml` 目前只跑 `make package`，应对齐 `build-release.yml`：补跑 `gen-control.sh`（写入版本号 + 随机 `CFBundleVersion`）
- [ ] 若需要 App Intents 变体：补跑 `build.sh`（`Makefile` 注释写明 Intents 仅 Xcode 编译，theos 包不含 `TrollMemo+AppIntents16_*.tipa`）
- [ ] 对齐 SDK 版本：examples 用 `SDKVERSION = 15.5`，根目录 TrollSpeed 为 `16.5`，长期应统一避免新系统差异
- [ ] 手动 workflow 选对 scheme：纯 TrollStore 设备用 `default`；越狱环境才选 `rootless` / `roothide`

### P1.5 — 配置存储与布局（比 P1 更细）

- [ ] 理清「双轨 + 错轨」存储，统一文字配置写入路径：
  - `USER_DEFAULTS_PATH` plist ← `RootViewController` 的 `saveUserDefaults`
  - `GetStandardUserDefaults()` ← HUD 读偏移、字号等
  - `standardUserDefaults` ← `EditTextSettingsViewController`（当前错轨，需改掉）
- [ ] `editTextSettingsDidSave` 除 `notify_post` 外，须把文字键合并进 `_userDefaults` 并调用 `saveUserDefaults`
- [ ] `UIColor` 存为 `NSData`（`NSKeyedArchiver`）后，确认能正确写入 plist 字典并被 HUD 读出
- [ ] `applyTextSettings` 重复添加宽高约束且从不移除旧约束，多次保存可能导致布局错乱，需改为更新或重建约束
- [ ] 评估是否恢复 `HUDBackdropLabel` 的反色/模糊效果：纯 `UITextView` 在复杂壁纸上可读性可能不如 TrollSpeed

### P2.5 — 仓库与文档

- [ ] `examples\TrollMemo` 在父仓库中为未跟踪目录（`??`），有丢失风险：应 push 到独立远程仓库，或合并进主仓库
- [ ] 父目录仍为 TrollSpeed 命名，与 examples 分叉，长期易改错目录
- [ ] 更新 `README`：目前仍描述「显示网速」，应改为 TrollMemo 目标
- [ ] 基于 TrollSpeed（AGPL），若对外分发 tipa 需注意许可证义务

### P3.5 — 产品范围（对标 XLsnowState 前先定边界）

- [ ] 明确 MVP：仅「桌面固定一行自定义文字」即可，还是完整四 Tab App（开关 / 组件 / 日历 / 指南）
- [ ] 是否支持多组件 / 组件集（XLsnowState 可添加多个文字组件）
- [ ] 文字是静态展示还是定时刷新（XLsnowState 有「更新间隔」滑块，如 1000 秒）
- [ ] 设置入口形态：独立 Tab vs 当前弹窗式「编辑文字」

### P4 — 真机验证清单（Windows 无法本地编译，只能靠 CI + 设备）

- [ ] 巨魔商店能成功安装 tipa
- [ ] 打开 App → 开启 HUD → 桌面出现自定义文字
- [ ] 修改文字并保存 → HUD 立即更新（无需重启 App）
- [ ] 锁屏再解锁 → HUD 仍显示
- [ ] 切后台 / 运行大型 App → 对比 TrollSpeed，确认 HUD 不被杀
- [ ] 卸载 App → HUD 进程随之退出
- [ ] 纯 TrollStore 路径：`posix_spawn -hud`（无 LaunchDaemon）
- [ ] 越狱路径：`ch.better.hudservices` LaunchDaemon 加载正常

### 稳定性补充说明

- `JetsamHelper.h` 中 `BypassJetsamByProcess` 全项目未被调用，稳定性主要靠 entitlements + root spawn，不必照搬 XLsnowState 的保活手段
- README 强调：无 root spawn 时解锁设备会被 SpringBoard 杀 HUD，这是运行时要求而非打包问题


