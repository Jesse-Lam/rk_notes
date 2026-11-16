---
id: 1761638255228332
---
# 初试DeepSeek写代码体验

## 前言

最近，DeepSeek 在网络上掀起了一股热潮，无论是技术论坛、社交媒体，还是开发者社区，几乎都能看到它的身影。作为一个嵌入式软件工程师，我也想要亲身体验一下 DeepSeek 的能力。

恰好，我心里一直想做一个 USB HID 设备的相关的小项目，想做但又懒得动手去写。于是，我萌生了一个想法：为什么不试试让 DeepSeek 来帮我完成这个任务呢？

择日不如撞日，这就开始吧！

## 目标

我的这个小项目，最终的目标是实现我的嵌入式系统设备作为 USB 键盘鼠标的桥接设备。嵌入式系统的 USB HOST 口接键盘鼠标，嵌入式系统的 USB OTG 口连接 PC，键盘鼠标可以透过嵌入式系统直接操作 PC。

为了实现这个目标，我将从最简单的功能开始实现，在这里，我只要 DeepSeek 帮我写代码实现把嵌入式系统配置成一个 HID 设备即可。

## 实现过程

### 描述需求，生成代码

我向 DeepSeek 描述了我的需求：

> 在基于 Linux 的嵌入式系统上，我需要配置一个 USB HID 设备，使其模拟键盘输入。我希望通过 Linux 的 ConfigFS 接口动态配置 USB Gadget，并用 C 语言自动完成所有必要的设置。
> 

DeepSeek 直接返回了完整的代码，包括实现步骤和编译指令。这让我非常惊讶，不仅代码结构清晰，甚至考虑到了系统配置的细节和代码注释。为了减少篇幅，以下是代码截图。

![deepseek实现hid.png](初试DeepSeek写代码体验.assets/deepseek%E5%AE%9E%E7%8E%B0hid.png)

### 代码移植到 RK3576 平台

为了验证 DeepSeek 生成的代码是否可用，我决定将其移植到 RK3576 平台的 Buildroot SDK。整个移植过程主要分为三步：

**第一步：配置 kernel**

要实现 HID 设备，嵌入式系统的 kernel 必须有配置 HID 设备相关的选项才能正常工作，Gadget HID 的配置是 `CONFIG_USB_CONFIGFS_F_HID=y`

**第二步：放置代码到合适的目录**

参考 SDK 内部已有的代码示例（如 `io.c`），我将测试代码 `hid_bridging.c` 放在 `external/rktoolkit/` 目录下。

**第三步：修改编译脚本**

为了确保代码能正确编译并链接，我修改了两处文件：

**修改 `rktoolkit.mk`**

```
# 在 buildroot/package/rockchip/rktoolkit/rktoolkit.mk 添加：
define RKTOOLKIT_BUILD_HIDBRIDGING
    $(TARGET_CC) $(RKTOOLKIT_CFLAGS) $(TARGET_LDFLAGS) $(@D)/hid_bridging.c \
        -o $(@D)/hid_bridging
endef
RKTOOLKIT_POST_BUILD_HOOKS += RKTOOLKIT_BUILD_HIDBRIDGING

define RKTOOLKIT_INSTALL_HIDBRIDGING
    $(INSTALL) -D -m 755 $(@D)/hid_bridging $(TARGET_DIR)/usr/bin/hid_bridging
endef
RKTOOLKIT_POST_INSTALL_TARGET_HOOKS += RKTOOLKIT_INSTALL_HIDBRIDGING
```

**修改 `Makefile`**

```
all: io hid_bridging update vendor_storage sample_vendor_lib minimad

hid_bridging:
    $(CC) -c $(PROJECT_DIR)/hid_bridging.c
    $(CC) -o $(PROJECT_DIR)/hid_bridging $(PROJECT_DIR)/hid_bridging.o

clean:
    rm -rf $(PROJECT_DIR)/hid_bridging $(PROJECT_DIR)/hid_bridging.o

install:
    install -D -m 755 $(PROJECT_DIR)/hid_bridging $(DESTDIR)/usr/bin/
```

经过上面的移植，发现竟然完全不需要手动修改就能编译通过，也是第一次领略到了 AI 的强大。编译完固件，为了不受系统默认的 USB 初始化脚本影响，我把板子里面的脚本usbdevice直接删除掉，然后重启系统并执行 hid_bridging 即可完美运行。

### 调试与优化

虽然 DeepSeek 生成的代码功能完整，但在实际运行中，仍然需要人工调试和优化。以下是我遇到的两个典型问题及解决方案：

**问题 1：UDC 配置错误**

DeepSeek 生成的代码默认使用通用的 UDC（USB Device Controller）地址，但 RK3576 平台的 UDC 地址可能不同，因此需要手动修改以匹配具体硬件。

**问题 2：符号链接路径错误**

DeepSeek 使用相对路径创建符号链接，如：

```
symlink("../../../../usb_gadget/mygadget/functions/hid.usb0", path);
```

然而，这种路径在某些环境下无效，导致程序运行失败。最终，我将其修改为绝对路径，成功解决了问题。

### 运行效果

经过调试和优化后，代码成功运行，嵌入式设备被 PC 正确识别为 USB HID 键盘，并且可以向 PC 发送数据。

## 总结

现在市场上的 AI 种类有很多，其他平台我还没去验证测试，但是在这次使用之后发现 AI 在代码生成方面表现还是很优异的，能快速提供高质量的实现方案。但是，在实际项目中，仍然需要开发者进行调试和优化，以确保代码适配具体的硬件和系统环境。AI 工具能大幅提升开发效率，但软件工程师的经验还是不可或缺的。希望我们没那么快并取代吧！