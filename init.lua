require "window-management"

local hk = require "hs.hotkey"
local wm = require('window-management')

local hyper = {'ctrl', 'alt', 'cmd'}
local hyperShift = {'ctrl', 'alt', 'cmd', 'shift'}
local ctrl = {'ctrl'}


hs.hotkey.alertDuration = 0
hs.window.animationDuration = 0


-- 计算table的大小
function getCount(t)
  if t == nil then return 0 end
  local count = 0
  for k, v in pairs(t) do
      count = count + 1
  end

  return count
end

-- 获取窗体名称，没有时使用应用的名称
function getWinName(win)
  -- print(win)
  if win:title() == nil or win:title() == "" then
    return win:application():title()
  end

  return win:title()
end

-- 跟踪的应用
local appList = {}

-- 绑定快捷键的应用
local keyObj = {}

-- 所有要监控的应用的名称
local allAppName ={}

local anotherAPP = {}

-- key:用于get用，value 不等于1的用于launch用
allAppName["360极速浏览器"] = "360Chrome"
allAppName["IntelliJ IDEA"] = "1"
allAppName["Code"] = "Visual Studio Code"
allAppName["Notion"] = "1"
allAppName["钉钉"] = "DingTalk"
allAppName["iTerm2"] = "iTerm"
anotherAPP["iTerm2"] = "iTerm"

function getLauchName(appName)
  if(allAppName[appName] ~= nil and allAppName[appName] ~= 1) then
    return allAppName[appName]
  end

  return appName
end



-- local runningApp = hs.application.runningApplications()
-- for k,v in pairs(runningApp) do
--   print(v:title())
-- end

-- 获取一个对应应用的应用信息，没有时创建一个
function getOrCreateAppInfo(appName)
  local appInfo = appList[appName]
  if appInfo == nil then
    appInfo = {}
    appList[appName] = appInfo
  end

  return appInfo
end

-- 窗口销毁事件处理
local winDestroyEventHandler = function(win, event, watcher, winName)
  print(winName.." destroyed")
  local appInfo = appList[win:application():title()]
  if appInfo ~= nil and appInfo[tostring(win:id())] ~= nil then
    appInfo[tostring(win:id())] = nil
  end

  watcher:stop()
  watcher = nil
end

-- 添加一个窗口移除的事件监控
function addDestroyWatcher(win)
  local winName = getWinName(win)
  win:newWatcher(winDestroyEventHandler, winName):start({hs.uielement.watcher.elementDestroyed})

  print("success add des event")
end

local winCreateOrMoveEventHandler = function(win,event,_,appName)
  if string.find(tostring(win), "hs.uielement") == nil and win:isStandard() then
    -- print("get event"..tostring(event).." of "..appName)
    -- print(tostring(win))
    local winId = tostring(win:id())
    local appInfo = getOrCreateAppInfo(appName)
    if appInfo[winId] == nil then
      print("create new "..appName.." a window")
      appInfo[winId] = win
      addDestroyWatcher(win)
    end 
  end
end



local elWat = hs.uielement.watcher
-- TODO:软件退出的处理，需要移除监控

-- 初始化
for k,v in pairs(allAppName) do
  local app = hs.application.get(k)
  -- 监视窗口创建
  if app ~= nil then
    print("beigin add created "..k)
    local appInfo = {}
    appList[k] = appInfo
    -- 获取窗口
    local wins = app:allWindows()
    if getCount(wins) > 0 then
      for k1, win in pairs(wins) do
        if win:isStandard() then
          print(win)
          --加入列表
          appInfo[tostring(win:id())] = win
          addDestroyWatcher(win)
        end
      end
    end
    app:newWatcher(winCreateOrMoveEventHandler, k):start({elWat.windowCreated,elWat.windowMoved})
  else
    print("找不到"..k.."的应用")
  end
end


-- 
-- windowCreated: A window was created. You should watch for this event on the application, or the parent window.
-- hs.uielement.watcher.windowMoved: The window was moved.
-- hs.uielement.watcher.windowResized: The window was resized.
-- hs.uielement.watcher.windowMinimized: The window was minimized.
-- hs.uielement.watcher.windowUnminimized: The window was unminimized.

-- 控制台列出当前的应用信息
hs.hotkey.bind(hyperShift, "l", function()
  for k, v in pairs(appList) do
    local count = getCount(v)
    print("应用"..k.."有"..count.."个窗口:")
    if count > 0 then
      for id, win in pairs(v) do
        if win:isStandard() then
          print("    id="..id.." isStan: "..tostring(win:isStandard()).." "..getWinName(win))
        end
      end
    end
  end
end)




-- * Key Binding Utility
--- Bind hotkey for window management.
-- @function windowBind
-- @param {table} hyper - hyper key set
-- @param { ...{key=value} } keyFuncTable - multiple hotkey and function pairs
--   @key {string} hotkey
--   @value {function} callback function
local function windowBind(hyper, keyFuncTable)
    for key, fn in pairs(keyFuncTable) do hk.bind(hyper, key, fn) end
end

-- * Move window to screen
windowBind({"ctrl", "alt"}, {left = wm.throwLeft, right = wm.throwRight})

-- * Set Window Position on screen
windowBind(hyperShift, {
    m = wm.maximizeWindow, -- ⌃⌥⌘ + M
    c = wm.centerOnScreen, -- ⌃⌥⌘ + C
    left = wm.leftHalf, -- ⌃⌥⌘ + ←
    right = wm.rightHalf, -- ⌃⌥⌘ + →
    up = wm.topHalf, -- ⌃⌥⌘ + ↑
    down = wm.bottomHalf -- ⌃⌥⌘ + ↓
})

-- -- -- * Set Window Position on screen
-- -- windowBind({"ctrl", "alt", "shift"}, {
-- --   left = wm.rightToLeft,      -- ⌃⌥⇧ + ←
-- --   right = wm.rightToRight,    -- ⌃⌥⇧ + →
-- --   up = wm.bottomUp,           -- ⌃⌥⇧ + ↑
-- --   down = wm.bottomDown        -- ⌃⌥⇧ + ↓
-- -- })
-- -- -- * Set Window Position on screen
-- -- windowBind({"alt", "cmd", "shift"}, {
-- --   left = wm.leftToLeft,      -- ⌥⌘⇧ + ←
-- --   right = wm.leftToRight,    -- ⌥⌘⇧ + →
-- --   up = wm.topUp,             -- ⌥⌘⇧ + ↑
-- --   down = wm.topDown          -- ⌥⌘⇧ + ↓
-- -- })

-- -- -- * Windows-like cycle
-- -- windowBind({"ctrl", "alt", "cmd"}, {
-- --   u = wm.cycleLeft,          -- ⌃⌥⌘ + u
-- --   i = wm.cycleRight          -- ⌃⌥⌘ + i
-- -- })


-- 选择框
local context = hs.chooser.new(function (choice)
  if choice then

    if choice.hasWin then
      local appInfo = appList[choice.appName]
      local curWin = appInfo[tostring(choice.content)]
      print(choice.content)
      print(curWin)
      if curWin:isVisible() == false then 
        curWin:raise()
      end

      curWin:focus()
    else
      local appName = choice.appName
      hs.application.launchOrFocus(getLauchName(appName))
      local lauchedApp = hs.application.get(appName)
        if lauchedApp ~= nil then
          lauchedApp:newWatcher(winCreateOrMoveEventHandler, appName):start({elWat.windowCreated,elWat.windowMoved})
        else
          print("找不到11"..appName)
        end
    end

    
    -- print("focus "+curWin:title())
    -- hs.window.find(choice.content):focus()
  end
end)

context:queryChangedCallback(function (query)
  local queryNum = tonumber(query)
  if queryNum ~=nil and queryNum>0 and #query == 1 then 
    context:query(nil)
    hs.eventtap.keyStroke({ "cmd" }, query) 
  end
end)

function disableHotKey()
  print('disable hot key')
  for k, v in pairs(keyObj) do
    v.app:disable()
  end
end

function enableHotKey()
  print('re enable hot key')
  for k, v in pairs(keyObj) do
    v.app:enable()
  end
end

hs.chooser.globalCallback = function(choose, name)
  if 'didClose' == name then
    enableHotKey()
  end
end


function createItem(win,appName, withAppName)
  local item = {}
  local title = appName;
  local text = title;
  item.hasWin = false
  if win ~= nil then
    item.hasWin = true
    title = win:title();
    if title == nil then title = 'null' end
    
    text = string.gsub(title, "[\r\n]+", " ")
    if text == nil or text == '' then text = win:application():title() end
    item.content = win:id()
  end

  if withAppName then
    item.text = appName.."=>"..text
  else
    item.text = text
  end
  
  item.appName = appName
  return item
end
-- appName用于get app用，而name用于launch用
function bindApp( key, appName , name)
  local app = hk.bind('cmd', key, function()
    local history = {}
    local wins = appList[appName]

    if wins == nil or getCount(wins) <= 1 then
        local finalName = name
        if name == nil then finalName = appName end
        hs.application.launchOrFocus(finalName)
        local lauchedApp = hs.application.get(appName)
        if lauchedApp ~= nil then
          lauchedApp:newWatcher(winCreateOrMoveEventHandler, appName):start({elWat.windowCreated,elWat.windowMoved})
        else
          print("找不到"..appName)
        end
      else
        disableHotKey()
        for k, v in pairs(wins) do
          table.insert(history, 1, createItem(v, appName))
        end
        -- hs.alert.show(context == nil)@
        context:choices(history)
        context:show()
        print('show choices')
    end
  end)

  local item ={}
  item.app = app
  table.insert(keyObj,1, item)
  return app
end


function bindAnother()
  -- body
  hk.bind('cmd', 'l', function()
    local history = {}
    disableHotKey()
    for appName, v in pairs(anotherAPP) do
      local appInfo = getOrCreateAppInfo(appName)
      if getCount(appInfo) == 0 then
        table.insert(history, 1, createItem(nil, appName))
      else
        for k1, v1 in pairs(appInfo) do
          table.insert(history, 1, createItem(v1, appName, true))
        end
      end
    end

    context:choices(history)
    context:show()
    print('show choices')

  end)
end


bindApp('f1', '360极速浏览器', '360Chrome')
bindApp('1', '360极速浏览器', '360Chrome')
bindApp('f2', 'IntelliJ IDEA')
bindApp('2', 'IntelliJ IDEA')
bindApp('f3', 'Code', 'Visual Studio Code')
bindApp('3', 'Code', 'Visual Studio Code')
bindApp('f4', 'FinalShell')
bindApp('4', 'FinalShell')
bindApp('f9', 'Notion')
bindApp('9','Notion')
bindApp('0','钉钉','DingTalk')
bindApp('f10', '钉钉','DingTalk')

bindAnother()


