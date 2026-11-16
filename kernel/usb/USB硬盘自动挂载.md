---
id: 1761638255142333
---
# USB 硬盘自动挂载
## 前言

最近遇到一个问题：Linux 系统下 U 盘能实现插入自动挂载，USB 硬盘插入能正常枚举，但是不能自动挂载，手动可以挂载成功。考虑到 Linux 系统的热插拔都是由 udev 实现的，因此找了 udev 相关的资料来调试这一功能，本文介绍 udev 的用法和调试过程。

## udev 简介

udev 是 Linux 系统中的用户空间设备管理工具，负责：

- 动态管理 **`/dev`** 目录下的设备节点
- 处理热插拔设备事件
- 加载设备对应的固件
- 执行设备相关的配置规则

## udev 规则工作原理

### 1. 事件处理流程

1. 内核检测到设备变动（热插拔或冷插拔）
2. 内核通过 netlink 发送 uevent 到 udevd
3. udevd 接收事件并匹配规则
4. 执行匹配到的规则中的动作
5. 创建设备节点或执行其他操作

### 2. 规则匹配过程

udev 规则采用"匹配+动作"的模式：

- **匹配部分**：一系列条件（如内核名称、子系统、属性等）
- **动作部分**：匹配成功后执行的操作（如创建设备节点、设置权限等）

## udev 规则文件

### 1. 规则文件位置

- 系统规则：**`/lib/udev/rules.d/`**
- 自定义规则：**`/etc/udev/rules.d/`**
- 临时规则：**`/run/udev/rules.d/`**

### 2. 规则文件命名

- 以数字开头（决定优先级，数字小的先执行）
- 以 **`.rules`** 结尾
- 例如：**`99-mydevice.rules`**

## 规则语法详解

### 1. 基本结构

```
匹配键 [操作符] "值", 匹配键 [操作符] "值", ... ACTION=="动作", 操作键+="值", ...
```

### 2. 常用匹配键

- **`KERNEL`** - 内核设备名称
- **`SUBSYSTEM`** - 设备子系统
- **`DRIVER`** - 设备驱动
- **`ATTR{filename}`** - 设备属性文件内容
- **`ENV{key}`** - 环境变量

### 3. 操作符

- == 相等比较
- != 不等比较
- = 赋值（创建或替换）
- += 追加赋值
- := 最终赋值（之后不能再修改）

### 4. 常用操作键

- **`NAME`** - 设备节点名称
- **`SYMLINK`** - 符号链接名称
- **`MODE`** - 设备节点权限
- **`OWNER`**, **`GROUP`** - 设备所有者/组
- **`RUN`** - 执行外部程序
- **`IMPORT`** - 导入外部程序输出

## 高级特性

### 1. 变量替换

- **`$kernel`** - 内核设备名
- **`$number`** - 设备编号
- **`%k`** - 内核设备名（同 $kernel）
- **`%n`** - 设备号（如分区号）

### 2. 条件执行

```
ACTION=="add", RUN+="/bin/add_device"
ACTION=="remove", RUN+="/bin/remove_device"
```

### 3. 外部程序调用

```
IMPORT{program}="/sbin/blkid -o udev -p %N"
RUN+="/usr/local/bin/setup_device.sh"
```

## 调试技巧

### 1. 测试规则

```bash
udevadm test --action=add /sys/class/block/sde1
```

说明：

- **`-action=add`** 表示模拟一个设备插入（**`add`**）的 uevent 事件（类似热插拔）。
- 实际不会真正添加设备，只是测试 udev 规则如何响应这种事件。
- **`/sys/class/block/sde1`** 是目标设备的 **sysfs 路径**，对应设备节点 **`/dev/sde1`**（通常是一个分区）。
- udev 会读取该路径下的设备属性（如 **`devtype`**、**`size`**、**`partition`** 等）用于规则匹配。
- 命令会输出详细的规则匹配过程，包括：
    - 读取的设备属性（**`ATTR{...}`**、**`ENV{...}`**）。
    - 匹配到的 udev 规则文件及规则行。
    - 将要执行的动作（如 **`RUN`**、**`SYMLINK`**、**`IMPORT`** 等），但不会实际执行。

### 2. 查看设备属性

```bash
udevadm info -a -p /sys/class/block/sde1
```

说明：

- 从设备的 **`sysfs`** 路径（**`/sys/class/block/sde1`**）中提取所有 udev 可用的属性（如 **`ID_SERIAL`**、**`ID_FS_TYPE`**、设备大小等）。
- 这些属性可用于编写 udev 规则时的匹配条件（如 **`ATTR{size}=="123456"`**）。
- 通过 **`a`** 参数递归显示设备的父设备（如 USB 控制器、SCSI 主机等）的所有属性，帮助理解设备的完整连接路径。
- 仅读取信息，不会触发任何实际操作（如挂载、加载驱动等）。

### 3. 触发事件

```bash
udevadm trigger --action=add /sys/class/block/sde1
```

说明：

- 通过 **`-action=add`** 模拟设备被插入的动作，让 udev 像检测到新设备一样重新处理该设备。
- 对 **`/sys/class/block/sde1`**（对应 **`/dev/sde1`** 分区）触发事件。
- udev 会重新扫描设备的属性（如序列号、文件系统类型等）。
- 执行所有匹配该设备的规则中的操作（如创建设备节点、设置权限、运行脚本等）。
- 与 **`udevadm test`**（仅测试）不同，此命令会真正执行规则中的操作（如挂载、加载驱动等）。

### 4. 监控事件

```bash
udevadm monitor
```

说明：

- 监控内核通过 **`uevent`** 机制发送的设备动态：插入（**`add`**）、移除（**`remove`**）、状态变化（**`change`**）等。
- 显示事件的完整上下文，包括设备路径、动作类型、环境变量等。
- 观察设备事件是否触发预期的 udev 规则。
- 验证设备属性（如 **`ID_SERIAL`**、**`ID_FS_TYPE`**）是否正确传递。
- 仅监听事件，不会修改系统状态或干扰设备正常操作。

### 5. 重新加载规则文件

```bash
udevadm control --reload
```

说明：

- 修改 udev 规则文件（如 **`/etc/udev/rules.d/99-myrule.rules`**）后，必须执行此命令使新规则生效。
- 无需重启系统或 udev 服务，避免中断正在管理的设备。
- 重新读取以下目录中的所有 **`.rules`** 文件：
    - 系统规则：**`/lib/udev/rules.d/`**
    - 自定义规则：**`/etc/udev/rules.d/`**
    - 临时规则：**`/run/udev/rules.d/`**
- 仅重新加载规则，不会主动触发设备事件（需配合 **`udevadm trigger`** 处理现有设备）。

## 调试过程

### 1. 确认系统的 udev 规则文件

```bash
# busybox find / -name rules.d
/run/udev/rules.d
/usr/lib/udev/rules.d
/etc/udev/rules.d
```

经过排查，用的是`/usr/lib/udev/rules.d/usbmount.rules`

### 2. 查看当前配置

```bash
# cat /usr/lib/udev/rules.d/usbmount.rules 
# Rules for USBmount -*- conf -*-

SUBSYSTEM!="block", GOTO="usbmount_end"
ACTION=="remove", RUN+="/usr/share/usbmount/usbmount remove"

ACTION!="add", GOTO="usbmount_end"
ENV{ID_FS_TYPE}=="", GOTO="usbmount_end"

KERNEL=="mmcblk*", ATTRS{type}=="SD", RUN+="/usr/share/usbmount/usbmount add sd"
ENV{ID_BUS}=="usb", RUN+="/usr/share/usbmount/usbmount add usb"

LABEL="usbmount_end"
```

当前配置了 SD 卡和 USB 设备，前面已经测试 U 盘是正常的，说明这个 USB 设备的配置是可用的。

那么，我们需要分析 USB 硬盘与 U 盘的 udev 信息有什么区别。

### 3. 对比差异并修改规则

```bash
为了简约，这里不加-a参数
U盘：
# udevadm info -p /sys/class/block/sde1
P: /devices/platform/23400000.usb/xhci-hcd.0.auto/usb2/2-1/2-1:1.0/host1/target1:0:0/1:0:0:0/block/sde/sde1
N: sde1
S: disk/by-id/usb-aigo_W338_12DC8C01A870D539-0:0-part1
S: disk/by-label/\xbbָ\xb4
S: disk/by-partuuid/5a34c360-01
S: disk/by-path/platform-xhci-hcd.0.auto-usb-0:1:1.0-scsi-0:0:0:0-part1
S: disk/by-uuid/FE40-0C8F
E: DEVLINKS=/dev/disk/by-id/usb-aigo_W338_12DC8C01A870D539-0:0-part1 /dev/disk/by-label/\xbbָ\xb4 /dev/disk/by-partuuid/5a34c360-01 /dev/disk/by-path/platform-xhci-hcd.0.auto-usb-0:1:1.0-scsi-0:0:0:0-part1 /dev/disk/by-uuid/FE40-0C8F
E: DEVNAME=/dev/sde1
E: DEVPATH=/devices/platform/23400000.usb/xhci-hcd.0.auto/usb2/2-1/2-1:1.0/host1/target1:0:0/1:0:0:0/block/sde/sde1
E: DEVTYPE=partition
E: DISKSEQ=15
E: ID_BUS=usb
E: ID_FS_LABEL=_ָ_
E: ID_FS_LABEL_ENC=\xbbָ\xb4
E: ID_FS_TYPE=vfat
E: ID_FS_USAGE=filesystem
E: ID_FS_UUID=FE40-0C8F
E: ID_FS_UUID_ENC=FE40-0C8F
E: ID_FS_VERSION=FAT32
E: ID_INSTANCE=0:0
E: ID_MODEL=W338
E: ID_MODEL_ENC=W338\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20
E: ID_MODEL_ID=6300
E: ID_PART_ENTRY_DISK=8:64
E: ID_PART_ENTRY_FLAGS=0x80
E: ID_PART_ENTRY_NUMBER=1
E: ID_PART_ENTRY_OFFSET=2048
E: ID_PART_ENTRY_SCHEME=dos
E: ID_PART_ENTRY_SIZE=67108864
E: ID_PART_ENTRY_TYPE=0xc
E: ID_PART_ENTRY_UUID=5a34c360-01
E: ID_PART_TABLE_TYPE=dos
E: ID_PART_TABLE_UUID=5a34c360
E: ID_PATH=platform-xhci-hcd.0.auto-usb-0:1:1.0-scsi-0:0:0:0
E: ID_PATH_TAG=platform-xhci-hcd_0_auto-usb-0_1_1_0-scsi-0_0_0_0
E: ID_REVISION=PMAP
E: ID_SERIAL=aigo_W338_12DC8C01A870D539-0:0
E: ID_SERIAL_SHORT=12DC8C01A870D539
E: ID_TYPE=disk
E: ID_USB_DRIVER=usb-storage
E: ID_USB_INTERFACES=:080650:
E: ID_USB_INTERFACE_NUM=00
E: ID_VENDOR=aigo
E: ID_VENDOR_ENC=aigo\x20\x20\x20\x20
E: ID_VENDOR_ID=3535
E: MAJOR=8
E: MINOR=65
E: PARTN=1
E: SUBSYSTEM=block
E: USEC_INITIALIZED=537397984

USB硬盘：
# udevadm info -p /sys/class/block/sde1
P: /devices/platform/23400000.usb/xhci-hcd.0.auto/usb1/1-1/1-1:1.0/host1/target1:0:0/1:0:0:0/block/sde/sde1
N: sde1
S: disk/by-id/ata-WDC_WD5000LPCX-60VHAT0_WD-WXU1E776JT62-part1
S: disk/by-id/wwn-0x50014ee608107338-part1
S: disk/by-partuuid/a342b05c-01
S: disk/by-path/platform-xhci-hcd.0.auto-usb-0:1:1.0-scsi-0:0:0:0-part1
S: disk/by-uuid/68D2C485D2C45948
E: DEVLINKS=/dev/disk/by-id/ata-WDC_WD5000LPCX-60VHAT0_WD-WXU1E776JT62-part1 /dev/disk/by-id/wwn-0x50014ee608107338-part1 /dev/disk/by-partuuid/a342b05c-01 /dev/disk/by-path/platform-xhci-hcd.0.auto-usb-0:1:1.0-scsi-0:0:0:0-part1 /dev/disk/by-uuid/68D2C485D2C45948
E: DEVNAME=/dev/sde1
E: DEVPATH=/devices/platform/23400000.usb/xhci-hcd.0.auto/usb1/1-1/1-1:1.0/host1/target1:0:0/1:0:0:0/block/sde/sde1
E: DEVTYPE=partition
E: DISKSEQ=16
E: ID_ATA=1
E: ID_ATA_DOWNLOAD_MICROCODE=1
E: ID_ATA_FEATURE_SET_APM=1
E: ID_ATA_FEATURE_SET_APM_CURRENT_VALUE=128
E: ID_ATA_FEATURE_SET_APM_ENABLED=1
E: ID_ATA_FEATURE_SET_PM=1
E: ID_ATA_FEATURE_SET_PM_ENABLED=1
E: ID_ATA_FEATURE_SET_PUIS=1
E: ID_ATA_FEATURE_SET_PUIS_ENABLED=0
E: ID_ATA_FEATURE_SET_SECURITY=1
E: ID_ATA_FEATURE_SET_SECURITY_ENABLED=0
E: ID_ATA_FEATURE_SET_SECURITY_ENHANCED_ERASE_UNIT_MIN=65628
E: ID_ATA_FEATURE_SET_SECURITY_ERASE_UNIT_MIN=65628
E: ID_ATA_FEATURE_SET_SMART=1
E: ID_ATA_FEATURE_SET_SMART_ENABLED=1
E: ID_ATA_ROTATION_RATE_RPM=5400
E: ID_ATA_SATA=1
E: ID_ATA_SATA_SIGNAL_RATE_GEN1=1
E: ID_ATA_SATA_SIGNAL_RATE_GEN2=1
E: ID_ATA_WRITE_CACHE=1
E: ID_ATA_WRITE_CACHE_ENABLED=1
E: ID_BUS=ata
E: ID_FS_TYPE=ntfs
E: ID_FS_USAGE=filesystem
E: ID_FS_UUID=68D2C485D2C45948
E: ID_FS_UUID_ENC=68D2C485D2C45948
E: ID_MODEL=WDC_WD5000LPCX-60VHAT0
E: ID_MODEL_ENC=WDC\x20WD5000LPCX-60VHAT0\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20
E: ID_PART_ENTRY_DISK=8:64
E: ID_PART_ENTRY_FLAGS=0x80
E: ID_PART_ENTRY_NUMBER=1
E: ID_PART_ENTRY_OFFSET=4096
E: ID_PART_ENTRY_SCHEME=dos
E: ID_PART_ENTRY_SIZE=209719296
E: ID_PART_ENTRY_TYPE=0x7
E: ID_PART_ENTRY_UUID=a342b05c-01
E: ID_PART_TABLE_TYPE=dos
E: ID_PART_TABLE_UUID=a342b05c
E: ID_PATH=platform-xhci-hcd.0.auto-usb-0:1:1.0-scsi-0:0:0:0
E: ID_PATH_TAG=platform-xhci-hcd_0_auto-usb-0_1_1_0-scsi-0_0_0_0
E: ID_REVISION=01.01A01
E: ID_SERIAL=WDC_WD5000LPCX-60VHAT0_WD-WXU1E776JT62
E: ID_SERIAL_SHORT=WD-WXU1E776JT62
E: ID_TYPE=disk
E: ID_WWN=0x50014ee608107338
E: ID_WWN_WITH_EXTENSION=0x50014ee608107338
E: MAJOR=8
E: MINOR=65
E: PARTN=1
E: SUBSYSTEM=block
E: USEC_INITIALIZED=638175243
```

经过对比，可以找到 USB 硬盘和 U 盘还是很多差异属性，为了能兼容这一类的 USB 硬盘，我选择这个参数：`ID_BUS=ata`，因此参考默认配置，添加这一行：

```bash
KERNEL=="sd*", ENV{ID_BUS}=="ata", RUN+="/usr/share/usbmount/usbmount add usb"
```

### 4. 测试

```bash
udevadm control --reload
udevadm trigger --action=add /sys/class/block/sde1
```

确认可以正常加载，之后重启系统再测试，确认功能正常即可。

## 总结

通过本次对 udev 规则的分析和调试，我们成功解决了 USB 硬盘无法自动挂载的问题，以后如果遇到类型问题，关键是通过`udevadm info`对比属性差异，针对性扩展规则即可解决此类问题。