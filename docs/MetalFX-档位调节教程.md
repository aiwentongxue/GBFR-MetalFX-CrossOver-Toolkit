# 《碧蓝幻想 Relink》MetalFX 档位调节教程

适用环境：Apple Silicon Mac、CrossOver Preview 0821、DXMT、Steam Build ID `24955526`。

## 最简单的方法

1. 完全退出游戏。
2. 双击 `GBFR MetalFX 配置工具.command`。
3. 选择“调整 MetalFX 档位”。
4. 选择游戏目录和 CrossOver 容器，再选择需要的百分比。
5. 重新启动游戏。

## 手动修改

打开游戏目录中的 `ReShade.ini`，找到 `[Luma]`：

```ini
[Luma]
DisplayMode=0
RenderScale=0.50
SRUserType=2
```

只修改 `RenderScale`：

| 档位 | RenderScale | 3456×2234 输出时的近似输入分辨率 | 特点 |
|---|---:|---:|---|
| 性能 | `0.50` | 1728×1117 | 已实机验证，性能最好 |
| 均衡 | `0.60` | 2074×1340 | 清晰度和性能折中 |
| 质量 | `0.65` | 2246×1452 | 更清晰，GPU 压力更高 |
| 超高质量 | `0.75` | 2592×1676 | 接近原生观感 |
| 接近原生 | `0.85` | 2938×1899 | 性能收益较小 |
| 原生输入 | `1.0` | 3456×2234 | 基本没有超分性能收益 |

输入分辨率会根据输出分辨率按比例计算，并可能取整。最终以 Metal HUD 右上角的 `Scaling Input Res` 与 `Scaling Target Res` 为准。

## 必须保留的设置

- `DisplayMode=0`：使用 SDR 交换链，保证当前 DXMT 环境走绿色 `Direct`。
- `SRUserType=2`：选择 DLSS 接口；DXMT 会把它转换为 MetalFX Temporal。
- CrossOver 容器必须使用 DXMT，并启用 `D3DM_ENABLE_METALFX=1`。
- 必须禁用 `nvapi64.dll`，否则可能出现人物和大部分场景不渲染。

## HDR 说明

当前适配版不提供 HDR。Luma 的 scRGB HDR 会把交换链升级为 `R16G16B16A16_FLOAT`；在已测试的 CrossOver Preview 0821 + DXMT 环境中，这会让 Metal HUD 从绿色 `Direct` 变为黄色 `Composited`。这是有意的兼容性取舍，不是 MetalFX 失效。

## 如何确认 MetalFX 真正生效

打开 Metal HUD 后，同时满足以下条件：

- 右上角显示绿色 `Direct`；
- `Scaling` 显示 `Temporal`；
- `Scaling Input Res` 小于 `Scaling Target Res`；
- 50% 档位、3456×2234 输出时，应接近 `1728×1117 → 3456×2234`。

仅看到 `nvngx.dll` 或配置开关不代表 MetalFX 已经执行，必须以 HUD 的运行时数据为准。

