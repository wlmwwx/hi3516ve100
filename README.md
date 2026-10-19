# 安装步骤

## 1. 备份原来的固件
```
# 请逐行输入命令！不要一次复制粘贴多行！
printenv ethaddr
setenv ipaddr 192.168.3.10; setenv serverip 192.168.3.20
mw.b 0x82000000 0xff 0x1000000
sf probe 0; sf read 0x82000000 0x0 0x1000000
tftpput 0x82000000 0x1000000 backup-hi3516ev100-nor16m.bin
# if there is no tftpput but tftp then run this instead
# (the third argument is what makes tftp upload rather than download)
tftp 0x82000000 backup-hi3516ev100-nor16m.bin 0x1000000
```

## 2. 刷入新固件
```
# 请逐行输入命令！不要一次复制粘贴多行！
setenv ipaddr 192.168.3.10; setenv serverip 192.168.3.20
mw.b 0x82000000 0xff 0x1000000
sf probe 0; sf lock 0;
tftpboot 0x82000000 openipc-hi3516ev100-nor-lite-16mb.bin && sf erase 0x0 0x1000000 && sf write 0x82000000 0x0 ${filesize}
# if there is no tftpboot but tftp then run this instead
tftp 0x82000000 openipc-hi3516ev100-nor-lite-16mb.bin && sf erase 0x0 0x1000000 && sf write 0x82000000 0x0 ${filesize}
reset

```

## 3. 在引导加载程序的命令行中，根据您的闪存大小和类型重新映射 ROM 分区。这步必须做
连接串口，重启，马上按任意键终止启动，进入uboot，运行下面的指令
```
# 请逐行输入命令！不要一次复制粘贴多行！
run setnor16m
reset
```

因为我的方机摄像头是8M flash，官方8Mflash没有wifi支持，增加wifi 8Mflash空间不够，需要更换为16M flash。
刷入自定义编译的固件。

backup-hi3516ev100-nor8m.bin  原来的固件
openipc-hi3516ev100-nor-lite-16mb.bin 官方16M 固件,刷入后同样要做第三步
openipc-hi3516ev100-nor-lite-16mb-new.bin 新编译的固件，增加wifi支持

u-boot-region.bin  16M 版本提取的uboot

## 4 控制逻辑
在软件层面，你需要在主程序中根据环境亮度（通过 传感器 Sensor 的亮度统计值 或 外置光敏电阻 CDS 的 GPIO 输入）和智能分析结果（如人形检测），来切换这三种工作模式：

☀️ 模式 A：白天模式（Day Mode）

• 白光灯：关闭（LOW）。
• 红外灯：关闭（LOW）。
• IRCUT滤镜：移入（切换至白天状态，过滤红外光，使画面不偏色）。
• ISP软件设置：调用海思 MPP SDK 将图像模式设为 彩色（Color）。

🌙 模式 B：普通夜视模式（IR Night Mode）

• 白光灯：关闭（LOW）。
• 红外灯：开启（HIGH 或 PWM 调节亮度）。
• IRCUT滤镜：移出（切换至夜间状态，让红外光通过以感光）。
• ISP软件设置：调用海思 MPP SDK 将图像模式设为 黑白（Mono/Mono-Chrome），否则画面会严重偏色（变紫/变红）。

🚨 模式 C：白光警戒模式（White Light Mode）

当触发智能警戒（如人脸识别、人形检测）时，从红外模式切换为白光：
1. 红外灯：立刻关闭（LOW）。
2. 白光灯：立刻开启（HIGH）。
3. IRCUT滤镜：切回白天状态（移入滤镜，过滤红外干扰）。
4. ISP软件设置：延迟数百毫秒（等待白光灯稳定、环境变亮后），调用 SDK 将图像模式切回 彩色（Color）。

## 启动时禁止白光LED
/etc/init.d/S10-init-leds

## 增加/usr/sbin/motion.sh 实现原来晚上有人走动点亮白光，录制彩色图像功能。


## 控制白光LED的 有的是gpio-55,有的是gpio-54
  S10-init-leds.sh 和motion.sh 里都要做相应的改动

## motion.sh 被调用时出现网络连接不上的情况，目前没有找到问题，先放弃这个功能
