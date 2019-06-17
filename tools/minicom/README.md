## 简介  
minicom是linux系统的一个串口工具，相当于window系统的`超级终端`或者`SecureCRT`的serial功能。在RK平台的开发过程中，我们用串口作为调试口，可以打印log信息，也可以执行相关的指令进行设备的调试。串口的硬件连接方法如下：
![serial](https://raw.githubusercontent.com/Jesse-Lam/rk_notes/master/tools/minicom/serial_connect_to_pc.png)
## 安装  
```
sudo apt-get install minicom
```
## 配置
进入配置界面有两种方式：  
1.使用命令：`sudo minicom -s`启动直接进入配置界面  
2.使用命令：`sudo minicom`启动，再按`ctrl+a o`进入配置界面  
![minicom configure](https://raw.githubusercontent.com/Jesse-Lam/rk_notes/master/tools/minicom/minicom_1.png)  
使用上下键选择`Serial port setup`可以设置串口相关属性，如：  
![minicom setup](https://raw.githubusercontent.com/Jesse-Lam/rk_notes/master/tools/minicom/minicom_2.png)  
我们只需输入上面对应的字母，就可以进如相应的菜单进行设置，设置完返回主菜单后，选择`Save setup as dfl`，将其保存为默认设置。
## 使用
如果设置正确，使用命令：`sudo minicom`就可以启动minicom并自动打印串口信息，此时，按`ctrl+a`可以进入设置状态，在设置状态你可以：  
按z键：打开帮忙菜单  
按w键：自动换行  
按c键：清屏  
按b键：浏览历史显示  
按f键：进入快速中断  
按o键：进入配置菜单  
按l键：把log保存  
按x键：退出  
## 其他技巧
```
sudo minicom -s //进入设置界面
sudo minicom -b 1500000 //以1.5M的波特率进入
sudo minicom -D /dev/ttyUSB1 //打开/dev/ttyUSB1
sudo minicom -C /path/test.log //把log保存到/path/test.log
sudo minicom -c //显示颜色
```

