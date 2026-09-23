# GBFR MetalFX Direct 工具

这是面向 Apple Silicon Mac + CrossOver/DXMT 的《碧蓝幻想 Relink》非官方适配工具。

已验证组合：

- CrossOver Preview 0821
- Steam App ID `881020`
- Steam Build ID `24955526`
- 游戏 EXE SHA-256：`4b3ace0fd03df5d3d08c6453e12df2279c6259abf7d2fb3622921fcbea775145`
- 3456×2234 输出、MetalFX 50%：1728×1117 → 3456×2234
- Metal HUD：绿色 `Direct`

## 使用方法

1. 完全退出游戏。
2. 解压整个文件夹，不要只单独复制 `.command` 文件。
3. 双击 `GBFR MetalFX 配置工具.command`。
4. 首次使用选择“安装 / 修复 Direct + MetalFX”。
5. 后续可选择“调整 MetalFX 档位”或“开启 / 关闭 Metal HUD”。

若 macOS 阻止首次启动，可右键该 `.command` 文件并选择“打开”。也可以在终端执行：

```bash
xattr -dr com.apple.quarantine "/你的路径/GBFR-MetalFX-Direct-工具-v1.0.0"
```

## 重要限制

- 当前模式是 `SDR + MetalFX + Direct`，不包含 HDR。
- Luma scRGB HDR 在已测试的 DXMT 环境中会进入 `Composited`。
- 游戏更新后，地址扫描和 shader 哈希可能变化；未知 EXE 版本会显示警告。
- 工具不会修改游戏 EXE，也不会删除备份。
- 免费非商业分享时必须保留本目录中的许可证和项目署名；商业使用 Luma 需要先征得原作者许可。

## 来源与署名

- Luma Framework：Filippo Tarpini 与项目贡献者
- ReShade：Patrick Mours 与项目贡献者
- CrossOver/DXMT MetalFX Direct 兼容适配：基于实机 A/B 测试制作

项目链接：

- https://github.com/Filoppi/Luma-Framework
- https://github.com/crosire/reshade

