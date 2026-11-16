---
id: 1761638254533343
---
# RK平台内核USB配置指南

在嵌入式开发中，USB模块的配置是基础且必要的环节。无论是连接U盘、键鼠，还是调试USB外设，都需要正确配置内核中的USB相关选项。本文从内核基础配置到PHY、Host、Gadget，再到各类外设驱动的配置选项，提供详细的说明。

## 一、内核USB配置基础操作

USB模块的配置与其他内核模块类似，需完成基础配置的导入、修改和保存。以arm64架构芯片为例，步骤如下：

### 1. 导入默认配置

首先加载芯片对应的默认配置，例如RK平台常用的`rockchip_defconfig`：

```bash
make ARCH=arm64 rockchip_defconfig
```

### 2. 进入配置界面

使用`menuconfig`打开图形化配置界面，后续的USB相关选项都在此处修改：

```bash
make ARCH=arm64 menuconfig
```

### 3. 保存配置

修改完成后请务必保存配置。可先保存为`defconfig`格式：

```bash
make ARCH=arm64 savedefconfig
```

若希望替换默认配置（例如下次直接使用修改后的配置），可将生成的`defconfig`文件替换原有的`rockchip_defconfig`。

## 二、USB PHY配置

USB PHY是USB信号的物理层实现，不同RK芯片使用的PHY IP不同，需根据型号选择正确的驱动。

**配置路径**：

```
Device Drivers  --->
	PHY Subsystem  --->
		...
		<*> Rockchip INNO USB2PHY Driver
		...
		<*> Rockchip NANENG USB2PHY Driver
		...
		<*> Rockchip NANENG COMBO PHY Driver
		...
		<*> Rockchip TYPEC PHY Driver
		...
		<*> Rockchip INNO USB 3.0 PHY Driver
		...
		<*> Rockchip USBDP COMBO PHY Driver
```

- **RK3399、RK3588、RK3568**等USB 2.0 PHY使用Innosilicon IP，应选择`Rockchip INNO USB2PHY Driver`。
- **RV1126** USB 2.0 PHY使用NANENG IP，应选择`Rockchip NANENG USB2PHY Driver`。
- **RK3568、RK3576、RK3562**等USB 3.0 PHY使用NaNeng IP，应选择`Rockchip NANENG COMBO PHY Driver`。
- **RK3399** USB 3.0 PHY使用TYPEC PHY，应选择`Rockchip TYPEC PHY Driver`。
- **RK3328** USB 3.0 PHY使用Innosilicon USB 3.0 PHY，应选择`Rockchip INNO USB 3.0 PHY Driver`。
- **RK3588** USB 3.0 PHY使用USB3.0/DP combo PHY（Samsung IP），应选择`Rockchip USBDP COMBO PHY Driver`。

## 三、USB Host配置

USB Host使芯片作为“主机”连接外设（如U盘、键盘），需根据USB版本选择正确的驱动。

```
Device Drivers  --->
	-*- Support for Host-side USB
	[*] USB support  --->
		...
		<*> xHCI HCD (USB 3.0) support
		-*- Generic xHCI driver for a platform device
		...
		<*> EHCI HCD (USB 2.0) support
		[ ]   Root Hub Transaction Translators
		[*]   Improved Transaction Translator scheduling
		<*> Generic EHCI driver for a platform device
		...
		<*> OHCI HCD (USB 1.1) support
		< >   OHCI support for PCI-bus USB controllers
		<*>   Generic OHCI driver for a platform device
```

### 1. 基础必选选项

首先打开Host功能的总开关，包括：

- 勾选`-*- Support for Host-side USB`（Host功能总开关，必须选择）；
- 勾选`[*] USB support --->`（USB基础支持，选择后才能看到细分驱动）。

### 2. 按USB版本选择驱动

在`USB support`子菜单中，根据版本选择对应驱动：

- **USB 1.1**：选择`<*> OHCI HCD (USB 1.1) support`，并勾选`<*> Generic OHCI driver for a platform device`；
- **USB 2.0**：选择`<*> EHCI HCD (USB 2.0) support`，并勾选`<*> Generic EHCI driver for a platform device`；
- **USB 3.0**：选择`<*> xHCI HCD (USB 3.0) support`，并勾选`-*- Generic xHCI driver for a platform device`。

## 四、USB OTG与Gadget配置

除了“主机模式”，某些场景需要芯片作为“设备”（例如连接电脑调试），此时需配置OTG（双向模式）和Gadget（设备功能）。

### 1. USB OTG配置

OTG支持“主机/设备”模式切换，配置路径如下：

```
Device Drivers  --->
	-*- Support for Host-side USB
	[*] USB support  --->
		...
		<*> DesignWare USB2 DRD Core Support
			DWC2 Mode Selection (Dual Role mode)
		...
		<*> DesignWare USB3 DRD Core Support
			DWC3 Mode Selection (Dual Role mode)
```

- 勾选`<*> DesignWare USB2 DRD Core Support`（USB 2.0双向模式），子选项选择“Dual Role mode”；
- 勾选`<*> DesignWare USB3 DRD Core Support`（USB 3.0双向模式），子选项选择“Dual Role mode”。

### 2. USB Gadget配置

Gadget是“设备模式”的功能实现（例如模拟U盘、串口），Rockchip默认支持多种功能，可按需勾选。

```
Device Drivers  --->
	[*] USB support  --->
		[*] USB Gadget Support  --->
			...
			USB Gadget Drivers (USB functions configurable through configfs)  --->
				[ ] Generic serial bulk in/out
				[*] Abstract Control Model (CDC ACM)
				[ ] Object Exchange Model (CDC OBEX)
				[ ] Network Control Model (CDC NCM)
				[ ] Ethernet Control Model (CDC ECM)
				[ ] Ethernet Control Model (CDC ECM) subset
				[*] RNDIS
				[ ] Ethernet Emulation Model (EEM)
				[*] Mass storage
				[ ] Loopback and sourcesink function (for testing)
				[*] Function filesystem (FunctionFS)
				[*] MTP gadget
				[*] PTP gadget
				[*] Accessory gadget
				[*] Audio Source gadget
				[*] Uevent notification of Gadget state
				[ ] Audio Class 1.0
				[ ] Audio Class 2.0
				[*] MIDI function
				[ ] HID function
				[ ] USB Webcam function
				[ ] Printer function
```

RK平台默认支持RNDIS、MTP、PTP、Accessory、ADB、MIDI、Audio等功能，开发者可根据实际产品需求启用更多USB Gadget功能。

## 五、USB外设配置

完成基础模块配置后，还需根据具体外设启用对应驱动。常见外设的配置步骤如下：

### 1. U盘（Mass Storage Class）

U盘属于SCSI设备，需先启用SCSI支持，再启用USB存储驱动。

- **第一步：配置SCSI**

```
Device Drivers --->
	SCSI device support --->
		<*> SCSI device support
		[ ] SCSI: use blk-mq I/O path by default
		[*] legacy /proc/scsi/ support
			*** SCSI support type (disk, tape, CD-ROM) ***
		<*> SCSI disk support
		< > SCSI tape support
		< > SCSI OnStream SC-x0 tape support
		< > SCSI CDROM support
		<*> SCSI generic support
		<*> SCSI media changer support
		[*] Verbose SCSI error reporting (kernel size +=75K)
		[*] SCSI logging facility
		[*] Asynchronous SCSI scanning
			SCSI Transports  --->
		[*] SCSI low-level drivers  --->
		[ ] PCMCIA SCSI adapter support  ----
		[ ] SCSI Device Handlers  ----
```

- **第二步：配置USB存储**

```
Device Drivers --->
	[*] USB support  --->
		<*> USB Mass Storage support
```

### 2. USB 3G Modem（含PPP拨号）

3G模块本质是“USB转串口”，需启用串口驱动和PPP拨号支持。

- **第一步：启用串口驱动**

```
Device Drivers --->
	[*] USB support  --->
		<*> USB Serial Converter support  --->
			<*> USB driver for GSM and CDMA modems
```

- **第二步：启用PPP拨号**

```
Device Drivers --->
	[*] Network device support  --->
		<*> PPP (point-to-point protocol) support
			<*> PPP BSD-Compress compression
			<*> PPP Deflate compression
			[*] PPP filtering
			<*> PPP MPPE compression (encryption)
			[*] PPP multilink support
			<*> PPP over Ethernet
			<*> PPP over L2TP
			<*> PPP on L2TP Access Concentrator
			<*> PPP on PPTP Network Server
			<*> PPP support for async serial ports
			<*> PPP support for sync tty ports
```

### 3. PL2303串口模块

如需使用PL2303输出数据到串口，需选择以下选项，同时**禁用**`USB driver for GSM and CDMA modems`，否则PL2303可能被误识别为USB 3G modem。

```
Device Drivers --->
	[*] USB support  --->
		<*> USB Serial Converter support  --->
			<*> USB Prolific 2303 Single Port Serial Driver
```

### 4. USB GPS

GPS设备通常使用CDC ACM协议，直接启用对应驱动即可：

```
Device Drivers --->
	[*] USB support  --->
		[*] USB Modem (CDC ACM) support
```

### 5. USB键鼠（HID设备）

USB键盘鼠标属于HID类设备，配置路径如下：

```
Device Drivers --->
	[*] HID support
		[*] USB HID transport layer
		[ ] PID device support
		[*] /dev/hiddev raw HID device support
```

### 6. USB相机（UVC相机）

常见的USB相机（如免驱摄像头）使用UVC协议，配置如下：

```
Device Drivers --->
	<*> Multimedia support  --->
		[*] Media USB Adapters  --->
			*** Webcam devices ***
			<*> USB Video Class (UVC)
			[*] UVC input events device support
```

### 7. USB音频设备

USB音箱、麦克风等设备需启用USB音频驱动：

```
Device Drivers --->
	<*> Sound card support --->
		<*> Advanced Linux Sound Architecture --->
			...
			[*] USB sound devices --->
				[*] USB Audio/MIDI driver
```

### 8. USB HUB

如需外接USB HUB扩展接口，请勿勾选“禁用HUB”选项：

```
Device Drivers --->
	[*] USB support --->
		-*- Support for Host-side USB
		...
		[ ] Disable external hubs
```

## 六、其他外设

除上述外设外，还有USB打印机、特殊传感器等设备。这类设备的配置思路如下：

- 若为“标准设备”（符合USB标准类协议）：直接在`menuconfig`中搜索设备类名（如“Printer”），勾选对应驱动即可；
- 若为“厂商定制设备”：需使用厂商提供的驱动，按驱动文档修改`Kconfig`和`Makefile`，再在`menuconfig`中勾选对应选项。

RK平台对USB外设没有特殊限制，遵循Linux通用配置流程即可。

## 参考资料
* 《Rockchip_Developer_Guide_USB_CN》