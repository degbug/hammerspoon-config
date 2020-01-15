# hammerspoon-config
hammerspoon配置

window-management 引用[window-management](https://github.com/CrossRaynor/.hammerspoon/blob/master/modules/window-management.lua)

window-switch,实现了为应用绑定热键用于切换窗口的功能,逻辑如下：
当应用未启动或者只有一个窗体时，调用对应热键会启动或切换到该应用。
当应用有多个窗体时，列出该应用所有窗体，并支持输入对应的顺序，跳转

使用：
```lua

local switcher = require("hammerspoon-config.window-switch")

-- 为这些应用单独榜单热键
switcher.bindApp(cmd, '1', '360极速浏览器')
switcher.bindApp(cmd, '2', 'IntelliJ IDEA')
switcher.bindApp(cmd, 'f3', 'Code')
switcher.bindApp(cmd, '3', 'Code')
switcher.bindApp(cmd, '4', 'FinalShell')
switcher.bindApp(cmd, '9','Notion')
switcher.bindApp(cmd, '0','钉钉')

-- 为这些应用绑定同一个热键
switcher.addTrackerApp({"iTerm2","MarginNote 3","Typora"})
switcher.bindHotKey(cmd, 'l')
```

问题：

自带的window.filter无法正确获取一个应用的所有窗体（隐藏，最小化，在其他space中的），因此该模块自己用监控并记录应用window的创建和销毁。其中有个问题是，一个应用如果有多个窗体（最小化，或者在其他space），每次更新配置时，需要将这种窗体先唤出显示一次才行，否则无法找到