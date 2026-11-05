# 基于 FPGA 的实时图像边缘检测系统

赛题四工程，当前版本为 **V4-ddr1**。系统在易灵思 Ti60F225I3 开发板上接收 SC431HAI 摄像头的 MIPI CSI-2 图像，使用板载 DDR3 缓存，并通过 HDMI 输出 1920×1080 @ 60 Hz 画面。以下功能已由项目成员上板验证。

## 功能

| 模式或操作 | 屏幕表现 |
| --- | --- |
| BASIC | 默认左侧灰度画面、右侧 Sobel 白色边缘，显示几何识别结果 |
| MED SOBEL | 对灰度图执行 3×3 中值滤波后提取 Sobel 边缘 |
| CANNY | 实时显示局部连接的 Canny 边缘。冻结时计算所选帧的全帧八邻接递归结果，屏显 `EXACT:READY` 后显示结果 |
| DIGITS | 识别中央区域内的单个印刷数字 0～9 |
| HANDS | 识别中文单手数字手势 1～10，默认在右半屏以 1:1 显示中央 960×1080 区域的白色手形掩膜 |
| 视图切换 | 灰度与白边分屏、彩色红边叠加、彩色画面 |
| 冻结与回放 | DDR3 保留最多四个有效帧。冻结后可向较旧或较新的帧逐帧切换 |

几何识别覆盖圆、矩形与三角形。边缘和印刷数字阈值由按键设置，默认值为 128，范围 32～192，步长 8。自动阈值关闭，RGB 增益系数固定为 280 / 240 / 376。

## 板上操作

接好 SC431HAI 摄像头与 HDMI 显示器，加载本仓库固件后进入 BASIC 模式。

| 操作 | 功能 |
| --- | --- |
| 短按并松开 KEY2 | BASIC → MED SOBEL → CANNY → DIGITS → HANDS → BASIC |
| KEY0 / KEY1 | 分别调高 / 调低边缘或印刷数字阈值。HANDS 使用固定肤色门 |
| KEY0＋KEY1 | 分屏 → 彩色红边叠加 → 彩色画面 → 分屏 |
| 长按 KEY2 约 600 ms | 冻结 / 恢复实时画面 |
| 冻结时按住 KEY2 再按 KEY0 / KEY1 | 分别选择较旧 / 较新的缓存帧 |

屏显 `ID` 为当前源帧号，`N` 为有效缓存帧数，`AGE` 为当前帧在缓存中的相对位置，0 代表最新。逻辑按键 KEY0、KEY1、KEY2 分别对应 `GPIOL_07`、`GPIOL_03`、`GPIOR_21`。

## 固件与构建

- [Efinity 工程入口](ti60f225_oob.xml)使用 Titanium Ti60F225、I3 时序模型。
- [Flash 镜像 HEX](firmware/ti60f225_oob.hex)与 [JTAG 位流 BIT](firmware/ti60f225_oob.bit)对应正式标签 `V4-ddr1`，镜像哈希和构建数据见[固件清单](firmware/manifest.json)。
- [技术文档](docs/technical-design.md)包含视频数据通路、DDR3 帧管理、识别实现、上板操作与构建记录。

Windows 主机安装 Efinity 2026.1.132、编程器驱动和 Python 3 后，在工程根目录执行所需命令。脚本支持 `-EfinityHome` 与 `-Python` 指定安装路径。

```powershell
# 从源码构建，输出位流和构建清单到 .build
powershell -ExecutionPolicy Bypass -File .\build.ps1

# 将 firmware 中的已封存镜像烧录到 Flash
powershell -ExecutionPolicy Bypass -File .\flash.ps1
```

烧录入口先核对工程与镜像身份，再备份覆盖范围、写入 Flash 并执行厂商内置检查。构建和烧录的路径、输出及复现步骤见[技术文档](docs/technical-design.md#构建与部署)。
