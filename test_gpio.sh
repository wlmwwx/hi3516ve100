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
