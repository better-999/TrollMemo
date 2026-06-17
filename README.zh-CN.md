# TrollMemo

**[English → README.md](README.md)**

[![Xcode - Build and Analyze](https://github.com/better-999/TrollMemo/actions/workflows/build-analyse.yml/badge.svg)](https://github.com/better-999/TrollMemo/actions/workflows/build-analyse.yml)
[![Analyse Commands](https://github.com/better-999/TrollMemo/actions/workflows/analyse-commands.yml/badge.svg)](https://github.com/better-999/TrollMemo/actions/workflows/analyse-commands.yml)
[![Build Release](https://github.com/better-999/TrollMemo/actions/workflows/build-release.yml/badge.svg)](https://github.com/better-999/TrollMemo/actions/workflows/build-release.yml)
![Latest Release](https://img.shields.io/github/v/release/better-999/TrollMemo)
![AGPL-3.0 License](https://img.shields.io/github/license/better-999/TrollMemo)

[now-on-havoc]: https://havoc.app/package/TrollMemo

[<img width="150" src="https://docs.havoc.app/img/badges/get_square.svg" />][now-on-havoc]

在 iOS 主屏幕通过常驻 HUD 显示自定义文字浮窗。

已在 opa334 版 TrollStore 支持的各 iOS 版本上测试，预期均可使用。

## 工作原理

[TrollStore](https://github.com/opa334/TrollStore) + [UIDaemon](https://github.com/limneos/UIDaemon) +（TrollSpeed 同款方案）
\=

- 通过 TrollStore 应用以 root 权限拉起 HUD 进程。
- 不要对该进程调用 `waitpid`，让它自行运行。
- HUD 使用 `assistivetouchd` 的 entitlements，在全局窗口中持久显示。
- 自定义文字内容、颜色、大小和对齐方式保存在共享 plist 中，由 HUD 渲染。

## 如何编译

- 使用 [theos](https://github.com/theos/theos) 编译：
  - `FINALPACKAGE=1 make package`
- 产物为 `./packages` 目录下的 `.tipa` 文件。
- 不想用 **theos**？可用 `./build.sh` 通过 Xcode 编译。

## 注意事项

- **必须**以 root 权限拉起进程，否则解锁设备时 HUD 进程会被 SpringBoard 结束。
- 卸载 TrollMemo 后，其 HUD 进程会自动退出。

## 说明

- 如有问题、Bug 或建议，欢迎反馈。
- 觉得有用的话，欢迎点个 Star 🌟，谢谢！

## 截图

![preview](screenshots/preview.jpeg)

## 致谢

本项目基于 [TrollSpeed](https://github.com/Lessica/TrollSpeed)（[@Lessica](https://github.com/Lessica)）改造，并参考了 [TrollStore](https://github.com/opa334/TrollStore)、[UIDaemon](https://github.com/limneos/UIDaemon)、[SPLarkController](https://github.com/ivanvorobei/SPLarkController)、[SnapshotSafeView](https://github.com/Stampoo/SnapshotSafeView)、[KIF](https://github.com/kif-framework/KIF) 等开源项目。

维护：[@better-999](https://github.com/better-999)

- [TrollSpeed](https://github.com/Lessica/TrollSpeed) by [@Lessica](https://github.com/Lessica)
- [KIF](https://github.com/kif-framework/KIF)
- [SPLarkController](https://github.com/ivanvorobei/SPLarkController) by [@ivanvorobei_](https://twitter.com/ivanvorobei_)
- [TrollStore](https://github.com/opa334/TrollStore) by [@opa334dev](https://twitter.com/opa334dev)
- [UIDaemon](https://github.com/limneos/UIDaemon) by [@limneos](https://twitter.com/limneos)
- [NetworkSpeed13](https://github.com/lwlsw/NetworkSpeed13) by [@johnzarodev](https://twitter.com/johnzarodev)
- [SnapshotSafeView](https://github.com/Stampoo/SnapshotSafeView) by [Ilya knyazkov](https://github.com/Stampoo)

## 许可证

Fork 自 [TrollSpeed](https://github.com/Lessica/TrollSpeed)，采用 [GNU Affero General Public License v3](LICENSE)。

### 本地化

添加语言时，在 `Resources` 下新建 `.lproj` 目录即可。

- en/zh-Hans [@better-999](https://github.com/better-999)
- es [@Deci8BelioS](https://github.com/Deci8BelioS)
