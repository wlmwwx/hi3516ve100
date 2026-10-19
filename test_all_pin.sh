# test all pin
# !!! 主演，执行到某个pin时会造成系统不响应，请按web页面里setting-pin 里的pin 图逐个测试

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
