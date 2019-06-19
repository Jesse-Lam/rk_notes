## Pin-Ctrl子系统
### Pin-Ctrl子系统简介
Pin-Ctrl是rockchip管理主控所有pin脚的重要子系统，主要功能有以下几点：  
1. 管理系统中所有的可以控制的pin，在系统初始化的时候，枚举所有可以控制的pin，并标识这些pin。  
2. 管理pin的复用(IOMUX)。对于soc而言，其引脚除了配置成普通的GPIO之外，若干个引脚还可以组成一个pin group，形成特定的功能，比如当作lcdc，sdmmc，uart等。  
3. 配置pin的特性。例如使能或关闭引脚上的上拉(pull-up)电阻、下拉(pull-down)电阻，配置引脚的驱动强度(driver strength)。  
### Pin-Ctrl的基本框架
在芯片的主dts文件(以rk3288为例: rk3288.dtsi)，一般会有一个pinctrl节点：
```
pinctrl: pinctrl {
                compatible = "rockchip,rk3288-pinctrl"; 
                rockchip,grf = <&grf>;
                rockchip,pmu = <&pmu>;
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                gpio0: gpio0@ff750000 {
                        compatible = "rockchip,gpio-bank";
                        reg = <0x0 0xff750000 0x0 0x100>;
                        interrupts = <GIC_SPI 81 IRQ_TYPE_LEVEL_HIGH>;
                        clocks = <&cru PCLK_GPIO0>;
                        gpio-controller;
                        #gpio-cells = <2>;
                        interrupt-controller;
                        #interrupt-cells = <2>;
                };
        ......
```
该节点描述了芯片的所有pin脚及其对应的功能，对应驱动：drivers/pinctrl/pinctrl-rockchip.c，开机的时候驱动会读取dts配置进行初始化，具体的初始化流程这里先不讨论。

### DTS配置
在实际应用中一般不会去修改rk3288.dtsi和pinctrl-rockchip.c，而是在设备驱动的dts节点中配置Pin-Ctrl。以HDMI为例：
```
        hdmi: hdmi@ff980000 {
                compatible = "rockchip,rk3288-dw-hdmi";
                reg = <0x0 0xff980000 0x0 0x20000>;
                reg-io-width = <4>;
                rockchip,grf = <&grf>;
                interrupts = <GIC_SPI 103 IRQ_TYPE_LEVEL_HIGH>;
                clocks = <&cru  PCLK_HDMI_CTRL>, <&cru SCLK_HDMI_HDCP>, <&cru SCLK_HDMI_CEC>;
                clock-names = "iahb", "isfr", "cec";
                pinctrl-names = "default", "sleep";
                pinctrl-0 = <&hdmi_ddc>;
                pinctrl-1 = <&hdmi_gpio>;
                power-domains = <&power RK3288_PD_VIO>;
                status = "disabled";

                ports {
                        hdmi_in: port {
                                #address-cells = <1>;
                                #size-cells = <0>;
                                hdmi_in_vopb: endpoint@0 {
                                        reg = <0>;
                                        remote-endpoint = <&vopb_out_hdmi>;
                                };
                                hdmi_in_vopl: endpoint@1 {
                                        reg = <1>;
                                        remote-endpoint = <&vopl_out_hdmi>;
                                };
                        };
                };
        };
        pinctrl: pinctrl {
                compatible = "rockchip,rk3288-pinctrl";
                rockchip,grf = <&grf>;
                rockchip,pmu = <&pmu>;
                #address-cells = <2>;
                #size-cells = <2>;
                ranges;
                hdmi {
                        hdmi_gpio: hdmi-gpio {
                                rockchip,pins = <7 19 RK_FUNC_GPIO
                                                 &pcfg_pull_none>,
                                                <7 20 RK_FUNC_GPIO
                                                 &pcfg_pull_none>;
                        };

                        hdmi_cec: hdmi-cec {
                                rockchip,pins = <7 16 RK_FUNC_2 &pcfg_pull_none>;
                        };

                        hdmi_ddc: hdmi-ddc {
                                rockchip,pins = <7 19 RK_FUNC_2 &pcfg_pull_none>,
                                                <7 20 RK_FUNC_2 &pcfg_pull_none>;
                        };
                };

```
dts中配置了pinctrl-names为"default"和"sleep"，分别对应pinctrl-0和pinctrl-1，在pinctrl节点中可以看到对该引脚的定义，kernel初始化的时候会把该引脚设置为default状态，即RK_FUNC_2，休眠的时候会设置为sleep状态，即RK_FUNC_GPIO，这时hdmi就没有输出了；在休眠唤醒的时候重新设置为default状态。在HDMI的代码中可以看到：
```
drivers/gpu/drm/bridge/synopsys/dw-hdmi.c
dw_hdmi_suspend---->pinctrl_pm_select_sleep_state(dev);
dw_hdmi_resume---->pinctrl_pm_select_default_state(dev);
```
### IOMUX配置
在RK的芯片中，一个引脚可以有多个功能，我们称之为功能复用，比如上面说的hdmi-gpio，即可以当作gpio，也可以当作hdmi-ddc。  
在kernel的include/dt-bindings/pinctrl/rockchip.h中有这样的定义：
```
#define RK_FUNC_GPIO    0
#define RK_FUNC_1       1
#define RK_FUNC_2       2
#define RK_FUNC_3       3
#define RK_FUNC_4       4
#define RK_FUNC_5       5
#define RK_FUNC_6       6
#define RK_FUNC_7       7
```
这里分别对应相应的寄存器值。  
还是以上面hdmi的GPIO为例，可以从rk3288的TRM手册《GRF》中查到：
![pinctrl_hdmi_trm](https://raw.githubusercontent.com/Jesse-Lam/rk_notes/master/kernel/drivers/gpio/pinctrl_hdmi_trm.png)  
GPIO7_C3可以当做gpio, i2c5hdmi_sda, edphdmii2c_sda三种功能，GPIO7_C4可以当做gpio, i2c5hdmi_scl, edphdmii2c_scl三种功能，hdmi-ddc节点选中了RK_FUNC_2，因此开机的时候默认配置成edphdmii2c_sda和edphdmii2c_scl。
### 驱动强度配置
驱动强度，即GPIO的驱动强度电流值，分别对应主控相应的寄存器，其配置在dts文件里。
```
                pcfg_pull_none_12ma: pcfg-pull-none-12ma {
                        bias-disable;
                        drive-strength = <12>;
                };
                gmac {
                        rgmii_pins: rgmii-pins {
                                rockchip,pins = <3 30 3 &pcfg_pull_none>, //为默认值
                                                <3 31 3 &pcfg_pull_none>,
                                                <3 26 3 &pcfg_pull_none>,
                                                <3 27 3 &pcfg_pull_none>,
                                                <3 28 3 &pcfg_pull_none_12ma>, //驱动能力设置为最大
                                                <3 29 3 &pcfg_pull_none_12ma>,
                                                <3 24 3 &pcfg_pull_none_12ma>,
                                                <3 25 3 &pcfg_pull_none_12ma>,
                                                <4 0 3 &pcfg_pull_none>,
                                                <4 5 3 &pcfg_pull_none>,
                                                <4 6 3 &pcfg_pull_none>,
                                                <4 9 3 &pcfg_pull_none_12ma>,
                                                <4 4 3 &pcfg_pull_none_12ma>,
                                                <4 1 3 &pcfg_pull_none>,
                                                <4 3 3 &pcfg_pull_none>;
                        };
                };
```
每一个pin 具有自己所在对应的驱动电流强度范围，所以配置的时候要选择其有效可配置的电流值，如果不是该pin 对应的有效电流值，配置将会出错，无法生效。  
GPIO的驱动强度也是可以从TRM手册的《GRF》中查到：
![pinctrl_drive_trm](https://raw.githubusercontent.com/Jesse-Lam/rk_notes/master/kernel/drivers/gpio/pinctrl_drive_trm.png)  
### 上下拉配置
上下拉，即配置芯片内部上拉，下拉或者都不配置，分别对应相应的寄存器值，其配置在dts文件里。
```
                pcfg_pull_up: pcfg-pull-up {
                        bias-pull-up;
                };

                pcfg_pull_down: pcfg-pull-down {
                        bias-pull-down;
                };

                pcfg_pull_none: pcfg-pull-none {
                        bias-disable;
                };

                pcfg_pull_none_12ma: pcfg-pull-none-12ma { 
                        bias-disable;
                        drive-strength = <12>;
                };

                uart2 {
                        uart2_xfer: uart2-xfer {
                                rockchip,pins = <7 22 RK_FUNC_1 &pcfg_pull_up>, //设置内部上拉
                                                <7 23 RK_FUNC_1 &pcfg_pull_none>; //未配置上拉和下拉
                        };
                };
```
GPIO口是否可以配置上下拉与芯片设计有关系，RK3288所有的GPIO口都可以配置内部上下拉，设置上拉(下拉)之后，对应的引脚在开机之后可以量到高电平(低电平)。
