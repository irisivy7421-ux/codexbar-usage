# CodexBar

一个只在本机读取 Codex 额度的 macOS 菜单栏工具。它显示 5 小时、每周额度、各自重置时间，以及可用 Full Reset 的数量和最近到期时间。

## 本机运行

1. 打开 Codex 桌面版并确保已登录。
2. 在终端进入本目录，执行 `swift run CodexBar`；或执行 `./scripts/package_app.sh`，再双击 `dist/CodexBar.app`。
3. 顶部菜单栏会出现仪表图标；点击可查看完整信息，数据每分钟自动刷新，也可手动刷新。

它调用本机的 `codex app-server`，不读取密码、Cookie 或 `auth.json`，也不会把额度数据发送到网络。

## 打包过程

`scripts/package_app.sh` 做了四件小事：编译 Swift 源码、搭出 macOS `.app` 的目录结构、写入 App 元信息、用本机 ad-hoc 签名验证。`dist/` 是每次构建重新生成的文件，所以不会提交到 GitHub。

## 这版已经做了什么

- 动态识别约 5 小时与约 7 天的额度窗口，不写死为唯一类型。
- 在菜单栏显示剩余百分比、重置时点和可用 Reset 数量。
- 小于 1 小时时，重置时间会显示为倒计时；否则显示具体时刻。
- 应对缺少某个额度窗口、无 Reset、无 deadline 等情况。

## 一个小知识

`UsageStore` 是数据管家：它负责读取、整理、定时刷新数据。`UsageMenu` 只负责把已经整理好的数据画到界面上。这种分工使以后添加历史图表或提醒时，不需要推翻界面代码。
