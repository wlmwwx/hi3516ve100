## AI 模式对话：hi3516ev100 控制 白光红外光切换

## 您说：hi3516ev100 控制 白光红外光切换

hi3516ev100 控制 白光红外光切换

下午7:30

### AI 模式针对“hi3516ev100 控制 白光红外光切换”的回复

海思 **Hi3516EV100** 控制白光灯与红外光切换（即双光切换 / 警戒模式控制）的核心逻辑，是 ==通过 **GPIO（通用输入输出引脚）** 配合软件中的 **图像ISP参数（如黑白模式与彩色模式切换）** 协同实现的== 。

实现这一功能通常包括以下 3 个关键步骤：

---

1\. 硬件引脚确认（GPIO 划分）

双光摄像机通常需要控制 3 个硬件模块，你需要首先查阅你的硬件原理图（Schematic），确认海思芯片对应的 **GPIO 编号** ：

1. **IRCUT（红外截止滤镜）** ：通常由 **一组（2个）GPIO** 组成 H 桥驱动（例如 GPIO\_A 和 GPIO\_B）。通过给这两个引脚高低电平差（\[1, 0\] 或 \[0, 1\]），控制电机正反转，从而切入或移开滤镜。
	GitHub +1
2. **红外灯控制（IR LED）** ：通常由 1 个 GPIO 控制（或者通过 PWM 调光引脚）。
	GitHub +1
3. **白光灯控制（White LED）** ：通常由 1 个 GPIO 控制，用于夜间彩色补光或报警闪烁。

---

2\. 软件逻辑切换（三种模式）

在软件层面，你需要在主程序中根据环境亮度（通过 **传感器 Sensor 的亮度统计值** 或 **外置光敏电阻 CDS 的 GPIO 输入** ）和 **智能分析结果（如人形检测）** ，来切换这三种工作模式：

百度百科 +1

☀️ 模式 A：白天模式（Day Mode）

- **白光灯** ：关闭（LOW）。
- **红外灯** ：关闭（LOW）。
- **IRCUT滤镜** ：移入（切换至 **白天状态** ，过滤红外光，使画面不偏色）。
- **ISP软件设置** ：调用海思 MPP SDK 将图像模式设为 **彩色（Color）** 。
	GitHub +1

🌙 模式 B：普通夜视模式（IR Night Mode）

- **白光灯** ：关闭（LOW）。
- **红外灯** ：开启（HIGH 或 PWM 调节亮度）。
- **IRCUT滤镜** ：移出（切换至 **夜间状态** ，让红外光通过以感光）。
- **ISP软件设置** ：调用海思 MPP SDK 将图像模式设为 **黑白（Mono/Mono-Chrome）** ，否则画面会严重偏色（变紫/变红）。
	GitHub +2

🚨 模式 C：白光警戒模式（White Light Mode）

当触发智能警戒（如人脸识别、人形检测）时，从红外模式切换为白光：

一牛网 +1

1. **红外灯** ：立刻关闭（LOW）。
2. **白光灯** ：立刻开启（HIGH）。
3. **IRCUT滤镜** ：切回 **白天状态** （移入滤镜，过滤红外干扰）。
4. **ISP软件设置** ：延迟数百毫秒（等待白光灯稳定、环境变亮后），调用 SDK 将图像模式切回 **彩色（Color）** 。

---

3\. 海思底层控制代码参考

运行期直接测试（用 Linux 命令或 `himm` 工具）

在板端命令行中，你可以通过修改 Linux 标准 GPIO 节点或利用海思的寄存器工具 `himm` 来直接测试硬件是否能切换：

CSDN博客

```
# 以控制某个GPIO（假设为GPIO 3）开启白光灯为例
echo 3 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio3/direction
echo 1 > /sys/class/gpio/gpio3/value  # 点亮白光灯
echo 0 > /sys/class/gpio/gpio3/value  # 关闭白光灯
```

请谨慎使用此类代码。

C语言 SDK 开发（调用海思 ISP 切换黑白/彩色）

在代码中，除了利用 `ioctl` 或设备树控制 GPIO 引脚输出外，必须同时调用海思的 MPI 接口同步切换图像色彩：

CSDN博客

```
// 切换为彩色模式（白光灯开启后使用）
HI_MPI_ISP_SetMonoAttr(ViPipe, &stMonoAttr); 
// 具体的结构体参数需要将 stMonoAttr.bEnable 设为 HI_FALSE (不启用单色模式，即彩色)

// 切换为黑白模式（红外灯开启后使用）
stMonoAttr.bEnable = HI_TRUE; // 启用单色（黑白）
HI_MPI_ISP_SetMonoAttr(ViPipe, &stMonoAttr);
```

请谨慎使用此类代码。

💡 调试避坑指南

1. **IRCUT 切换死循环（俗称“闪烁屏”）** ：当从红外切到白光，或者白天切到黑夜时，画面亮度会发生剧烈变化。如果光敏检测的阈值设计得太近，会导致刚切过去、亮度又触发了切回来的条件，从而导致灯光和滤镜疯狂拍打切换。软件上一定要做 **迟滞（Hysteresis）处理** 和 **3~5秒的防抖过滤延迟** 。
2. **画面发紫** ：如果切换到红外模式后，画面是紫色的彩色画面，说明 **IRCUT 没有成功移出** ；或者说明 **GPIO 组的方向引脚反了** （把白天和黑夜的电平写反了）。
	GitHub +2

如果您需要具体的 **GPIO 引脚计算公式** 或是海思 **ISP 图像模式切换的具体结构体代码** ，可以提供您的硬件引脚编号（例如 GPIO3\_1），我为您进一步编写出对应的控制逻辑。

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

- CSDN博客
	海思Hi3516EV300开发板防雷防静电图 - CSDN博客
	Hi3516EV300 IRCUT和CDS(红外灯)设置. 一、基本概念1、IPC网络摄像机一般对图像要求较高，要求白天...
	![](data:image/jpeg;base64,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)
- GitHub
	Majestic Night/Day: GPIO Hi/Low inverted ("IRcut filter polarity is...
	Description LukeO1982 opened on Feb 8, 2024 Dear community,...
	![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFIAAABSCAMAAADw8nOpAAAAkFBMVEX///9VVVXf398/Pz8AAAD8/Pz4+Pjx8fHk5eXu7u/LzM3Q0dLb3N3Y2dnn6Ojh4uLCw8VcYGU6QEamqKqcnqC5urxucXVna2+WmJp3en5ITVKxsrS+w8iPkZQiKjNiZmpUWF0AABOChIgaJC0wNz4THigADx0AAAmpr7UPGCGfpqyMlJwqLzXcxO7QsObj1uxnaLWPAAAFnklEQVRYhe1YDZPbJhDdqAIECIQE6ItDkiXZd07d9v//uy52mlyvyWUmuTSdjt/ItozZJxZ2H4sB7rjjjv8WCGEUGAFCyVvQMca0lkZ4KZg1mmnGGaOMU6bpN1K6YEypggxAlChDEYIRTngrpDPfSCnLsqzKCipjuGKGSKUyaYyQTOhvpLzjXwZ78fVr4Zs9APFPnoB6eqJAn55S8GRTC+DP4dqjzJ8tvvPwGF4lJOL9AwgFDyUNoB/giYHAGM+OWwHLKQBVDFigwBUOLauAnRwP2bX5i5SJhxLmeSkB3sP7wqchZXsd1aUOxXGZquzM/DgvbKjH6LZmmbxuxumVTEBKoA9PGPSJ8lfJ3qdRbqapbR20E01fHHQTzdE2Ed3ZAhz9OhNvv0RIE2WBEykLkSgdgKiQ8lwMExtDaHzjikO1x2CVXMcRNo/XMAB7JbmQUj4wX5EnLiSI2yjLvFIR9rCOfhqqAxs6P8rFxTPsS3UK5hyn+GVKioNSDwXGxgPOJtJzfOeOEwpBsT7I3jxyElYBVew1qLW0JYgYvkcI6aV9Ex19BvLzJcnw4abeN8VlOJGFNM7Zfw7NRItde+cwARxGe4g+NQuMpqKnvk+WHpsG1iVKq2uXfs8xOKNeL8OeqxeM3WG4bBTyuj207GxIM62nBdv7Btc054kyFkMHsLKWqGWs6eyGWq/HsYIWVkzweQE7dmwN0FuL3cVjBhA05AJMXl2E3RgUObrmRoy5x0TJWhjQctU5OXs/woxxN5S5JSbAis9yTdaqbvA75NKjTrid2hVdzXtTN3wSA46QTOi0O+b56cj7BYz/SNnO9Qy1hVhDnkFLr5Rrw5exaSE32zWEwsZE2FbIx7Et6CQi+ksO6VkjY+LA+xpwVT5SrpYDzmWi9HTAxkXYg3U7dDOsewSJ/unToNxjhOQrsE2UhyiHE7s5jnPZ12zFpVkErgUajvWkhgBugPUSMYXiOI4OqnFxR1C4ThE7g1wuq4swiUSJlmbZ5zKtLLqkGmYHf7NEcSP85M3ZpDv08FpwEEJuH0BCM15vEmjSwtst+fAdPvyYjD9YXhv90Povxa2w31p0/FB8UojsmkCBVLQArkEXRfGZrrKoNCuf271ELT7ejhjg4ATG5UYxGOpp37pnPWmbtNCeQtebCewn+fREFCjpIDExJBcq7xkxngH3xYwpSpDksdoT5dIzn0tQuDclk0wcLYNsaaUvTaPrOgMVsF3DPrQtNL0d41TN4xK3RtVtu/Cx6RpMDZNkAFa4UlJ/5u405xqTphviNCqwezMfezOafXehiUfkAHEUe3VUzdBfQotRnsvq0McT5gqMSGnlzZnk+HY8rPDoQTB82LCSLQlL20PnTAO4G42tayymjzjB2S1st6XRM3LkosqFMuKoSaIU4SNlGmWOMQy45VqoV7qlx3UR5r8oXWaK1qGqwJo7sM16UknfLk3Z1e1Fj3u3J7mrb5TrghaoPJk91DkK1twMpGlwoeeIzzI79CcbLvFRdihIAq+0JeKS4NQC1gggMI2pYVWKGX9LgkqBKrA0wU7YkZhCl6CxK2C1qwousUlChQ3qRaB9DuKtt7I7/nfQL6vZ74+ZYEBqWal0FShFUoivG70Oj/tSqXwpjZIypA//vTsDR2nEwy2leFGeXj+/Trvjjh+A324F2DXT2bUwI3/P8g+5hHvMsx+wpIEKCnx95mz+O9bvVJbOSzww9K0b4hAGPCpnipeZ1KX2UGRlSQQtC8MV1yUTnEnDqBJSVdL/M9n+wA1VrnHthnk1IZp3K9bEIKXH84bRzgssBTDxmS+tNFIKY420RPqCmkJgMeNfHjyufvGKa8xzTkvgVDOe4e7KFCOMEsx8DvhGSPoHjScVQC2QQHlFNOGkwC7fM+133PF5ZG8O+OXNAe/eHD+A8k9rk24TkhxQPAAAAABJRU5ErkJggg==)
- 百度百科
	杭州雄迈信息技术有限公司 - 百度百科
	AI智能双光警戒摄像机：支持人形检测、真人语音告警、声光报警、报警信息手机推送、报警录像云端存储等AI智能功能。基于人形...
	![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFEAAABSCAMAAAAbxciqAAAAolBMVEX8/v/////ILB4AAADmx8LJOCzEAAD2+PnmvbeytLTYkI3FDADHHwx/goPAAACHiYpbYmPXiYf17uvp6+sAAAkADRUkMjXO0NHfo5v05N/z6OXHycqRlJTHGwXQbF/NV0zWkIPKTUARJytrcXK6vsDb3d12enpASUrQZloAFhwAIibr1M9HUFKcnJ0rOTxYWlramZThsq3Sc2nSe3Olp6jZm46Vp/IZAAAB8UlEQVRYhe2U65KiMBSEc8IlIkQQdFEBL0OAccbrrvv+r7YdwFqnamT2707lq1TSOVJdfUKQMYPBYDAYDAaD4btDoJ365V6jdm01u1f/yTCejsdjscA0HS2hpytiejsdwciTghKZiTDV1rlH4s6QIy+CYu0HgbuhLZaCx8ud3tqMxEtJdLSSxFI66ExWdRNJTT4Ucuf6vh6vjAVYfZfrrT8h8qJ9KVVzCuVbKTOiKiH2I6T7kTzl3e4QTNgPvDMmmjNjan4Q1UwxloTnI4nTIQ/D8FwPWNKVO47D1+jqolVPYBNlFoJFbwfqu0Y+0WWMoiHHacB5sMFRE9ei4P4OwoVD1HhzNXtpuw5h3jviySFH2rraaAW5hHJoOxldfR78xLFZXnPOm/JjRvmVY2vIC5waXQIe/CK2og3nvr47XdvylKr9MU26jPt82LFLCIMrDBysNorxBKK9cIcTaUfl7XNVwVHSzarglTbnJ470u20ZY0ts6UPHKC4KNK1/RcTbjSS6nqFrSuflLdOCbl72uSMS4vptFi4moguWtW7JgRhpUVq1ZVG9D2srwpuJLFJ12lF9HjG+jkAc65kxG/NSl3VVtBkzUXlJqpJEYAgvJUq8DvXsvXS3/+/fw0OxFw8fSP/o19+MwWAwGAwGg8Hwf/MHr3sj9kSi85QAAAAASUVORK5CYII=)
- GitHub
	wiki/en/gpio-settings.md at master · OpenIPC/wiki · GitHub
	Board GPIO Settings Lists: Mappings provided for Anjoy/Anjvi...
- GitHub
	Different GPIO pins open and close the same IR shutter? · Issue #1720
	openipc-ai commented openipc-ai 4h ago Collaborator More act...
- GitHub
	OpenIPCwiki/en/gpio-settings.md at master
	Table\_title: CamHi / Xin boards Table\_content: | Processor |
- GitHub
	Finding the White and IR LED gpio pins to control via gio #135
	Activity \* OptimusGREEN commented OptimusGREEN on Dec 19, 20...
	![](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQkPJsNZNLDsoa4-8QPSyj4MRUHKoBYCgneLkfv_bI2a4UwSMzY53lBGjSEjJRM0cClbEr-fQ4mYf2NxR8t_gKDRi1a)
- 一牛网
	亿智SV830C 双目(RGB+NIR)人脸识别/方案定制 - 一牛网论坛
	（1）高清液晶屏：配备一块高分辨率彩色LED屏，用于人脸识别、状态提示和身份验证结果反馈。屏幕支持中英文语言界面，可根据...
	![](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTQQsUFjU8AhqOF_93gsXf-dj6w4dvEwI3MxZb0-PJ89WaB_u3h7paBf3kx7Z4yv8eZoMeXWJEZy5HZPI7IBJED4Po)
- CSDN博客
	关于IRCUT切换的操作步骤原创 - CSDN博客
	最新发布 保姆级教程：用海思Hi3516EV200的himm命令手动切换IRCUT滤镜（附完整Shell脚本）. 本文提...
	![](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSJDGfmSmm7LI9IE-prlfBOniH4ocYog9JqdbF8dC1RnauYoblTV8e3blsc8NIs4t0jvvdEfudOxkzQOdGzWJ-tIy6odvUL6ACafOMm)
- 迅思维科技
	Hi3516EV100 核心板简要说明
	Hi3516EV100 核心板简要说明. 一，芯片参数. 1. 处理器内核. ＊ ARM926@ 800MHz......

全部显示

## 您说：我没有电路图,如何确认是那个引脚

我没有电路图,如何确认是那个引脚

下午7:32

### AI 模式针对“我没有电路图,如何确认是那个引脚”的回复

在没有电路图的情况下，我们可以通过 **寻找核心驱动芯片** 、 **测量关键测试点（TP点）** 以及 **在内核中“扫盲试探”** 这三种方法，顺藤摸瓜找到控制红外灯、白光灯和 IRCUT 的 GPIO 引脚。

以下是具体的排查实操步骤：

---

第一步：观察板卡硬件，逆向寻找“驱动源”

海思 Hi3516EV100 芯片本身的引脚驱动电流非常小（通常只有几毫安）， **绝不可能** 直接连到红外灯或白光灯。它的 GPIO 必然连着一个 **放大/驱动芯片** 。

1. **寻找 IRCUT 驱动芯片（最容易找）** ：
	- 在板子上寻找靠近镜头 IRCUT 软排线插座的一个 **8引脚（或6引脚）的小芯片** 。
		- 常见型号有： `F6208` 、 `DRV8837` 、 `B6228` 、 `MX6208` 。
		- 找到这个芯片后，去网上搜它的 DataSheet（引脚图）。这类芯片一般有 2 个输入端（ `INA` / `INB` ）。这两个输入端连接的必然就是海思的 GPIO。
2. **寻找白光灯/红外灯的 MOS 管** ：
	- 灯板上的大电流通常由三极管或 **MOS管（通常是3个引脚或5、6个引脚的黑色微型元件）** 控制。
		- 顺着红外灯、白光灯的电源线座子往回摸，一定会摸到这两个 MOS 管。MOS 管的基极（G极）连接的就是海思的控制 GPIO。

---

第二步：万用表蜂鸣档“盲测法”（最快、最准）

如果你能认出上述的驱动芯片或 MOS 管，直接拿出万用表，调到 **蜂鸣器档（断电测量）** ：

1. 一根表笔按住 IRCUT 驱动芯片的 **输入脚（如 INA）** 。
2. 另一根表笔在海思芯片周围的测试点（TP点）或排阻上挨个滑动。
3. **听到“滴”的一声** ，说明这个测试点直接通向该引脚。
4. 记录下测试点的名字（如果 PCB 上有丝印，如 TP12）。此时我们不需要知道海思的具体引脚名，可以通过后面的“第三步”软件手段来验证它。

---

第三步：Linux 命令行“穷举扫盲”（软件排查法）

海思的 GPIO 数量是有限的。我们可以通过在板子的 Linux 终端里，直接用命令强制让所有可能的 GPIO 输出高低电平，同时用万用表测电压（或直接看灯亮不亮）。

1\. 计算海思的 GPIO 编号

海思的 GPIO 采用分组管理，公式为：  
$GPIO编号=组号×8+组内管脚号GPIO编号 equals 组号 cross 8 plus 组内管脚号$  
*例如：GPIO3\_1 = 3 \* 8 + 1 = 25*

Hi3516EV100 的 GPIO 组数通常在 **GPIO0 ~ GPIO8** 之间。你只需要尝试这几十个排列组合。

2\. 批量导出并试探（推荐脚本）

你可以通过串口进入板子终端，直接粘贴运行以下命令。这里以遍历 `GPIO2_0` 到 `GPIO5_7` （编号 16 ~ 47，这是摄像头控制引脚最集中的区域）为例：

```
# 1. 批量导出 16 到 47 号 GPIO
for i in $(seq 16 47); do 
    echo $i > /sys/class/gpio/export 2>/dev/null
    echo out > /sys/class/gpio/gpio$i/direction 2>/dev/null
done

# 2. 全亮测试：将这些引脚全部拉高（看白光灯/红外灯是否亮起，或听见IRCUT啪嗒一声）
for i in $(seq 16 47); do 
    echo 1 > /sys/class/gpio/gpio$i/value
done

# 3. 全灭测试：如果刚才灯亮了，全部拉低让它灭掉
for i in $(seq 16 47); do 
    echo 0 > /sys/class/gpio/gpio$i/value
done
```

请谨慎使用此类代码。

3\. 逐个排查精确定位

如果执行上述“全亮测试”时，你的白光灯亮了，说明控制引脚就在 16~47 之间。接下来采用 **二分法** 或者 **逐个拉高** 来锁定：

```
# 比如你想测试 25 号引脚 (GPIO3_1)
echo 1 > /sys/class/gpio/gpio25/value   # 如果此时白光灯突然亮了，那 25 号就是白光灯！
echo 0 > /sys/class/gpio/gpio25/value   # 关灯
```

请谨慎使用此类代码。

> ⚠️ **重要提示（复用问题）** ：如果用上面的 `echo` 方式提示 `Device or resource busy` （设备忙），或者拉高了灯也没反应，说明这个引脚在海思芯片内部被 **复用（Mux）** 成了其他功能（例如 SPI、I2C 或普通输入）。  
> 你需要使用海思的 `himm` 工具去查看和修改管脚复用寄存器（管脚控制寄存器配置为 GPIO 模式），Hi3516EV100 的复用寄存器基地址通常是 `0x14010000` 附近。

---

第四步：从现有固件中“偷”信息（高级技巧）

如果板子原本是有正常工作的原厂固件（或者能开机的旧程序），你可以直接去系统里看它用了哪个引脚：

1. **查看当前已被系统申请的 GPIO** ：  
	在串口终端输入：
	```
	cat /sys/kernel/debug/gpio
	```
	请谨慎使用此类代码。
	它会打印出一张表，显示当前有哪些 GPIO 正在被使用（比如被标记为 `ircut_p` 、 `ircut_n` 、 `led_white` 、 `led_ir` 或者是被某些自定义驱动占用了）。如果有这些标签，后面的数字就是我们要找的 GPIO 编号。

你可以先在板子上执行一下 `cat /sys/kernel/debug/gpio` 或者尝试一下上述的 **批量拉高脚本** 。  
如果你遇到了 **"Device or resource busy"** 报错，或者想知道具体某个引脚（比如检测到了测试点）对应的 **海思复用寄存器地址** ，可以随时告诉我，我帮你查询具体的寄存器映射表。

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

全部显示

root@hi3516cv300-sc2235p:~# cat /sys/kernel/debug/gpio GPIOs 0-7, amba/12140000.gpio, 12140000.gpio: gpio-0 (sysfs ) out lo gpio-1 (sysfs ) out lo GPIOs 8-15, amba/12141000.gpio, 12141000.gpio: GPIOs 16-23, amba/12142000.gpio, 12142000.gpio: GPIOs 24-31, amba/12143000.gpio, 12143000.gpio: GPIOs 32-39, amba/12144000.gpio, 12144000.gpio: GPIOs 40-47, amba/12145000.gpio, 12145000.gpio: GPIOs 48-55, amba/12146000.gpio, 12146000.gpio: GPIOs 56-63, amba/12147000.gpio, 12147000.gpio: GPIOs 64-71, amba/12148000.gpio, 12148000.gpio:

### AI 模式针对“root@hi3516cv300-sc2235p:~# cat /sys/kernel/debug/gpio GPIOs 0-7, amba/12140000.gpio, 12140000.gpio: gpio-0 (sysfs ) out lo gpio-1 (sysfs ) out lo GPIOs 8-15, amba/12141000.gpio, 12141000.gpio: GPIOs 16-23, amba/12142000.gpio, 12142000.gpio: GPIOs 24-31, amba/12143000.gpio, 12143000.gpio: GPIOs 32-39, amba/12144000.gpio, 12144000.gpio: GPIOs 40-47, amba/12145000.gpio, 12145000.gpio: GPIOs 48-55, amba/12146000.gpio, 12146000.gpio: GPIOs 56-63, amba/12147000.gpio, 12147000.gpio: GPIOs 64-71, amba/12148000.gpio, 12148000.gpio:”的回复

从你发过来的 `cat /sys/kernel/debug/gpio` 打印信息中，可以发现两个非常关键的细节：

1. **实际芯片为 Hi3516CV300** ：你的系统终端提示符显示为 `root@hi3516cv300-...`，说明你的板子实际芯片是 **Hi3516CV300** （或 Hi3516EV100 的同系列变种，寄存器基地址与 300 相同，为 `0x1214xxxx` ），而非最开始提到的 EV100（EV100 的 GPIO 基地址通常是 `0x120Bxxxx` ）。
2. **内核已经导出了 gpio-0 和 gpio-1** ：在 `GPIOs 0-7` 这一组中， `gpio-0` 和 `gpio-1` 已经被通过 `sysfs` 导出了，且当前电平为低电平（ `lo` ）。这通常意味着之前有人或某个开机脚本为了控制某些硬件（极大概率就是 IRCUT 的正反转引脚，或者灯的开关），已经提前执行过 `export` 了。

由于目前除了 `0` 和 `1` 之外，其他引脚都是空的（没有被系统或驱动占用），我们现在可以直接利用这台机器的内核节点进行 **在线高低电平测试** 。

请依次在板子上执行以下步骤进行排查：

---

第一步：优先验证已被导出的 `gpio-0` 和 `gpio-1`

这两个引脚被挂载在 `GPIO0` 组（即 `GPIO0_0` 和 `GPIO0_1` ），极大概率就是控制 **IRCUT** 或 **红外灯/白光灯** 的。

请直接在终端输入以下命令，并 **用眼睛观察镜头（听声音）或用万用表测量灯板电压** ：

```
# ----- 测试 gpio-0 -----
echo 1 > /sys/class/gpio/gpio0/value   # 拉高。观察：白光灯或红外灯是否亮起？或者镜头有无“啪嗒”一声？
echo 0 > /sys/class/gpio/gpio0/value   # 拉低。

# ----- 测试 gpio-1 -----
echo 1 > /sys/class/gpio/gpio1/value   # 拉高。观察：是否有灯亮或IRCUT切换？
echo 0 > /sys/class/gpio/gpio1/value   # 拉低。

# ----- 联动测试（如果它们是 IRCUT 的正反驱动引脚） -----
echo 1 > /sys/class/gpio/gpio0/value
echo 0 > /sys/class/gpio/gpio1/value   # 组合 A
sleep 1
echo 0 > /sys/class/gpio/gpio0/value
echo 1 > /sys/class/gpio/gpio1/value   # 组合 B（看滤镜是否啪嗒切回）
echo 0 > /sys/class/gpio/gpio0/value
echo 0 > /sys/class/gpio/gpio1/value   # 恢复关闭
```

请谨慎使用此类代码。

---

第二步：如果前两个引脚没反应，批量轰炸其余引脚

如果上述两个引脚没有让任何灯亮起，说明控制灯的引脚在其他组。Hi3516CV300 共有 9 组 GPIO（GPIO0 ~ GPIO8），总编号为 **0 到 71** 。我们可以编写一个安全的自动化脚本，将所有未被占用的引脚 **依次拉高 2 秒再拉低** 。

请将以下脚本整体复制，直接粘贴到你的板子串口终端中运行：

```
for i in $(seq 2 71); do
    # 尝试导出引脚
    if [ ! -d "/sys/class/gpio/gpio$i" ]; then
        echo $i > /sys/class/gpio/export 2>/dev/null
    fi
    
    # 设置为输出方向
    echo out > /sys/class/gpio/gpio$i/direction 2>/dev/null
    
    # 拉高引脚
    echo "[测试中] 正在拉高 GPIO 编号: $i ..."
    echo 1 > /sys/class/gpio/gpio$i/value 2>/dev/null
    
    # 停顿 2 秒，期间盯紧你的白光灯、红外灯、以及听镜头声音
    sleep 2
    
    # 拉低恢复
    echo 0 > /sys/class/gpio/gpio$i/value 2>/dev/null
done
```

请谨慎使用此类代码。

如何通过该脚本锁定引脚？

在脚本运行过程中，终端会一行一行打印 `正在拉高 GPIO 编号: X ...`。

- 当打印到某一个数字（比如 `正在拉高 GPIO 编号: 42 ...`）时， **白光灯突然亮了** ，那么 **42** 就是白光灯的控制引脚。
- 当运行到某数字时，听见镜头\*\*“啪嗒”\*\*响了一声，记录下这个数字，它就是 IRCUT 的其中一个控制引脚。

---

第三步：计算对应的海思官方引脚名

当你通过上述测试找到了引发硬件变化的数字编号后，可以通过以下公式反推它是海思的哪一组哪个引脚，方便你后续写 C 语言代码或配置复用：

- **组号** = 编号 / 8 （向下取整）
- **组内管脚号** = 编号 % 8 （取余数）

> **举个例子** ：如果测试发现编号 `25` 能让白光灯亮。  
> 25 / 8 = 3，25 % 8 = 1。那么它对应的海思官方引脚名就是 **GPIO3\_1** 。

你可以直接把上面的 **批量排查脚本** 粘贴到板子上运行一下。请告诉我：

1. 运行第一步时， `gpio-0` 和 `gpio-1` 产生动作了吗？
2. 运行第二步脚本时，白光灯和红外灯分别在 **哪一个数字编号** 亮起？

AI 可能会出错，请注意核查 AI 回答

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

全部显示

操作pin0，pin1听见摄像头里有响声，已知pin

### AI 模式针对“操作pin0，pin1听见摄像头里有响声，已知pin”的回复

既然操作 **pin0** 和 **pin1** 听见了摄像头里的“啪嗒”响声，这可以 ==**100% 确认：pin0 和 pin1 就是控制 IRCUT（红外截止滤镜）的正反转引脚**== 。

由于控制 IRCUT 需要两个引脚产生电平差来驱动微型电机，它们的具体对应关系和操作逻辑如下：

1\. IRCUT 的控制规律

- **白天模式（切换为彩色）** ：
	```
	echo 1 > /sys/class/gpio/gpio0/value
	echo 0 > /sys/class/gpio/gpio1/value
	```
	请谨慎使用此类代码。
	*(注：让电机正转，滤镜移入。完成切换后，为了省电和保护电机，建议在 500ms 后将两引脚全部拉低： `echo 0 > ...`)*
- **黑夜模式（切换为黑白夜视）** ：
	```
	echo 0 > /sys/class/gpio/gpio0/value
	echo 1 > /sys/class/gpio/gpio1/value
	```
	请谨慎使用此类代码。
	*(注：让电机反转，滤镜移开。完成切换后，同样在 500ms 后全部拉低复位。)*

如果发现色彩反了（比如大白天画面变紫，黑夜画面反而正常），只需把上面代码里 pin0 和 pin1 的 `1` 和 `0` 对调即可。

---

2\. 接下来如何寻找“白光灯”和“红外灯”引脚？

既然 pin0 和 pin1 已经被滤镜占用了，那么白光灯和红外灯一定在剩下的引脚里。请将此前为您编写的 **精简版批量扫盲脚本** 直接复制到终端运行，这次我们跳过 0 和 1，直接从 **pin2 扫描到 pin71** ：

```
for i in $(seq 2 71); do
    # 尝试导出引脚
    if [ ! -d "/sys/class/gpio/gpio$i" ]; then
        echo $i > /sys/class/gpio/export 2>/dev/null
    fi
    
    # 设置为输出方向
    echo out > /sys/class/gpio/gpio$i/direction 2>/dev/null
    
    # 拉高引脚
    echo "[正在试探] 正在拉高 GPIO 编号: $i ..."
    echo 1 > /sys/class/gpio/gpio$i/value 2>/dev/null
    
    # 停顿 2 秒，期间盯紧你的白光灯、红外灯是否亮起
    sleep 2
    
    # 拉低恢复
    echo 0 > /sys/class/gpio/gpio$i/value 2>/dev/null
done
```

请谨慎使用此类代码。

请观察并告诉我：  
当终端打印到 **哪两个数字** 时， **白光灯** 和 **红外灯** 分别亮了起来？  
（如果扫描完所有的灯都没亮，请告诉我，我们可能需要使用 `himm` 命令去解锁管脚的通用 GPIO 复用功能）。

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

全部显示

刚测试发现，测试15，16s时网络断链了，修改下脚本，每次只测试1个pin，从命令行参数获得

### AI 模式针对“刚测试发现，测试15，16s时网络断链了，修改下脚本，每次只测试1个pin，从命令行参数获得”的回复

网络断开是因为某些 GPIO 引脚被复用为了 **网络芯片（PHY）的复位、时钟或数据引脚** 。当脚本强制把它修改为普通 GPIO 输出并拉低时，网络便中断了。

为了安全排查，这里为您提供修改后的单引脚测试脚本。您可以直接在命令行后传入要测试的 **Pin 编号** 。

1\. 单个 Pin 测试脚本

请在板子的终端中直接执行以下命令，或者将其保存为 `test_pin.sh` ：

```
# 定义测试函数（直接粘贴到命令行即可）
test_gpio() {
    local pin=$1
    if [ -z "$pin" ]; then
        echo "请输入要测试的 GPIO 编号，例如: test_gpio 2"
        return 1
    fi

    echo "=== 开始测试 GPIO: $pin ==="
    
    # 1. 导出引脚
    if [ ! -d "/sys/class/gpio/gpio$pin" ]; then
        echo $pin > /sys/class/gpio/export 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "错误: 无法导出 GPIO $pin，可能已被系统锁定或复用为关键功能。"
            return 1
        fi
    fi
    
    # 2. 设置为输出
    echo out > /sys/class/gpio/gpio$pin/direction 2>/dev/null
    
    # 3. 拉高
    echo "拉高 GPIO $pin (灯是否亮起?)..."
    echo 1 > /sys/class/gpio/gpio$pin/value
    
    # 4. 等待用户确认（按任意键继续并关闭）
    read -p "请观察灯板。确认后请按 [Enter] 回车键关闭该引脚..." CONFIRM
    
    # 5. 拉低恢复
    echo 0 > /sys/class/gpio/gpio$pin/value
    echo "=== GPIO: $pin 测试结束 ==="
}
```

请谨慎使用此类代码。

2\. 使用方法

粘贴上述代码后，您可以通过输入 `test_gpio [引脚号]` 来逐个安全测试。例如：

```
test_gpio 2   # 测试 pin2
test_gpio 3   # 测试 pin3
test_gpio 12  # 测试 pin12
```

请谨慎使用此类代码。

*每一次测试，它都会保持拉高状态，直到您在终端 **按下回车键** 才会关闭并拉低。这样您有充足的时间观察是哪个灯亮。*

---

💡 避坑跳过提示（保护网络）

既然 **15 和 16** 会导致断网，请在接下来的手动试探中 **绝对不要** 去碰以下范围的引脚（海思网络 PHY 芯片常用的复用管脚）：

- **跳过 12 ~ 23** （这对应海思的 GPIO1\_4 ~ GPIO2\_7，是 RMII 网络接口和 PHY 芯片高频高危区）。

您可以优先尝试测试 **pin2 ~ pin11** 以及 **pin24 ~ pin63** 这些相对安全的区间。

请您使用 `test_gpio` 命令针对其他区间（如 **pin2, pin3, pin4, pin5** 或 **pin24** 之后）进行手动抽测。  
是否有在哪个编号下成功看到 **白光灯** 或 **红外灯** 点亮？

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

全部显示

测试发现GPIO 54 控制白光LED，HIGH 关闭，LOW 打开，红外led由电源控制板上的电路结合cds控制，白天都关闭，晚上红外打开，检测物体经过就打开白光，摄像头就变成彩色了，这是原来固件的功能，刷入openipc就没这个功能了

### AI 模式针对“测试发现GPIO 54 控制白光LED，HIGH 关闭，LOW 打开，红外led由电源控制板上的电路结合cds控制，白天都关闭，晚上红外打开，检测物体经过就打开白光，摄像头就变成彩色了，这是原来固件的功能，刷入openipc就没这个功能了”的回复

这是一个非常经典的双光摄像机在开源固件（如 **OpenIPC** ）上的配置与调优问题。

首先，恭喜你成功锁定了关键的硬件逻辑：

1. **白光灯 (White LED)** ：由 **GPIO 54** 控制。它的控制电平是 **反向的** （ **LOW/0 为开启** ， **HIGH/1 为关闭** ）。
2. **红外灯与光敏 (IR & CDS)** ：由灯板上的硬件电路自动联动控制（晚上自动开红外，白天自动关）。
3. **IRCUT (滤镜)** ：由 **GPIO 0** 和 **GPIO 1** 控制。

为什么刷入 OpenIPC 后这个功能没有了？

OpenIPC 默认是一个纯净的嵌入式 Linux 系统加流媒体服务（如 Majestic），它 **默认不会主动去把“人形检测/运动检测”与“GPIO 54（白光灯）”以及“IRCUT图像彩色/黑白切换”联动起来** 。这些逻辑需要我们在 OpenIPC 中通过配置文件或脚本来重新激活。

为了在 OpenIPC 上复现你原厂固件的“智能双光警戒”功能，你需要按照以下步骤配置：

---

第一步：在 Majestic 中配置 IRCUT 和基本夜视

OpenIPC 的核心流媒体组件是 `Majestic` 。我们需要告诉它，如何控制你的滤镜（GPIO 0/1）以及环境变暗时如何处理画面。

1. 网页登录你的 OpenIPC 后台，或者通过 SSH 修改配置文件 `/etc/majestic.yaml` 。
2. 找到或添加 `nightMode` （夜视模式）的相关配置：

```
nightMode:
  enabled: true
  # 当硬件红外灯开启、光敏电阻检测到天黑时，Majestic 会通过算法或传感器触发夜视
  # 配置 IRCUT 引脚（GPIO 0 和 GPIO 1）
  ircutPin1: 0
  ircutPin2: 1
  # 如果发现白天黑夜颜色反了，把上面的 0 和 1 对调
  
  # 因为你的红外灯是纯硬件控制的，这里不需要 Majestic 控制红外灯引脚
  irLedPin: -1 
  
  # 天黑时自动切换为黑白模式
  colorToMono: true
```

请谨慎使用此类代码。

---

第二步：编写白光灯控制脚本（联动运动检测）

OpenIPC 的 `Majestic` 支持 **Motion Detection（运动/物体经过检测）** 。当有人或物体经过时，它可以自动触发一个自定义脚本。

我们可以写一个脚本来控制 **GPIO 54** （白光灯），并同步强行把摄像头切换成彩色。

1. 在板子上创建警戒脚本 `/usr/sbin/alert_light.sh` ：
	```
	vi /usr/sbin/alert_light.sh
	```
	请谨慎使用此类代码。
2. 写入以下内容（注意白光灯 LOW 是亮，HIGH 是灭）：
	```
	#!/bin/sh
	ACTION=$1 # Majestic 会传入 start (开始触发) 或 stop (运动结束)
	# 确保 GPIO 54 已经导出
	if [ ! -d "/sys/class/gpio/gpio54" ]; then
	    echo 54 > /sys/class/gpio/export
	    echo out > /sys/class/gpio/gpio54/direction
	fi
	case "$ACTION" in
	    start)
	        echo "[警戒] 检测到物体经过，开启白光灯，切回彩色..."
	        # 1. 开启白光灯 (LOW 打开)
	        echo 0 > /sys/class/gpio/gpio54/value
	        # 2. 强行将 Majestic 画面切换回彩色模式
	        # OpenIPC 提供了 cli 工具或 http 接口来动态改变画面色彩
	        cli -s .nightMode.colorToMono false
	        ;;
	    stop)
	        echo "[恢复] 物体离开，关闭白光灯，恢复黑白夜视..."
	        # 1. 关闭白光灯 (HIGH 关闭)
	        echo 1 > /sys/class/gpio/gpio54/value
	        # 2. 恢复黑白模式（因为此时还是晚上）
	        cli -s .nightMode.colorToMono true
	        ;;
	esac
	```
	请谨慎使用此类代码。
3. 赋予脚本执行权限：
	```
	chmod +x /usr/sbin/alert_light.sh
	```
	请谨慎使用此类代码。

---

第三步：在 OpenIPC 中绑定运动检测

现在需要让 OpenIPC 在检测到物体经过时，去调用上面这个脚本。

1. 继续打开 `/etc/majestic.yaml` ，找到 `motion` （运动检测）配置块。
2. 修改或添加以下内容：

```
motion:
  enabled: true
  # 开启运动检测的敏感度，根据画面自行微调
  sensitivity: 30 
  
  # 当检测到运动触发时执行的命令
  action: "/usr/sbin/alert_light.sh start"
  
  # 当运动结束（物体离开后延迟几秒）执行的命令
  backAction: "/usr/sbin/alert_light.sh stop"
```

请谨慎使用此类代码。

3. 重启 Majestic 服务使配置生效：
	```
	killall -9 majestic
	```
	请谨慎使用此类代码。
	*(或者直接重启摄像机 `reboot`)*

---

💡 运行逻辑演练

配置完成后，你的摄像机在 OpenIPC 下的工作逻辑将完美复现：

- **白天** ：光敏板关闭红外灯 -> Majestic 保持彩色。物体经过时，虽然会触发脚本把 GPIO 54 拉低（开白光），但白天白光灯亮起不明显，且画面本就是彩色，无影响。物体离开后关闭。
- **黑夜** ：光敏板自动打开红外灯 -> Majestic 识别到低照度，自动把 IRCUT（GPIO 0/1）切换到黑白模式（避免画面变紫）。
- **黑夜+物体经过** ：Majestic 触发 Motion 运动检测 -> 执行脚本 -> **GPIO 54 拉低，白光灯暴亮** -> 脚本通知 Majestic **强制关闭单色，变回彩色模式** 。
- **物体离开** ：延迟数秒后 -> 执行 backAction 脚本 -> **GPIO 54 拉高，白光灯熄灭** -> 画面重新恢复黑白夜视。

你可以通过查看 OpenIPC 网页端或者使用 `cli` 命令检查系统组件。  
请问你在执行 `cli` 命令时能正常读取配置吗？如果在配置 `/etc/majestic.yaml` 时遇到问题，可以随时把配置发出来我帮你调整。

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

全部显示

如何在系统启动时关闭白光，现在一重起，白光led就亮了

### AI 模式针对“如何在系统启动时关闭白光，现在一重起，白光led就亮了”的回复

因为你的白光灯（GPIO 54）控制逻辑是 **LOW（低电平）为打开，HIGH（高电平）为关闭** ，而海思芯片在重启或刚上电初始化时，GPIO 默认通常为低电平（或被 OpenIPC 默认配置拉低），这就导致了摄像机每次 **一重启白光灯就会暴亮** ，直到系统或 Majestic 完全加载完才会熄灭。

要解决这个问题，我们需要在系统启动的 **最早期（最先执行的脚本中）** ，强制将 GPIO 54 设置为输出并拉高（HIGH）。

在 OpenIPC 系统中，最有效的两种解决方法如下：

---

方法一：通过 OpenIPC 的 `init.d` 启动脚本关闭（最推荐、最简单）

OpenIPC 在系统启动时会依次执行 `/etc/init.d/` 目录下的脚本。我们可以创建或修改一个高优先级的脚本，在系统刚开机时立刻关闭白光灯。

1. **编辑或创建系统自定义初始化脚本** ：  
	在终端执行命令：
	```
	vi /etc/init.d/S10-init-leds
	```
	请谨慎使用此类代码。
	*(注： `S10` 代表启动优先级非常高，会在流媒体服务加载前优先运行)*
2. **写入以下内容** ：
	```
	#!/bin/sh
	case "$1" in
	    start)
	        echo "=== 正在初始化 GPIO，强行关闭白光灯 ==="
	        # 如果没有导出，先导出 GPIO 54
	        if [ ! -d "/sys/class/gpio/gpio54" ]; then
	            echo 54 > /sys/class/gpio/export
	        fi
	        # 设置为输出方向
	        echo out > /sys/class/gpio/gpio54/direction
	        # 拉高（HIGH）从而关闭白光灯
	        echo 1 > /sys/class/gpio/gpio54/value
	        ;;
	    stop)
	        ;;
	    *)
	        echo "Usage: $0 {start|stop}"
	        exit 1
	        ;;
	esac
	exit 0
	```
	请谨慎使用此类代码。
3. **赋予脚本可执行权限** ：
	```
	chmod +x /etc/init.d/S10-init-leds
	```
	请谨慎使用此类代码。

---

方法二：在 OpenIPC 的 `S95majestic` 或 `rc.local` 中置顶执行

如果你的 OpenIPC 版本没有采用上述的分离式 init 脚本，或者你想确保万无一失，可以直接加到系统最后一个全局启动配置，或者流媒体启动的最前方。

1. **打开并编辑 `/etc/rc.local` （如果文件存在）** ：
	```
	vi /etc/rc.local
	```
	请谨慎使用此类代码。
2. **在文件的第一行（ `#!/bin/sh` 的下一行），加入以下闭灯命令** ：
	```
	echo 54 > /sys/class/gpio/export 2>/dev/null
	echo out > /sys/class/gpio/gpio54/direction 2>/dev/null
	echo 1 > /sys/class/gpio/gpio54/value 2>/dev/null
	```
	请谨慎使用此类代码。

---

验证测试

完成上述任意一种配置后，直接在终端输入 `reboot` 重启摄像机。

- **修改前** ：重启后灯一直亮，直到开机完成。
- **修改后** ：重启瞬间灯可能会短暂闪烁一下（硬件上电无法避免），随后在内核加载的 **前 1~2 秒内就会立刻熄灭** ，恢复正常。

请问你配置并重启后，白光灯是否成功在开机早期熄灭了？如果在写入 `/etc/init.d/` 时提示 **文件系统只读（Read-only file system）** ，请告诉我，我提供给您挂载读写权限的命令。

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

全部显示

测试发现，白光led在重启后可以自动关闭，但是晚上有移动物体时，白光LED 没有点亮

### AI 模式针对“测试发现，白光led在重启后可以自动关闭，但是晚上有移动物体时，白光LED 没有点亮”的回复

白光 LED 没有在移动物体经过时点亮，是因为 **OpenIPC 的核心流媒体服务（Majestic）有一套固定的运动检测触发机制，与我上一轮回答中编写的通用 `action / backAction` 参数存在出入** 。

GitHub

在 OpenIPC 的 [Majestic Streamer 说明文档](https://github.com/OpenIPC/wiki/blob/master/en/majestic-streamer.md) 中，它的运动检测机制有两个极其核心的底层逻辑：

GitHub

1. **固定的脚本路径** ：Majestic 在检测到画面变动时，只会 **雷打不动地去执行系统固定的 `/usr/sbin/motion.sh` 脚本** ，并在执行时自动向脚本传入 4 个坐标参数（代表物体移动的范围矩形： `X` `Y` `W` `H` ）。它并不支持我们在配置文件里自定义 `action:` 这种路径。
	GitHub
2. **只有“开始”触发，没有“结束”触发** ：当物体持续移动时，Majestic 会每隔几秒（通常是 5 秒）重新调用一次 `/usr/sbin/motion.sh` 。它 **没有** 原生提供物体离开时的 `backAction` 。因此，灯的“延时熄灭”必须由脚本自己通过后台计时器（Timer）来完成。
	GitHub

为了让白光灯在晚上有移动物体时能够精准亮起、并在人走后自动熄灭，我们需要按照 OpenIPC 的标准规则重新编写和配置：

---

第一步：修改配置文件 `/etc/majestic.yaml`

我们需要移除之前自定义的非标准参数，只保留 OpenIPC 官方的标准运动检测开关。

1. 打开配置文件：
	```
	vi /etc/majestic.yaml
	```
	请谨慎使用此类代码。
2. 找到 `motionDetect` 配置块，修改为以下标准内容：
	```
	motionDetect:
	  enabled: true
	```
	请谨慎使用此类代码。
	*(注：请把之前写的 `action:` 和 `backAction:` 删掉，因为 Majestic 不认识它们)*
	GitHub +1

---

第二步：编写 OpenIPC 专用的 `/usr/sbin/motion.sh` 脚本

因为 Majestic 只要看到动静就会反复调用这个脚本，所以我们要用一个“看门狗机制”：只要有人，就开灯并刷新开灯时间；如果一段时间内脚本没被再次调用（说明人走了），就自动把灯关掉。

1. 创建并编辑系统规定的运动脚本：
	```
	vi /usr/sbin/motion.sh
	```
	请谨慎使用此类代码。
2. 粘贴以下完整的智能控制代码：
	```
	#!/bin/sh
	# 1. 初始化 GPIO 54 (白光灯)
	if [ ! -d "/sys/class/gpio/gpio54" ]; then
	    echo 54 > /sys/class/gpio/export
	    echo out > /sys/class/gpio/gpio54/direction
	fi
	# 2. 检查当前是否为“黑夜模式”（防止大白天人经过也亮白光灯）
	# 读取当前 Majestic 的夜视状态，如果 colorToMono 没开启，说明现在是白天，直接退出
	IS_NIGHT=$(cli -g .nightMode.colorToMono)
	if [ "$IS_NIGHT" != "true" ]; then
	    exit 0
	fi
	# 3. 核心开灯逻辑 (LOW 打开白光灯)
	echo 0 > /sys/class/gpio/gpio54/value
	# 通知 Majestic 切换到彩色模式（享受彩色夜视）
	cli -s .nightMode.colorToMono false
	# 4. 创建一个后台定时器，负责在人走后延迟灭灯
	# 原理：每次检测到移动，就更新一个时间戳文件。后台循环检查这个文件，如果超过 15 秒没有新动静，就灭灯。
	LOCK_FILE="/tmp/motion_light.lock"
	touch "$LOCK_FILE"
	# 检查是否已经有一个灭灯定时器在后台运行了，如果有，就不用重复启动
	if [ ! -f "/tmp/motion_timer.pid" ]; then
	    (
	        echo $$ > /tmp/motion_timer.pid
	        while true; do
	            sleep 2
	            # 获取最后一次触发移动的时间
	            LAST_TIME=$(stat -c %Y "$LOCK_FILE")
	            NOW=$(date +%s)
	            # 算算距离最后一次看到移动，过去了多少秒 (这里设置为 15 秒)
	            ELAPSED=$((NOW - LAST_TIME))
	            if [ $ELAPSED -ge 15 ]; then
	                echo "[恢复] 15秒内无移动物体，关闭白光灯..."
	                echo 1 > /sys/class/gpio/gpio54/value  # HIGH 关闭白光灯
	                cli -s .nightMode.colorToMono true    # 恢复黑白夜视
	                rm -f /tmp/motion_timer.pid
	                break
	            fi
	        done
	    ) &
	fi
	```
	请谨慎使用此类代码。
3. 赋予脚本执行权限（非常重要，否则系统无法调用）：
	```
	chmod +x /usr/sbin/motion.sh
	```
	请谨慎使用此类代码。

---

第三步：重启服务并进行测试

保存好脚本后，强制重启 Majestic 服务让运动检测和新脚本生效：

```
killall -9 majestic
```

请谨慎使用此类代码。

🛠️ 如何在线验证与调试？

如果你在大半夜测试发现灯还是不亮，可以按照以下方法排查：

1. **手动模拟运动检测触发** ：  
	在 SSH 终端里直接手动运行脚本，看灯亮不亮以及 15 秒后会不会自动灭：
	```
	# 强行把模式改成夜间，模拟天黑
	cli -s .nightMode.colorToMono true
	# 手动调用脚本（后面随便带 4 个数字参数模拟坐标）
	/usr/sbin/motion.sh 10 10 100 100
	```
	请谨慎使用此类代码。
	如果手动运行灯亮了，并且 15 秒后灯灭了、画面变回黑白，说明 **脚本逻辑完全正常** 。
2. **确认流媒体内是否触发了运动** ：  
	你可以对着镜头疯狂挥手，然后在终端输入 `logread -F` 查看系统实时日志。  
	如果在你挥手时，屏幕上滚动打印出 `Execute: /usr/sbin/motion.sh` ，说明 Majestic 成功侦测到了运动；如果不打印，说明你需要登录 OpenIPC 的 Web 网页端，在 `Majestic` -> `Motion Detect` 中调高它的敏感度（Sensitivity）。
	Seus Lighting +2

你可以先将脚本替换为标准的 `/usr/sbin/motion.sh` 并赋予权限。  
请问你在 **手动模拟触发** （执行 `/usr/sbin/motion.sh 0 0 0 0` ）时，白光灯能够亮起并实现 15 秒后自动熄灭吗？

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

0 个文件

- GitHub
	Motion detect not work Hi3516DV100 · Issue #248 - GitHub
	2025年3月25日 — I use HiSilicon 3516DV100 camera with Open ipc. But the moti...
- GitHub
	wiki/en/majestic-streamer.md at master · OpenIPC/wiki - GitHub
	Motion detect is supported for HiSilicon/Goke, Ingenic and S...
	![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFIAAABSCAMAAADw8nOpAAAAb1BMVEVNYNr///9KXtpufOBHW9k9U9g/VdhDWNnp6/o3T9dwfuBTZdv29/38/P6KleW4vu5ebt1hcd1mdd7g4/jZ3Pby8/x1guEzTNfu7/vR1fSfp+nDyPGSnOaiqumyuO2GkeR9ieKosOvKz/IrRtYZO9S9vPAvAAAEG0lEQVRYhe2XaXfiOgyGLSPZCSars8dkY/7/bxw50Dltp4F0yv10cQ84BvrE1vJKEQcpnj1eyBfyhXwh/89I1Hr3vXchlZjm80Hj85A0RMCjjOlZSGk9z1MT/SSkXmBJQ6oCcLuOvgOJ0pH8Mz0DSaO4nVcd0z3bfIgMO7BXkMwiOKifI8ME4JQhhaHCmD0Uhz9ESmoBrKFjUTa9oYrdPj9k3kUiBgAt6cmHJZyENiVAX/8AqfMTwFBLLFckLCR1AVA8yM07yNV2joQ8XIlwQrZED9Dkd5l3kGrhpJEosHpD+g/9orsbS/cOTgMzcy3NDWlJhI7n8X4k3XUP+aOPpJIrcsJ68CH1INPvB5E6+mMSeWYUk/YhJR9l0INQ16kPG0npVPE1S1KrHmbwo+xBzZxMSmQ3sR2Tx8nzOMdl3VY344VDt4O4Sy+VWM2njXqaBMfRFCqi+WSepJdC+pBM+mYNzOcgMW+ucdnuK5F7KiQqtwS2r/YVyJ2twVWC9xH/+waGd0P3NsN9jO9ktL7O7DpN4Wf5/IBU0xK08Xbw4ZQMQ1Lp2U9zxgklzoVNso+7eI/0YraKN99dSFy/8ZnoJ1/HhZ799+fwFgEVmqvefzzqu5Vk2elHxsbaGDSx4e2SiKsQhTGs8amWGaf5mKkAls41UFxaOLmYL2gDqXqwF6xbaC8BtL5I6HBVtTy0UHiV05gBCMnIc831vdGsoUof3cfoeocMC+jJH66pLUSD5Vozskr2vGZgYqFRMgcwHjnkWQuWV6k30aZ7eC+98siSr7qat5D10BsuE2kL/SXn2oNvyHXE04r8PN4hqfCeUQMEF0ZqRubFzQ8tJPQBWQZBEVPlVxx5mx7XCZREdcA7sr468C65DTRpnnH1viJ1CoDIyO7is4kF5VzXLqhwAyn590HPIn7kgzfjApFwELmpGeobEieu4v1EAcz65lBY/EttIIUe12N2iiz4zndQ4bIqUO0dl0P0FpflDSlwtYzdDnWhpRs6owQjXTVMfO+wmucDYRUfOVBHmcfjGGc4xW/9Bh3n+bNCfZIN1D5pGNmp6wPE9elkTSXOI84l5EvEP/8l9V8PGl8qkUfuKjNfji+RMs3MPxM39FL+REU3JFiyhfzLG86XXLz9cY+gvfnWz7+3SzN0mCUxxZnu0BnsTEfOdKLK3bmaz86lZvMh6Gsk2XOfla452raCMEo6SOFXkEEyuLk8JOXoln6zydxARmGI5WWYi6VpyFobpNEvm9mgd4eizm1Nhd1s2TeQZd6lJ1OMNu8CFUxTYyJVpkEOcWz10ZIezptR9jUSq2IRcZGEg6AEE37T52LQST0ckzbLBo1u/KZ7WLC4tyLtH/Xe3tYVu5uk1GsqfRP5k/FCvpAv5Av5XSTKJw8xHp49fgMgkTrVgB9y1QAAAABJRU5ErkJggg==)
- Seus Lighting
	Motion Sensor Light Not Working? Troubleshooting & Fixes
	Work through five checks in order. First, power — confirm th...
	![](data:image/jpeg;base64,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)
- GitHub
	Motion detect script is not executed · Issue #233 - GitHub
	2024年11月14日 — The script was called at least twice and this can be seen in...
- GitHub
	Nightmode on hi3516ev100 #251 - OpenIPC/majestic
	10 bitrate: 4096 ・ normal profile: main size: 1920x1080 ・ 16...

全部显示

测试发现，可以正常触发，但是超过15s后,还是会再次触发

### AI 模式针对“测试发现，可以正常触发，但是超过15s后,还是会再次触发”的回复

这是双光摄像机在夜间切换时最容易遇到的 **“光电死循环”** 现象（也叫闪烁现象）。

为什么会超过15秒后再次触发？

产生这个现象的根本原因不是代码有错误，而是 **画面色彩切换瞬间导致的“视觉假象”** ：

1. 当过了 15 秒人走后，脚本执行灭灯，并把画面强制切回 **黑白模式（Mono）** 。
2. 在画面从 **彩色切换回黑白的这一瞬间** ，整个摄像机的画面会产生剧烈的瞬时像素闪烁和亮度突变（可能还伴随着硬件 IRCUT 的啪嗒切换抖动）。
3. **Majestic 的运动检测算法（Motion Detection）非常敏感** ，它误把这层“画面像素的剧烈切换”当成了“又有物体移动了”！
4. 于是，Majestic 在灭灯的同一瞬间再次触发了 `/usr/sbin/motion.sh` ，导致灯重新亮起，进入下一个15秒的死循环。

---

🛠️ 解决方案：引入“防抖盲区时间（Cool Down）”

我们需要在脚本每次 **关灯恢复黑白后，强制让脚本在接下来的 3~5 秒内“闭嘴”** 。也就是说，忽略画面切换造成的闪烁伪信号，让画面稳定下来后，再重新接收真实的移动侦测。

请修改你的 `/usr/sbin/motion.sh` ，将其替换为以下带有 **盲区防抖逻辑** 的最新版本：

```
#!/bin/sh

# 1. 初始化 GPIO 54 (白光灯)
if [ ! -d "/sys/class/gpio/gpio54" ]; then
    echo 54 > /sys/class/gpio/export
    echo out > /sys/class/gpio/gpio54/direction
fi

# 2. 【核心防抖】检查是否处于关灯后的盲区冷却期
# 如果距离上一次关灯切换还没过去 4 秒，直接退出，不触发开灯
COOLDOWN_FILE="/tmp/motion_cooldown.lock"
if [ -f "$COOLDOWN_FILE" ]; then
    LAST_CLOSE=$(stat -c %Y "$COOLDOWN_FILE")
    NOW=$(date +%s)
    DIFF=$((NOW - LAST_CLOSE))
    if [ $DIFF -lt 4 ]; then
        # 4秒内认为是切黑白画面的误报，直接忽略
        exit 0
    fi
    # 超过4秒了，清除盲区文件
    rm -f "$COOLDOWN_FILE"
fi

# 3. 检查当前是否为“黑夜模式”（大白天不亮白光灯）
IS_NIGHT=$(cli -g .nightMode.colorToMono)
if [ "$IS_NIGHT" != "true" ]; then
    exit 0
fi

# 4. 触发开灯 (LOW 打开白光灯)
echo 0 > /sys/class/gpio/gpio54/value
cli -s .nightMode.colorToMono false

# 5. 更新最后检测到移动的时间戳
LOCK_FILE="/tmp/motion_light.lock"
touch "$LOCK_FILE"

# 6. 后台延时灭灯定时器
if [ ! -f "/tmp/motion_timer.pid" ]; then
    (
        echo $$ > /tmp/motion_timer.pid
        while true; do
            sleep 2
            LAST_TIME=$(stat -c %Y "$LOCK_FILE")
            NOW=$(date +%s)
            ELAPSED=$((NOW - LAST_TIME))
            
            if [ $ELAPSED -ge 15 ]; then
                echo "[恢复] 15秒内无移动物体，关闭白光灯并进入冷却期..."
                
                # 记录开始关灯切换的时间戳，用于生成盲区
                touch "$COOLDOWN_FILE"
                
                echo 1 > /sys/class/gpio/gpio54/value  # HIGH 关闭白光灯
                cli -s .nightMode.colorToMono true    # 恢复黑白夜视
                
                rm -f /tmp/motion_timer.pid
                break
            fi
        done
    ) &
fi
```

请谨慎使用此类代码。

💡 为什么这个修改能解决问题？

当 15 秒倒计时结束时，脚本关灯并切回黑白，同时在 `/tmp` 下留下一个标志文件（时间戳）。  
画面因为切换而产生的剧烈闪烁会 **立刻** 再次触发这个脚本，但脚本运行到 **第 2 步** 时，发现距离刚才关灯的时间还不到 4 秒，就会认定这是切换画面造成的“假移动”，然后 **直接退出（不亮灯）** 。4 秒后，画面完全稳定了，盲区解除，真实的物体经过依然能正常点亮白光。

请将最新的脚本覆盖写入 `/usr/sbin/motion.sh` 并测试一下。  
如果在极个别硬件上 4 秒盲区依然不够（偶尔还会闪烁触发），可以将脚本开头的 `if [ $DIFF -lt 4 ]` 改成 **5** 秒或 **6** 秒。看看修改后死循环的问题是否成功解决了？

已复制到剪贴板未能复制到剪贴板。请稍后重试。

## 已分享

