---
id: 1761638254538342
---
## 1. 概述

BC1.2（Battery Charging Specification 1.2）是USB-IF（USB Implementers Forum）制定的电池充电规范，旨在通过USB接口为设备提供更高效的充电能力。BC1.2协议定义了多种充电模式，包括标准下行端口（SDP）、充电下行端口（CDP）和专用充电端口（DCP）。RK平台的USB PHY驱动通过硬件和软件的结合，实现了对BC1.2协议的支持，能够检测USB端口的充电类型，并根据检测结果调整充电策略。

前面在《BC1.2充电协议简介》文章中介绍了BC1.2协议，本文将基于RK平台的USB PHY驱动源码，分析其如何实现充电检测和BC1.2协议，包括硬件支持、软件实现。

## 2. BC1.2协议简介

BC1.2协议定义了三种主要的充电模式：

1. **标准下行端口（SDP）**：标准的USB端口，提供500mA的电流。数据线（D+和D-）在空闲状态下保持低电平。
2. **充电下行端口（CDP）**：支持充电的USB端口，提供1.5A的电流。数据线（D+和D-）在空闲状态下通过特定的电压分压电路保持特定电平。
3. **专用充电端口（DCP）**：专为充电设计的USB端口，提供1.5A的电流。数据线（D+和D-）通过短接或特定电阻连接。

BC1.2协议通过检测USB数据线（D+和D-）的电压和电流，来判断USB端口的类型。检测过程分为三个阶段：数据线接触检测（DCD）、初级检测和次级检测。

## 3. RK平台USB PHY的充电检测实现

RK平台的USB PHY驱动通过硬件寄存器和软件逻辑的结合，实现了对BC1.2协议的充电检测。以下是具体的实现分析：

### 3.1 充电检测状态机

在RK平台的USB PHY驱动中，充电检测通过一个状态机来实现。状态机的定义如下：

```
enum usb_chg_state {
    USB_CHG_STATE_UNDEFINED = 0,
    USB_CHG_STATE_WAIT_FOR_DCD,
    USB_CHG_STATE_DCD_DONE,
    USB_CHG_STATE_PRIMARY_DONE,
    USB_CHG_STATE_SECONDARY_DONE,
    USB_CHG_STATE_DETECTED,
};
```

- **USB_CHG_STATE_UNDEFINED**：初始状态，表示充电检测尚未开始。
- **USB_CHG_STATE_WAIT_FOR_DCD**：等待数据线接触检测（DCD）完成。
- **USB_CHG_STATE_DCD_DONE**：DCD检测完成，进入初级检测阶段。
- **USB_CHG_STATE_PRIMARY_DONE**：初级检测完成，进入次级检测阶段。
- **USB_CHG_STATE_SECONDARY_DONE**：次级检测完成，确定充电类型。
- **USB_CHG_STATE_DETECTED**：充电类型已确定。

### 3.2 充电检测流程

充电检测的流程如下：

1. **触发充电检测：**
   - USB口在Peripheral模式或OTG模式初始化时触发。
   - VBUSDET中断触发。
2. **DCD检测（Data Contact Detection）**：
   - 在DCD阶段，PHY会检测USB数据线（D+和D-）是否接触良好。
   - 如果检测到数据线接触良好，则进入初级检测阶段。
3. **初级检测（Primary Detection）**：
   - 在初级检测阶段，PHY会通过检测D+和D-的电压来判断是SDP还是DCP/CDP。
   - 如果D+和D-的电压符合SDP的特征，则判定为SDP。
   - 如果D+和D-的电压符合DCP/CDP的特征，则进入次级检测阶段。
4. **次级检测（Secondary Detection）**：
   - 在次级检测阶段，PHY会进一步检测D+和D-的电压，以区分DCP和CDP。
   - 如果D+和D-的电压符合DCP的特征，则判定为DCP。
   - 如果D+和D-的电压符合CDP的特征，则判定为CDP。

### 3.3 充电检测的硬件支持

RK平台的USB PHY驱动通过以下硬件寄存器来实现充电检测：

- **chg_mode**：设置PHY进入充电检测模式。
- **cp_det**：检测充电端口（CP）是否连接成功。
- **dcp_det**：检测专用充电端口（DCP）是否连接成功。
- **dp_det**：检测数据线（D+）是否连接成功。
- **idm_sink_en**：打开DM（D-）的电流吸收。
- **idp_sink_en**：打开DP（D+）的电流吸收。
- **idp_src_en**：打开DP（D+）的电流源。
- **rdm_pdwn_en**：打开DM（D-）的下拉电阻。
- **vdm_src_en**：打开DM（D-）的电压源。
- **vdp_src_en**：打开DP（D+）的电压源。

### 3.4 充电检测的软件实现

在软件层面，RK平台的USB PHY驱动通过以下步骤实现充电检测：

1. **初始化充电检测**：
   - 设置PHY进入充电检测模式，并初始化相关寄存器。
2. **DCD检测**：
   - 打开DM和DP的电流吸收，检测数据线是否接触良好。
   - 如果检测到数据线接触良好，则进入初级检测阶段。
3. **初级检测**：
   - 打开DP的电压源，检测D+和D-的电压。
   - 根据电压值判断是SDP还是DCP/CDP。
4. **次级检测**：
   - 如果初级检测结果为DCP/CDP，则进一步检测D+和D-的电压，以区分DCP和CDP。
5. **充电类型确定**：
   - 根据检测结果，确定充电类型，并设置相应的充电策略。

### 3.5 充电检测的代码实现

以下是RK平台USB PHY驱动中充电检测的核心代码：

```c
/* 进入充电检测 */
/* PHY初始化时触发： */
static int rockchip_usb2phy_init(struct phy *phy)
{
    /* ... */
    if (rport->port_id == USB2PHY_PORT_OTG &&
        (rport->mode == USB_DR_MODE_PERIPHERAL ||
         rport->mode == USB_DR_MODE_OTG)) {
        /* 启动充电检测工作队列 */
        schedule_delayed_work(&rport->otg_sm_work,
                              rport->typec_vbus_det ? 0 : OTG_SCHEDULE_DELAY);
    }
    /* ... */
}

/* VBUS有效中断触发： */
static irqreturn_t rockchip_usb2phy_bvalid_irq(int irq, void *data)
{
    struct rockchip_usb2phy_port *rport = data;
    struct rockchip_usb2phy *rphy = dev_get_drvdata(rport->phy->dev.parent);

    if (!property_enabled(rphy->grf, &rport->port_cfg->bvalid_det_st))
        return IRQ_NONE;

    /* 清除中断状态 */
    property_enable(rphy->grf, &rport->port_cfg->bvalid_det_clr, true);

    /* 启动充电检测 */
    if (rport->otg_sm_work.work.func) {
        cancel_delayed_work_sync(&rport->otg_sm_work);
        rockchip_usb2phy_otg_sm_work(&rport->otg_sm_work.work);
    }

    return IRQ_HANDLED;
}

/* 充电检测流程 */
static void rockchip_chg_detect_work(struct work_struct *work)
{
    struct rockchip_usb2phy_port *rport =
        container_of(work, struct rockchip_usb2phy_port, chg_work.work);
    struct rockchip_usb2phy *rphy = dev_get_drvdata(rport->phy->dev.parent);
    struct regmap *base = get_reg_base(rphy);
    const struct usb2phy_reg *phy_sus_reg;
    bool is_dcd, tmout, vout;
    unsigned long delay;
    unsigned int mask;
    int ret;

    dev_dbg(&rport->phy->dev, "chg detection work state = %d\\n",
            rphy->chg_state);

    switch (rphy->chg_state) {
    case USB_CHG_STATE_UNDEFINED:
        /* 初始化充电检测 */
        property_enable(base, &rphy->phy_cfg->chg_det.chg_mode, true);
        rockchip_chg_enable_dcd(rphy, true);
        rphy->chg_state = USB_CHG_STATE_WAIT_FOR_DCD;
        rphy->dcd_retries = 0;
        rphy->primary_retries = 0;
        delay = CHG_DCD_POLL_TIME;
        break;
    case USB_CHG_STATE_WAIT_FOR_DCD:
        /* DCD检测 */
        is_dcd = property_enabled(rphy->grf, &rphy->phy_cfg->chg_det.dp_det);
        tmout = ++rphy->dcd_retries == CHG_DCD_MAX_RETRIES;
        if (is_dcd || tmout) {
            rockchip_chg_enable_dcd(rphy, false);
            rockchip_chg_enable_primary_det(rphy, true);
            delay = CHG_PRIMARY_DET_TIME;
            rphy->chg_state = USB_CHG_STATE_DCD_DONE;
        } else {
            delay = CHG_DCD_POLL_TIME;
        }
        break;
    case USB_CHG_STATE_DCD_DONE:
        /* 初级检测 */
        vout = property_enabled(rphy->grf, &rphy->phy_cfg->chg_det.cp_det);
        rockchip_chg_enable_primary_det(rphy, false);
        if (vout) {
            rockchip_chg_enable_secondary_det(rphy, true);
            delay = CHG_SECONDARY_DET_TIME;
            rphy->chg_state = USB_CHG_STATE_PRIMARY_DONE;
        } else {
            if (rphy->dcd_retries == CHG_DCD_MAX_RETRIES) {
                rphy->chg_type = POWER_SUPPLY_TYPE_USB_DCP;
                rphy->chg_state = USB_CHG_STATE_DETECTED;
                delay = 0;
            } else {
                if (rphy->primary_retries < 2) {
                    rockchip_chg_enable_dcd(rphy, false);
                    rockchip_chg_enable_primary_det(rphy, true);
                    delay = CHG_PRIMARY_DET_TIME;
                    rphy->chg_state = USB_CHG_STATE_DCD_DONE;
                    rphy->primary_retries++;
                    break;
                }
                rphy->chg_type = POWER_SUPPLY_TYPE_USB;
                rphy->chg_state = USB_CHG_STATE_DETECTED;
                delay = 0;
            }
        }
        break;
    case USB_CHG_STATE_PRIMARY_DONE:
        /* 次级检测 */
        vout = property_enabled(rphy->grf, &rphy->phy_cfg->chg_det.dcp_det);
        rockchip_chg_enable_secondary_det(rphy, false);
        if (vout)
            rphy->chg_type = POWER_SUPPLY_TYPE_USB_DCP;
        else
            rphy->chg_type = POWER_SUPPLY_TYPE_USB_CDP;
        fallthrough;
    case USB_CHG_STATE_SECONDARY_DONE:
        rphy->chg_state = USB_CHG_STATE_DETECTED;
        fallthrough;
    case USB_CHG_STATE_DETECTED:
        /* 充电类型确定 */
        if (rphy->phy_cfg->chg_det.chg_mode.offset !=
            rport->port_cfg->phy_sus.offset)
            property_enable(base, &rphy->phy_cfg->chg_det.chg_mode, false);

        /* 恢复PHY的挂起配置 */
        phy_sus_reg = &rport->port_cfg->phy_sus;
        mask = GENMASK(phy_sus_reg->bitend, phy_sus_reg->bitstart);
        ret = regmap_write(base, phy_sus_reg->offset,
                           (rphy->phy_sus_cfg | (mask << BIT_WRITEABLE_SHIFT)));
        if (ret)
            dev_err(&rport->phy->dev,
                    "Fail to set phy_sus reg offset 0x%x, ret %d\\n",
                    phy_sus_reg->offset, ret);
        mutex_unlock(&rport->mutex);
        rockchip_usb2phy_otg_sm_work(&rport->otg_sm_work.work);
        dev_dbg(&rport->phy->dev, "charger = %s\\n",
                 chg_to_string(rphy->chg_type));
        return;
    default:
        mutex_unlock(&rport->mutex);
        return;
    }

    schedule_delayed_work(&rport->chg_work, delay);
}
```

## 4. 总结

RK平台的USB PHY驱动通过硬件寄存器和软件状态机的结合，实现了对BC1.2协议的充电检测。通过DCD检测、初级检测和次级检测，PHY能够准确判断USB端口的充电类型（SDP、CDP或DCP），并根据检测结果调整充电策略。这种实现方式不仅提高了充电效率，还确保了设备的安全性和兼容性。