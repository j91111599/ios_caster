# YKCaster（自研 iOS 被控端）

抓屏 → H.264 Baseline 硬编 → WebSocket 推流到 PC，配合 PC 端 `RemoteProQt.exe` 使用。
协议见 `../RemotePro_src/docs/STREAM_PROTOCOL_V1.md`。

## 组成

| 文件 | 作用 |
|---|---|
| `main.m` | App 入口；连 `ws://PC:10000`，发 hello，收 config 应用参数 |
| `Capture.m` | ReplayKit 抓屏（前台可用） |
| `Encoder.m` | VTCompressionSession；关键帧前置 SPS/PPS；AVCC→Annex-B |
| `WsClient.m` | NSURLSessionWebSocketTask 客户端，文本帧回调 |
| `Tweak.xm` | 后台抓屏钩子骨架（对应原版 mediaserverd 注入） |

## 构建（必须 macOS 或 GitHub Actions）

```bash
export THEOS=~/theos
make THEOS_PACKAGE_SCHEME=rootless package FINALPACKAGE=1
# 产物：packages/com.ykclone.caster_0.1.0_iphoneos-arm64.deb
```

推代码到 GitHub 会自动出包（`.github/workflows/build.yml`）。

## 部署（不用 SSH）

```powershell
cd D:\RemotePro_Workspace\RemotePro_src
python tools\deploy_deb.py --file D:\path\to\com.ykclone.caster_0.1.0_iphoneos-arm64.deb
```

脚本会：起本机 HTTP → 调手机 `/network/download` → `/app/install` → 轮询确认。

## 联调检查

PC 端 `rp_ws.log` 应出现：

```
video peer connected: 192.168.1.43
video text: {"cmd":"hello","role":"device","codec":"h264"}
hello -> config sent
```

设备日志（Console.app 或 `idevicesyslog`）应出现：

```
[YKCaster] apply config fps=30 bitrate=4000000
```

## 已知限制

- 当前 `Capture.m` 用 ReplayKit，只能抓本 App 前台画面
- 要抓任意前台 App：启用 `Tweak.xm`（需确认目标系统里的合成类名与选择器）

## 后台抓屏（依据厂商 tweak 的静态分析）

`Tweak.xm` 已按 `YKSBTweak.dylib` 的真实结构重写：

| 证据 | 说明 |
|---|---|
| `Filter.Bundles = com.apple.springboard` | 注入目标是 SpringBoard |
| `CADisplayLink` / `setDisplayLink:` / `displayDidRefresh:` | 用显示刷新回调驱动抓帧 |
| `_includesStateSnapshotInBridgeEvents` | SpringBoard 内部状态快照 |

流程：`CADisplayLink` → 每帧取 key window 的 `layer renderInContext` → `CVPixelBufferRef(BGRA)`
→ `VTCompressionSession` → WebSocket 10000。

> 注：厂商的 `YKMediaserverdTweak.dylib` 只 hook 了 `AudioUnitRender`——那是**音频**，不是视频。
> 视频抓屏确实在 SpringBoard 注入里。

## 两个构建目标

```bash
make package                       # 同时产出 App + Tweak（同一 deb）
# 只想要 App（无后台抓屏）：
make YKCaster-only
```

| 目标 | 产物 | 作用 |
|---|---|---|
| `YKCaster` (Application) | `YKCaster.app` | 前台界面、ReplayKit 抓屏 |
| `YKScreenHook` (Tweak) | `YKScreenHook.dylib` | 注入 SpringBoard，CADisplayLink 后台抓屏 |

两者共用 `Encoder.m` / `WsClient.m`（各自编译一份，避免跨进程依赖）。

## 权限

`entitlements.plist` 已含 `platform-application`、`com.apple.private.security.no-container`，
rootless 打包后安装在 `/var/jb/Applications` 与 `/var/jb/Library/MobileSubstrate/DynamicLibraries`。
