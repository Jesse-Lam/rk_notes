---
id: 1761638254905338
---
# RK平台调试指令-系统篇

## 1. 系统版本信息
- **查看Android设备型号**  
```shell
getprop ro.product.model
```
- **查看Android厂商品牌**  
```shell
getprop ro.product.manufacturer
```
- **查看Android系统版本**  
```shell
getprop ro.build.version.release
```
- **查看Linux系统版本**  
```shell
uname -a
```
- **查看Kernel版本和编译信息**  
```shell
cat /proc/version
```

## 2. 硬件信息
- **查看内存信息**  
```shell
cat /proc/meminfo
```
- **查看系统分区信息**  
```shell
cat /proc/partitions
```
- **查看CPU信息**  
```shell
cat /proc/cpuinfo
```
- **查看CPU支持的频率**（x可改为0,1,2,3...）  
```shell
cat /sys/devices/system/cpu/cpux/cpufreq/scaling_available_frequencies
```
- **查看CPU支持的策略**（x可改为0,1,2,3...）  
```shell
cat /sys/devices/system/cpu/cpux/cpufreq/scaling_available_governors
```
- **查看DDR支持的频率**  
```shell
cat /sys/class/devfreq/dmc/available_frequencies
```

## 3. 系统资源监控
- **查看内存使用情况**  
```shell
free -h
```
- **查看磁盘使用情况**  
```shell
df -h
```
- **查看所有进程**  
```shell
ps -ef
```
- **实时显示进程状态**  
```shell
top
```
- **查看内核日志**  
```shell
dmesg
```

## 4. 硬件状态监控
- **查看CPU温度**  
```shell
cat /sys/class/thermal/thermal_zone0/temp
```
- **查看CPU当前频率**（x可改为0,1,2,3...）  
```shell
cat /sys/devices/system/cpu/cpux/cpufreq/scaling_cur_freq
```
- **查看GPU使用率**（fb000000为GPU地址，不同SoC地址不同）  
```shell
cat /sys/devices/platform/fb000000.gpu/devfreq/fb000000.gpu/load
```
- **查看DDR当前频率**  
```shell
cat /sys/class/devfreq/dmc/cur_freq
```
- **查看DDR带宽占用率**  
```shell
cat /sys/devices/platform/dmc/devfreq/dmc/load
```
- **查看GPU当前频率**（fb000000为GPU地址，不同SoC地址不同）  
```shell
cat /sys/class/devfreq/fb000000.gpu/cur_freq
```
- **查看NPU当前频率**（fdab0000为NPU地址，不同SoC地址不同）  
```shell
cat /sys/class/devfreq/fdab0000.npu/cur_freq
```
- **查看NPU使用率**（fdab0000为NPU地址，不同SoC地址不同）  
```shell
cat /sys/class/devfreq/fdab0000.npu/load
```

## 5. 时钟和电压信息
- **查看系统CLK信息**  
```shell
cat /sys/kernel/debug/clk/clk_summary
```
- **查看CPU/GPU/DDR/NPU的频率电压表**  
```shell
cat /sys/kernel/debug/opp/opp_summary
```

## 6. GPIO信息
- **查看GPIO复用情况**  
```shell
cat /sys/kernel/debug/pinctrl/pinctrl/pinmux-pins
```
- **查看GPIO占用状态**  
```shell
cat /sys/kernel/debug/gpio
```

## 7. 电源管理
- **防止Android系统进入二级休眠**  
```shell
echo "test" > /sys/power/wake_lock
```
- **强制系统进入二级休眠**  
```shell
echo mem > /sys/power/state
```
- **保持PM_DOMAINS常开**  
```shell
echo 1 > /sys/module/pm_domains/parameters/always_on
```
- **保持CLK常开**  
```shell
echo 1 > /sys/module/clk_gate/parameters/always_on
```
- **查看电源域（Power Domain）信息**  
```shell
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary
```

## 8. CPU控制
- **关闭CPU核**（x可改为0,1,2,3...）  
```shell
echo 0 > /sys/devices/system/cpu/cpux/online
```
- **开启CPU核**（x可改为0,1,2,3...）  
```shell
echo 1 > /sys/devices/system/cpu/cpux/online
```
- **手动清除DDR缓存占用**  
```shell
echo 3 > /proc/sys/vm/drop_caches
```

## 9. 频率控制

### CPU定频
```shell
# 无大小核平台只要操作policy0
# 切换到userspace模式
echo userspace > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
# 设置1.2GHz
echo 1200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed

# 大小核平台需要操作多个policy
# 小核cpu0~cpu3设置
echo userspace > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 1200000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed

# 大核cpu4~cpu5设置
echo userspace > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed

# 大核cpu6~cpu7设置
echo userspace > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy6/scaling_setspeed
```

### GPU定频
```shell
# 切换到userspace模式（fb000000.gpu需根据平台修改）
echo userspace > /sys/class/devfreq/fb000000.gpu/governor

# 设置400MHz
echo 400000000 > /sys/class/devfreq/fb000000.gpu/userspace/set_freq

# 查看当前频率
cat /sys/class/devfreq/fb000000.gpu/cur_freq
```

### NPU定频
```shell
# 切换到userspace模式（fdab0000.npu需根据平台修改）
echo userspace > /sys/class/devfreq/fdab0000.npu/governor

# 设置1GHz
echo 1000000000 > /sys/class/devfreq/fdab0000.npu/userspace/set_freq

# 查看当前频率
cat /sys/class/devfreq/fdab0000.npu/cur_freq
```

### DDR定频
```shell
# 切换到userspace模式
echo userspace > /sys/class/devfreq/dmc/governor

# 查看可用频率
cat /sys/class/devfreq/dmc/available_frequencies

# 设置1.56GHz
echo 1560000000 > /sys/class/devfreq/dmc/userspace/set_freq

# 查看当前频率
cat /sys/class/devfreq/dmc/cur_freq
```

### 性能模式设置
```shell
# CPU性能模式
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo performance > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
echo performance > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor

# DDR性能模式
echo performance > /sys/devices/platform/dmc/devfreq/dmc/governor
```