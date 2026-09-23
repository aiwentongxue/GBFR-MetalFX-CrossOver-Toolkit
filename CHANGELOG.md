# Changelog

## v1.1.0 - 2026-09-23

- 合并 MetalFX Direct 适配与 GBFRelinkFix v1.1.5。
- 新增宽屏分辨率设置与原配置保留逻辑。
- 自动添加游戏专用 `winmm=native,builtin`。
- 自动设置并读回验证 `dxgi`、`nvapi64`、`nvngx` 和 `winmm` DLL 覆盖。
- 增加宽屏配置的备份、恢复和诊断。
- 修正 GBFRelinkFix.ini 的 CRLF/LF 兼容处理。

## v1.0.0 - 2026-09-23

- 首个公开版本。
- 提供 SDR + MetalFX Temporal + Direct 适配。
- 提供 MetalFX 档位、Metal HUD 开关、备份、恢复和诊断。
- 不包含宽屏或自定义分辨率补丁。
