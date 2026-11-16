---
id: 1761638254234348
---
# Buildroot之Overlay使用

## 前言

在《[USB 硬盘自动挂载](https://mp.weixin.qq.com/s/olnulO7Pn5wN1H26JSGT9A)》文章中我通过修改 `/usr/lib/udev/rules.d/usbmount.rules` 完成了调试。我调试的时候是在开发板上操作的，调试完成之后如何把修改同步到 SDK 代码中呢？针对这个问题，我首先去 SDK 搜索一番，发现 SDK 并没有这个文件，这个文件是 usbmount 模块自带的。根据以往的调试经验，我只有两个选择：一是去修改 usbmount 这个模块的代码；二是通过 Overlay 来覆写系统配置文件。由于对 usbmount 这个模块的开发流程不了解，我选择使用 Overlay 来处理，本文将介绍 Overlay 的原理和调试过程。

## Overlay 功能概述

Buildroot 的 Overlay 功能是一种强大的定制化机制，允许开发者在不修改 Buildroot 内部包定义的情况下，对生成的根文件系统进行深度定制。通过在构建过程中覆盖或添加文件，开发者可以轻松实现：

- 自定义配置文件
- 添加预编译的二进制文件
- 修改默认系统行为
- 部署自定义脚本和服务

## Overlay 的工作原理

Buildroot 的 Overlay 机制在构建过程的特定阶段执行，具体流程如下：

1. 构建流程中的位置：
    - 在所有软件包安装完成后执行
    - 在文件系统镜像生成之前执行
    - 在执行 post-build 脚本之前执行
2. 技术实现：
    
    ```bash
    buildroot/board/rockchip/common/post-build.sh
    OVERLAYS="$(dirname "$0")/overlays"
    for dir in $(ls "$OVERLAYS"); do
            OVERLAY_DIR="$OVERLAYS/$dir"
            if [ -x "$OVERLAY_DIR/prepare.sh" ] && \
                    ! "$OVERLAY_DIR/prepare.sh" "$TARGET_DIR"; then
                    echo ">>> Ignored $OVERLAY_DIR"
                    continue
            fi  
    
            echo ">>> Copying $OVERLAY_DIR"
            rsync -av --chmod=u=rwX,go=rX --exclude .empty --exclude /prepare.sh \
                    "$OVERLAY_DIR/" "$TARGET_DIR/"
    done
    ```
    
    使用 rsync 命令确保：
    - 保留文件权限（--chmod）
    - 排除版本控制文件和临时文件
    - 保持目录结构完整性

## 配置和使用方法

### 基础配置

1. 通过 menuconfig 配置：
    
    ```xml
    System configuration → Root filesystem overlay directories
    ```
    
2. 直接修改 .config 文件：
    
    ```bash
    BR2_ROOTFS_OVERLAY="/path/to/overlay1 /path/to/overlay2"
    ```
    

### 目录结构示例

典型的 overlay 目录结构应镜像目标根文件系统：

```
my_overlay/
├── etc/
│   ├── network/
│   │   └── interfaces
│   └── shadow
├── home/
│   └── user/
│       └── .bashrc
└── usr/
    └── local/
        └── bin/
            └── my_script
```

## 调试过程

### 查看当前配置

这里以 RK3576 的 SDK 为例，已知 Overlay 的宏为 `BR2_ROOTFS_OVERLAY`，Buildroot 编译生成的 .config 存放到 `buildroot/output/rockchip_rk3576/` 目录下，因此用 grep 搜索确认当前的配置：

```bash
$ grep "BR2_ROOTFS_OVERLAY" buildroot/output/rockchip_rk3576/.config
BR2_ROOTFS_OVERLAY="board/rockchip/common/base board/rockchip/rk3576/fs-overlay/"
```

### 确认当前目录结构

```bash
$ tree buildroot/board/rockchip/common/base/ buildroot/board/rockchip/rk3576/fs-overlay/
buildroot/board/rockchip/common/base/
└── busybox.fragment
buildroot/board/rockchip/rk3576/fs-overlay/

0 directories, 0 files
```

发现 Overlay 目录下只有一个文件，因此只能自己根据需要来创建对应的目录。

### 创建目录并内置文件

```bash
$ mkdir -p buildroot/board/rockchip/rk3576/fs-overlay/usr/lib/udev/rules.d/
$ cp ~/tmp/usbmount.rules buildroot/board/rockchip/rk3576/fs-overlay/usr/lib/udev/rules.d/
$ tree buildroot/board/rockchip/rk3576/fs-overlay/
buildroot/board/rockchip/rk3576/fs-overlay/
└── usr
    └── lib
        └── udev
            └── rules.d
                └── usbmount.rules

4 directories, 1 file
```

### 编译生成固件

编译过程可以看到下面的日志

```bash
2025-06-18T06:59:25 >>>   Finalizing host directory
2025-06-18T06:59:25 >>>   Finalizing target directory
2025-06-18T07:00:21 >>>   Sanitizing RPATH in target tree
2025-06-18T07:00:25 >>>   Sanity check in overlay board/rockchip/common/base
2025-06-18T07:00:25 >>>   Sanity check in overlay board/rockchip/rk3576/fs-overlay/
2025-06-18T07:00:25 >>>   Copying overlay board/rockchip/common/base
2025-06-18T07:00:25 >>>   Copying overlay board/rockchip/rk3576/fs-overlay/
2025-06-18T07:00:30 >>>   Executing post-build script board/rockchip/common/post-build.sh
```

确认修改的文件能更新到固件即可。

## 总结

Buildroot 的 Overlay 功能提供了灵活的文件系统定制方案，通过合理使用 Overlay 功能，开发者可以高效地创建满足特定需求的系统镜像，同时保持构建系统的整洁和可维护性。