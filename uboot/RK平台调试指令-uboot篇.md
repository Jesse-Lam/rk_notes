---
id: 1761638254798339
---
# RK平台调试指令-uboot篇


在RK平台嵌入式开发中，U-Boot作为引导程序，其调试依赖一系列专用指令。这些指令可快速定位硬件交互、固件加载、设备树配置等问题。本文整理了RK平台U-Boot调试的核心指令，涵盖内存操作、外设调试、系统状态查询等场景，并附实用示例与配置方法。

## 一、串口快捷操作
开机时长按以下组合键可触发特定功能，为调试和烧写提供便利：
```shell
ctrl+c：进入U-Boot命令行模式（调试核心入口）
ctrl+d：进入loader烧写模式（固件烧录）
ctrl+b：进入maskrom烧写模式（底层硬件烧录）
ctrl+f：进入fastboot模式（快速调试与升级）
```

## 二、内存操作指令
内存操作是U-Boot调试的基础，用于验证地址读写、固件加载地址正确性等场景。

### 1. `md`：读取内存数据
**功能**：按指定单位（字节/字/长字/四字）读取并打印内存地址内容。  
**用法**：`md [.b, .w, .l, .q] 地址 [数据数量]`  
- `.b`：1字节；
- `.w`：2字节；
- `.l`：4字节；
- `.q`：8字节  

**示例**：  
查看0x76000000开始的16个长字数据（验证内存数据完整性）：  
```bash
=> md.l 0x76000000 0x10
76000000: fffffffe ffffffff ffffffff ffffffff ................
76000010: ffffffdf ffffffff feffffff ffffffff ................
```

### 2. `mw`：写入内存数据
**功能**：向指定内存地址批量写入数据。  
**用法**：`mw [.b, .w, .l, .q] 地址 数据 [数量]`  

**示例**：  
向0x76000000写入长字数据0xffff1234并验证：  
```bash
=> mw.l 0x76000000 0xffff1234
=> md.l 0x76000000 1  # 验证写入结果
76000000: ffff1234 ................
```

### 3. `iomem`：通过设备树读寄存器
**功能**：基于设备树兼容属性（compatible）直接读取硬件寄存器，无需手动计算地址。  
**用法**：`iomem <compatible关键词> <起始偏移> <结束偏移>`  

**示例**：  
读取RK3568平台GRF寄存器0x00-0x1c内容（快速定位寄存器配置问题）：  
```bash
=> iomem -grf 0x0 0x1c
rockchip,rk3568-grf:
fdc60000:  00000000 00000000 00000000 00001111 
fdc60010:  00001111 00001111 00000000 00001110
```

## 三、I2C设备调试指令
I2C是外设常用通信协议，以下指令可直接操作I2C设备（如传感器、PMIC）。

### 1. `i2c dev`：切换I2C总线
**功能**：指定当前操作的I2C总线编号。  
**用法**：`i2c dev [总线编号]`  

**示例**：  
切换到I2C总线0（后续操作默认在此总线上执行）：  
```bash
=> i2c dev 0
Setting bus to 0
```

### 2. `i2c md`：读取I2C设备寄存器
**功能**：读取指定I2C设备的寄存器数据。  
**用法**：`i2c md <设备地址> <寄存器地址> [.0, .1, .2] [数据数量]`  
- 设备地址：7位I2C地址（无需左移）  

**示例**：  
读取I2C设备（地址0x1b）寄存器0x2e开始的32字节（验证传感器数据是否正常）：  
```bash
=> i2c md 0x1b 0x2e 0x20
002e: 11 0f 00 00 11 0f 00 00 01 00 00 00 09 00 00 0c ................
003e: 00 0a 0a 0c 0c 0c 00 07 07 0a 00 0c 0c 00 00 00 ................
```

### 3. `i2c mw`：写入I2C设备寄存器
**功能**：向I2C设备指定寄存器写入数据。  
**用法**：`i2c mw <设备地址> <寄存器地址> <数据> [数量]`  

**示例**：  
向I2C设备（地址0x1b）寄存器0x2e写入0x10并验证：  
```bash
=> i2c mw 0x1b 0x2e 0x10
=> i2c md 0x1b 0x2e 1  # 验证写入结果
002e: 10 ................
```

## 四、GPIO调试指令
GPIO用于硬件交互（如按键、LED、外设复位），以下指令可直接控制引脚状态。

### 1. `gpio status`：查看GPIO状态
**功能**：显示GPIO的输入/输出模式、电平值及关联设备。  
**用法**：`gpio status [-a] [<bank> | <pin>]`  
- `-a`：显示所有GPIO；
- `<bank>`：指定GPIO组（如gpio0）；
- `<pin>`：指定引脚（如gpio05）  

**示例**：  
查看RK3568平台GPIO05状态（验证外设控制引脚是否正常）：  
```bash
=> gpio status gpio05   
Bank gpio0:
gpio05: output: 0 [x] vcc5v0-otg-regulator.gpio  # 输出低电平，关联OTG电源
```

### 2. `gpio input/set/clear/toggle`：控制GPIO状态
**功能**：设置GPIO为输入、输出高低电平或切换状态。  
**用法**：  
- `gpio input <pin>`：设为输入  
- `gpio set <pin>`：输出高电平  
- `gpio clear <pin>`：输出低电平  
- `gpio toggle <pin>`：切换电平  

**示例**：  
控制GPIO05电平（验证外设复位逻辑）：  
```bash
=> gpio set gpio05    # 输出高电平
gpio: pin gpio05 (gpio 5) value is 1
=> gpio toggle gpio05 # 切换为低电平
gpio: pin gpio05 (gpio 5) value is 0
```

## 五、设备树（DTB）调试指令
设备树描述硬件配置，以下指令用于验证和修改节点配置，确保硬件设备正确被系统识别和使用。

### 1. `fdt addr`：指定设备树地址
**功能**：设置当前操作的设备树（DTB）在内存中的地址，后续所有设备树操作都将基于此地址进行。  
**用法**：`fdt addr [-c] <地址> [<长度>]`  
- `-c`：指定操作的是控制设备树  
- `<地址>`：设备树在内存中的起始地址  
- `<长度>`：可选参数，指定设备树的大小  

**示例**：  
指定设备树地址为0x08300000，后续设备树操作将基于此地址（如不执行，以默认地址操作）：  
```bash
=> fdt addr 0x08300000
```

### 2. `fdt print`：打印设备树内容
**功能**：递归打印指定路径的设备树节点及其属性，用于验证节点是否正确加载和配置。  
**用法**：`fdt print <路径> [属性]`  
- `<路径>`：设备树节点的绝对路径  
- `[属性]`：可选参数，指定需要打印的特定属性  

**示例**：  
打印uart2节点（路径为/serial@fe650000）的配置信息，验证串口硬件配置：  
```bash
=> fdt print /serial@fe650000
No FDT memory address configured. Default at 0x08300000
serial@fe650000 {
        compatible = "rockchip,rk3568-uart", "snps,dw-apb-uart";
        reg = <0x00000000 0xfe650000 0x00000000 0x00000100>;
        interrupts = <0x00000000 0x00000075 0x00000004>;
        clocks = <0x00000023 0x0000011f 0x00000023 0x0000011c>;
        clock-names = "baudclk", "apb_pclk";
        reg-shift = <0x00000002>;
        reg-io-width = <0x00000004>;
        dmas = <0x00000046 0x00000002 0x00000046 0x00000003>;
        pinctrl-names = "default";
        pinctrl-0 = <0x00000107>;
        status = "disabled";
        phandle = <0x000001e6>;
};
```

### 3. `fdt set`：修改设备树属性
**功能**：修改设备树中指定节点的属性值，常用于动态调整硬件配置（如启用/禁用设备）。  
**用法**：`fdt set <路径> <属性> <值>`  
- `<路径>`：设备树节点的绝对路径  
- `<属性>`：需要修改的属性名称  
- `<值>`：属性的新值  

**示例**：  
启用uart2节点（将status属性从"disabled"修改为"okay"）：  
```bash
=> fdt set /serial@fe650000 status okay
```

修改后再次打印节点信息，验证配置是否生效：  
```bash
=> fdt print /serial@fe650000          
serial@fe650000 {
        compatible = "rockchip,rk3568-uart", "snps,dw-apb-uart";
        reg = <0x00000000 0xfe650000 0x00000000 0x00000100>;
        interrupts = <0x00000000 0x00000075 0x00000004>;
        clocks = <0x00000023 0x0000011f 0x00000023 0x0000011c>;
        clock-names = "baudclk", "apb_pclk";
        reg-shift = <0x00000002>;
        reg-io-width = <0x00000004>;
        dmas = <0x00000046 0x00000002 0x00000046 0x00000003>;
        pinctrl-names = "default";
        pinctrl-0 = <0x00000107>;
        status = "okay";  // 已成功修改为启用状态
        phandle = <0x000001e6>;
};
```

通过`fdt set`可以灵活调整设备树配置，无需重新编译DTB文件即可测试不同的硬件参数设置，修改之后执行`boot`即可使用最新的配置开机运行，注意是单次有效，重启后修改无效。
## 六、MMC/SD设备调试指令
MMC（eMMC/SD卡）是主要存储介质，以下指令用于验证存储设备功能。

### 1. `mmc info`：查看MMC设备信息
**功能**：显示当前MMC设备的制造商、容量、速度等信息。  
**用法**：`mmc info`  

**示例**：  
查看eMMC设备信息（验证存储设备是否正常识别）：  
```bash
=> mmc info
Device: sdhci@fe310000
Manufacturer ID: 15
OEM: 100
Name: BJTD4 
Timing Interface: HS200
Tran Speed: 200000000
Rd Block Len: 512
MMC version 5.1
High Capacity: Yes
Capacity: 29.1 GiB
Bus Width: 8-bit
Erase Group Size: 512 KiB
HC WP Group Size: 8 MiB
User Capacity: 29.1 GiB WRREL
Boot Capacity: 4 MiB ENH
RPMB Capacity: 4 MiB ENH
```

### 2. `mmc dev`：切换MMC设备
**功能**：指定当前操作的MMC设备（如eMMC为0，SD卡为1）。  
**用法**：`mmc dev <设备编号>`  

**示例**：  
切换到SD卡（设备1）：  
```bash
=> mmc dev 1
switch to partitions #0, OK
mmc1 is current device
```

### 3. `mmc read/write/erase`：读写/擦除MMC数据
**功能**：直接操作MMC块数据，验证存储介质可靠性。  
**用法**：  
- `mmc read <内存地址> <块编号> <块数量>`  
- `mmc write <内存地址> <块编号> <块数量>`  
- `mmc erase <块编号> <块数量>`  

**示例**：  
读取MMC第0块数据到内存0x70000000（验证存储数据完整性）：  
```bash
=> mmc read 0x70000000 0 1
=> md.l 0x70000000 1  # 查看读取结果
70000000: 00000000 ................
```

## 七、USB调试指令
USB用于外接设备（U盘、网卡等），以下指令用于调试USB功能。

### 1. `rockusb`：进入RockUSB烧写模式
**功能**：启动RockUSB协议，通过USB烧写固件（支持eMMC/Nand等介质）。  
**用法**：`rockusb <USB控制器> <设备类型> <设备[:分区]>`  

**示例**：  
通过USB控制器0烧写eMMC设备0：  
```bash
=> rockusb 0 mmc 0
RKUSB: LUN 0, dev 0, hwpart 0, sector 0x0, count 0x3a3e000
```

### 2. `usb start/reset`：初始化/重置USB控制器
**功能**：`usb start`初始化控制器并扫描设备；`usb reset`重置控制器并重新扫描。  
**用法**：  
- `usb start [控制器编号]`  
- `usb reset [控制器编号]`  

**示例**：  
初始化USB控制器0并扫描设备：  
```bash
=> usb start
starting USB...
USB0: USB EHCI 1.00
scanning bus 0 for devices... 2 USB Device(s) found
       scanning usb for storage devices... 1 Storage Device(s) found
```

### 3. `usb tree/info/dev`：查看/切换USB设备
- `usb tree`：显示USB设备层级关系（验证设备枚举）；  
- `usb dev <编号>`：切换当前USB存储设备；  
- `usb info`：查看当前USB设备信息。  

**示例**：  
查看USB设备树并切换设备：  
```bash
=> usb tree
USB device tree:
  1  Hub (0x0000:0x0000)
    |
    +- 2  Mass Storage (0x1234:0x5678)  # U盘设备
=> usb dev 2  # 切换到该U盘
switched to usb storage device 2
```

## 八、系统状态调试指令
用于排查启动卡死、驱动异常等问题，查看系统整体状态。

### 1. `dm tree`：查看设备驱动绑定状态
**功能**：显示设备与驱动的绑定关系及探针（probe）状态，验证驱动是否加载。  
**用法**：`dm tree`  

**示例**：  
查看驱动加载状态（`[ + ]`表示探针成功）：  
```bash
=> dm tree
Class     Probed  Driver                Name
serial    [ + ]   ns16550_serial        |-- serial@11030000  # 串口驱动加载成功
mmc       [ + ]   rockchip_rk3288_dw_mshc |-- dwmmc@30020000*
```

### 2. `bidram_dump`/`sysmem_dump`：内存块管理信息
**功能**：  
- `bidram_dump`：显示系统总内存及预留块（如ATF、OPTEE占用）；  
- `sysmem_dump`：显示内核可见内存及固件（U-Boot、kernel）占用块。  

**用法**：命令行调用或开机按`ctrl+m`打印。  

**示例**：  
排查内存重叠问题（如KERNEL与RAMDISK地址冲突）：  
```bash
sysmem_dump_all:
memory.total = 0x7e000000 (2016 MiB)
allocated.rgn[0].name = "U-Boot" 0x71dd6140 - 0x80000000
allocated.rgn[1].name = "KERNEL" 0x80080000 - 0x88000000
```

## 九、U-Boot调试指令配置方法
U-Boot的调试指令并非默认全部开启，需在编译配置阶段通过`Kconfig`选项启用对应功能。步骤如下：

### 1. 进入配置界面
在U-Boot源码目录执行：  
```bash
make menuconfig
```

### 2. 核心配置项（路径：`Command line interface`）
| 功能     | 配置项               | 包含指令                      | 依赖项                                     |
| ------ | ----------------- | ------------------------- | --------------------------------------- |
| 内存操作   | `CONFIG_CMD_MEM`  | `md`、`mw`、`iomem`         | -                                       |
| I2C调试  | `CONFIG_CMD_I2C`  | `i2c dev`、`i2c md`等       | `CONFIG_DM_I2C`、平台I2C驱动                 |
| GPIO调试 | `CONFIG_CMD_GPIO` | `gpio status`、`gpio set`等 | `CONFIG_DM_GPIO`、`CONFIG_ROCKCHIP_GPIO` |
| 设备树调试  | `CONFIG_CMD_FDT`  | `fdt addr`、`fdt print`    | -                                       |
| MMC调试  | `CONFIG_CMD_MMC`  | `mmc info`、`mmc read`等    | `CONFIG_DWMMC`、平台MMC驱动                  |
| USB调试  | `CONFIG_CMD_USB`  | `usb start`、`rockusb`等    | `CONFIG_CMD_USB_STORAGE`（存储支持）          |
| 驱动状态   | `CONFIG_CMD_DM`   | `dm tree`                 | -                                       |

### 3. 配置生效
1. 保存配置（默认存为`.config`）；
2. 生成defconfig，替换系统的defconfig
```bash
make savedefconfig
mv defconfig configs/rk3568_defconfig
```
3. 重新编译U-Boot，并烧录新镜像后即可使用配置的指令。  

## 总结
RK平台U-Boot的调试指令覆盖了内存、I2C、GPIO、设备树、存储设备、USB等核心场景。通过这些指令，开发者可快速缩小问题范围，从软件配置到硬件交互进行全链路验证。