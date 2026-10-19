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
