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
