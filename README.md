# 基于FPGA的实时图像边缘检测系统

赛题四工程，基于易灵思Ti60F225I3、SC431HAI MIPI摄像头与板载DDR3，实现灰度化、中值滤波、Sobel、Canny、彩色边缘叠加、四帧冻结回放，以及几何图形、印刷数字和中文数字手势识别。

当前固件版本为 **V4-ddr1**。本轮已接入Efinity IP Manager生成的官方DDR3控制器，并完成map、interface、pnr和pgm实际构建。工程顶层为[ti60f225_oob.xml](ti60f225_oob.xml)，固件与身份记录位于[firmware](firmware)。

## 赛题要求与完成情况

| 赛题条目 | 本工程实现 | 主要入口 |
|---|---|---|
| 摄像头驱动与图像采集 | SC431HAI MIPI CSI-2，1920×1080，RAW10取高8位；完整帧检查与发布 | `rtl/cam_i2c_ctrl`、`rtl/frame_buffer_V3` |
| 彩色图像转灰度 | `(77R+150G+29B)>>8`，常数移位加法 | `rtl/edge/rgb888_to_gray.v` |
| 3×3 Sobel | 水平/垂直梯度、L1幅值、可配置阈值、双像素滑动窗口 | `rtl/edge/sobel_3x3.v`、`contest_pipeline_2px.v` |
| HDMI显示 | 1920×1080@60Hz配置，灰度/边缘分屏和全屏彩色红边 | `rtl/edge/video_compositor.v`、`rtl/dvi_tx` |
| 源码与约束 | RTL、生成IP、参数ROM、引脚与时序约束、BIT/HEX | 工程根目录、`ip`、`firmware` |
| 3×3中值滤波 | 固定比较交换网络，MED SOBEL先中值后Sobel | `rtl/edge/median9.v` |
| 实时阈值调节 | 32～192，默认128，步长8，按键消抖与帧边界更新 | `rtl/edge/video_controls.v` |
| DDR帧缓存 | 官方DDR3 IP，四个RAW槽位，冻结后前后帧选择 | `ip/ddr3_official`、`ddr_history_manager.v` |
| Canny | 实时局部连接；冻结帧全帧八邻接递归 | `rtl/edge/canny_recursive_frame.v` |
| 彩色边缘叠加 | RGB与边缘同步对齐，红色轮廓叠加 | `rtl/edge/rgb_align_2px.v`、`video_compositor.v` |
| 简易目标识别 | 圆、矩形、一般三角形、印刷数字0～9、中文单手数字1～10 | `shape_engine_2px.v`、`hand_cnn_core.v` |
| 演示视频 | 棋盘格、几何图形、印字纸张与前后帧演示流程已列入技术说明 | 按演示流程录制 |

Ti60的官方DDR3 IP名称为 **DDR3 Soft Controller**。本工程使用Efinity 2026.1.132中的5.16版本，x16、400MHz、BL8、CL6/CWL5；应用AXI为128位100MHz，DDR主控制器为200MHz。

## 操作与前后帧

| 操作 | 功能 |
|---|---|
| 上电默认 | BASIC，左灰度/右白边，阈值128 |
| KEY2短按松开 | BASIC → MED SOBEL → CANNY → DIGITS → HANDS → BASIC |
| KEY0 / KEY1 | 阈值+8 / -8，范围32～192 |
| KEY0＋KEY1 | 分屏 → RGB红边/轮廓 → RGB → 分屏 |
| KEY2长按约600ms | 冻结 / 恢复LIVE |
| 冻结后KEY2＋KEY0 | 选择较旧的缓存帧 |
| 冻结后KEY2＋KEY1 | 选择较新的缓存帧 |

四个RAW槽位基址为`0x00000000`、`0x00400000`、`0x00800000`和`0x00C00000`。冻结后停止接收新帧，已接收帧完成写入后发布。前后选择到达有效缓存边界时保持当前帧。

OSD的`ID`为源帧号，`N`为有效缓存数量，`AGE`为缓存中的新旧顺序，`0`表示最新。当前采用逐帧切换显示。逻辑键对应KEY0 `GPIOL_07`、KEY1 `GPIOL_03`、KEY2 `GPIOR_21`。

HANDS以中央960×1080为识别区域，默认右半屏1:1显示白色手形掩膜。分类采用2×32×32双通道INT8 CNN、固定分差64和两次一致确认。自动阈值关闭，RGB固定280/240/376。

## 构建与固件

安装Efinity 2026.1.132及其驱动，默认工具目录为`E:\Efinity 2026`，主机Python为`C:\Python314\python.exe`。进入工程目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

脚本依次完成综合、接口、布局布线和位流生成，并记录输入SHA256。可使用`-EfinityHome`和`-Python`指定安装位置。

| 资源或时序 | V4-ddr1实际构建 |
|---|---:|
| LUT4 | 29,730 |
| FF | 17,795 |
| RAM10 / DPRAM10 | 240 / 6 |
| 存储块总占用 | 246 / 256 |
| DSP48 / DSP24 | 54 / 3 |
| 最差setup裕量 | +0.341ns |
| 最差hold裕量 | +0.026ns |

[构建清单](firmware/manifest.json)包含镜像SHA256、输入身份和工具版本。当前视频处理采用74.25MHz双像素通路；HDMI配置为1080p60；识别调度约每0.5秒一次。显示刷新、相机新帧和分类调度分别统计。

工程保留正常烧录入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\flash.ps1
```

该入口核对镜像身份、保存覆盖区域备份，随后执行写入与厂商内置检查。本轮烧录在2026年11月4日已执行，载荷981,919字节，覆盖前备份1,048,576字节，厂商检查通过。部署资料保存在本地`artifacts/hardware`。

## 结构与版本

- `rtl`：视频、边缘、识别、帧缓存和AXI适配。
- `ip/ddr3_official`：官方DDR3控制器生成文件、初始化微码与参数。
- `ip/csi_rx_controller`：MIPI CSI-2接收控制器。
- `config`：模型配置、来源身份与DDR修订记录。
- `firmware`：当前BIT、HEX及构建清单。
- `tools`、`build.ps1`、`flash.ps1`：构建、封存、部署入口。

旧`V4`标签保留；新固件以`V4-ddr1`标识。本轮直接继承原视频算法、几何/数字/手势模块和模型ROM，构建过程未调用旧评分套件。现场视频与冷启动记录按各自实际演示归档。

厂商生成IP和参考模块保留原版权声明。DDR IP功能与端口说明参见[Efinix DDR3控制器用户指南](https://www.efinixinc.com/docs/ddr3-controller-core-ug-v2.1.pdf)。
