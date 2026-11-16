---
id: 1761638255037335
---
## 前言

设备树（Device Tree, DTS）在Linux内核中用于描述硬件的拓扑结构和特性。在Type-C子系统中，DTS如同一张精密的“接线图”，它向TCPM（Type-C Port Manager）框架准确传递以下硬件信息：
*   **所使用的芯片类型**（如FUSB302、HUSB311等）
*   **芯片的连接方式**（如挂载在I2C2总线）
*   **通信机制**（如中断引脚、控制引脚）
*   **连接的周边组件**（如USB PHY、DisplayPort控制器）
*   **设备支持的功能**（如供电能力、Alternate Mode）

本文将依据**数据流与功能模块**，以RK3588为例，系统性地解析这份关键的配置蓝图。

## 1. Type-C端口控制器节点

TCPC节点是Type-C配置的核心，定义了端口的控制逻辑和能力。

```dts
&i2c2 {
    status = "okay";
    usbc0: fusb302@22 {
        compatible = "fcs,fusb302"; // 驱动匹配的关键标识
        reg = <0x22>; // I2C设备地址
        interrupt-parent = <&gpio3>;
        interrupts = <RK_PB4 IRQ_TYPE_LEVEL_LOW>; // 低电平触发中断
        pinctrl-names = "default";
        pinctrl-0 = <&usbc0_int>; // 中断引脚复用配置
        vbus-supply = <&vbus5v0_typec>; // VBUS电源控制引用
        status = "okay";

        ports {
            #address-cells = <1>;
            #size-cells = <0>;
            port@0 {
                reg = <0>;
                usbc0_role_sw: endpoint@0 {
                    // 关键连接1：角色切换
                    // 连接到USB控制器，实现Host/Device（DRD）角色切换
                    remote-endpoint = <&dwc3_0_role_switch>;
                };
            };
        };

        usb_con: connector {
            compatible = "usb-c-connector";
            label = "USB-C";
            // 定义端口能力：双角色数据，双角色电源
            data-role = "dual";
            power-role = "dual";
            try-power-role = "sink"; // 初始尝试作为电源接收方
            op-sink-microwatt = <1000000>; // 最大接收功率

            // 作为Sink（设备）时，向Source宣告的功率需求列表
            // 硬件设计是关键！必须与硬件工程师确认最大耐受电压/电流
            sink-pdos = <
                PDO_FIXED(5000, 3000, PDO_FIXED_USB_COMM)
                PDO_FIXED(9000, 3000, PDO_FIXED_USB_COMM)
                PDO_FIXED(12000, 3000, PDO_FIXED_USB_COMM)
                PDO_FIXED(15000, 3000, PDO_FIXED_USB_COMM)
                PDO_FIXED(20000, 3000, PDO_FIXED_USB_COMM)
            >;

            // 作为Source（主机）时，提供的电压/电流
            source-pdos = <PDO_FIXED(5000, 3000, PDO_FIXED_USB_COMM)>;

            // 配置Alternate Mode，如DisplayPort
            altmodes {
                #address-cells = <1>;
                #size-cells = <0>;
                altmode@0 {
                    reg = <0>;
                    svid = <0xff01>; // 自定义SVID，用于与PHY通信
                    vdo = <0xffffffff>;
                };
            };

            ports {
                #address-cells = <1>;
                #size-cells = <0>;
                port@0 {
                    reg = <0>;
                    usbc0_orien_sw: endpoint {
                        // 关键连接2：正反插检测
                        // 连接到USB PHY，用于CC线极性检测与切换
                        remote-endpoint = <&usbdp_phy0_orientation_switch>;
                    };
                };
                port@1 {
                    reg = <1>;
                    dp_altmode_mux: endpoint {
                        // 关键连接3：DP AltMode多路复用
                        // 连接到USB PHY，用于切换DP信号通路
                        remote-endpoint = <&usbdp_phy0_dp_altmode_mux>;
                    };
                };
            };
        };
    };
};
```

**关键点说明**：
*   `compatible` 属性是驱动与设备节点匹配的核心依据，确保内核能够正确加载对应的TCPCI驱动。
*   `interrupt-parent` 和 `interrupts` 配置使TCPC能够通过中断机制及时通知主控状态变化。
*   `vbus-supply` 关联到VBUS控制电源，TCPC驱动通过此引用管理VBUS的供电状态。
*   `sink-pdos` 定义了设备作为功耗接收方时支持的功率规格，必须严格依据硬件设计配置。
*   `source-pdos` 定义了设备作为供电源时的输出能力。

## 2. USB控制器节点

此节点配置USB OTG控制器，使其支持双角色（DRD）功能。

```dts
&usbdrd3_0 {
    status = "okay";
};

&usbdrd_dwc3_0 {
    status = "okay";
    dr_mode = "otg"; // 必须设置为otg模式
    usb-role-switch; // 声明支持角色切换
    port {
        #address-cells = <1>;
        #size-cells = <0>;
        dwc3_0_role_switch: endpoint@0 {
            reg = <0>;
            // 与TCPC节点的角色切换端点相连
            remote-endpoint = <&usbc0_role_sw>;
        };
    };
};
```
**功能说明**：`usb-role-switch` 属性启用了内核的USB角色切换框架。当TCPC检测到连接事件并完成PD协议角色协商后，会通过此端点链路通知USB控制器切换至Host或Device模式。

## 3. USB PHY节点

PHY（物理层接口）负责信号的物理传输。RK平台（如RK3588）的USB3.0 PHY集成了Type-C方向检测和DP AltMode切换功能。

```dts
&usbdp_phy0 {
    status = "okay";
    orientation-switch; // 声明支持正反插检测
    svid = <0xff01>; // 与TCPC中altmode的svid匹配
    sbu1-dc-gpios = <&gpio4 RK_PA6 GPIO_ACTIVE_HIGH>; // SBU1用于DP AUX通道
    sbu2-dc-gpios = <&gpio4 RK_PA7 GPIO_ACTIVE_HIGH>; // SBU2用于DP HPD通道

    port {
        #address-cells = <1>;
        #size-cells = <0>;
        usbdp_phy0_orientation_switch: endpoint@0 {
            reg = <0>;
            // 与TCPC的正反插检测端点相连，接收CC极性信号
            remote-endpoint = <&usbc0_orien_sw>;
        };
        usbdp_phy0_dp_altmode_mux: endpoint@1 {
            reg = <1>;
            // 与TCPC的DP AltMode端点相连，控制信号通路切换
            remote-endpoint = <&dp_altmode_mux>;
        };
    };
};
/* 使能PHY的DP功能 */
&usbdp_phy0_dp {
    status = "okay";
};
/* 使能PHY的USB3.0功能 */
&usbdp_phy0_u3 {
    status = "okay";
};

/* 配置USB2.0 PHY */
&u2phy0 {
    status = "okay";
};
&u2phy0_otg {
    rockchip,typec-vbus-det; // 若VBUS常拉高的硬件设计，需配置此属性
    status = "okay";
};
```
**功能说明**：`orientation-switch` 和 `svid` 使PHY能够参与Type-C的方向检测和模式切换。SBU GPIOs用于在DP AltMode下传输AUX和HPD信号，符合Type-C DP AltMode的标准实现。

## 4. 显示与音频相关节点

若支持DP显示功能，需配置DisplayPort控制器及音频路由。

```dts
&dp0 {
    status = "okay";
};
/* 将DP0的输入源映射到Video Port 2 */
&dp0_in_vp2 {
    status = "okay";
};
/* 使能DP音频输出 */
&dp0_sound {
    status = "okay";
};
```
**功能说明**：此部分配置确保GPU的显示输出能正确路由至DP控制器，并同步启用音频功能。

## 5. 引脚控制与电源管理

这些配置确保硬件控制信号的正确初始化和管理。

```dts
/* 在Pinctrl节点中定义引脚功能 */
&pinctrl {
    usb-typec {
        usbc0_int: usbc0-int {
            rockchip,pins = <3 RK_PB4 RK_FUNC_GPIO &pcfg_pull_up>; // 上拉输入
        };
        typec5v_pwren: typec5v-pwren {
            rockchip,pins = <4 RK_PD0 RK_FUNC_GPIO &pcfg_pull_none>; // 推挽输出
        };
    };
};

/* 在根节点定义VBUS控制Regulator */
/ {
    vbus5v0_typec: vbus5v0-typec {
        compatible = "regulator-fixed";
        regulator-name = "vbus5v0_typec";
        regulator-min-microvolt = <5000000>;
        regulator-max-microvolt = <5000000>;
        enable-active-high;
        gpio = <&gpio4 RK_PD0 GPIO_ACTIVE_HIGH>; // 控制VBUS电源的GPIO
        vin-supply = <&vcc5v0_usb>; // 输入电源，通常为系统5V
        pinctrl-names = "default";
        pinctrl-0 = <&typec5v_pwren>; // 应用引脚配置
    };
};
```
**功能说明**：Pinctrl子系统确保GPIO在驱动加载时被初始化为正确的功能（如中断输入、电源控制输出）。Regulator框架提供了标准化的电源管理接口，TCPC驱动通过`vbus-supply`引用它来控制VBUS的开启与关闭。

## 总结

Type-C的DTS配置是一个紧密协作的链条：**TCPC** ←(角色/方向/DP信号)→ **USB PHY** ←(USB/DP数据)→ **USB/DP控制器**。

**配置要点检查清单：**
1.  **TCPC**：确保 `compatible`、`interrupts`、`vbus-supply`、`sink-pdos`（需硬件确认！）及三个`remote-endpoint`正确配置。
2.  **USB控制器**：确认 `dr_mode = "otg"`、`usb-role-switch` 属性及 `remote-endpoint` 连接。
3.  **USB PHY**：检查 `orientation-switch`、`svid`、SBU GPIOs 及 `remote-endpoint` 配置。
4.  **基础配置**：验证Pinctrl和Regulator节点是否正确。