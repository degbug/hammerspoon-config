local hk = require "hs.hotkey"
local elWat = hs.uielement.watcher

switcher = {}

local anotherAppName = "another_app"

-- 保存应用名和bundleId
local appInfo = {}

-- 保存应用bundleId-->窗体信息
local appWinInfo = {}

-- 跟踪的应用
local trackApp = {}

-- 绑定的热键信息
local keyObj = {}

-- 当前的chooser选项
local currChoices = {}

-- 上一次触发的应用名
local lastCallAppName

-- 绑定了特定热键的应用
local bindedSpecialApp = {}

-- 已经初始化的应用
local initedTable = {}


-- 循环Value内容
function forValue(myTable, processFun)
    if getCount(myTable) > 0 then
        for k, v in pairs(myTable) do processFun(v) end
    end
end

-- 窗口销毁事件处理
local winDestroyEventHandler = function(win, event, watcher, winName)
    -- print(winName .. " destroyed")
    removeWinInfo(win)
    watcher:stop()
    watcher = nil
end

-- 添加一个窗口移除的事件监控
function addDestroyWatcher(win)
    local winName = getWinName(win)
    win:newWatcher(winDestroyEventHandler, winName):start(
        {hs.uielement.watcher.elementDestroyed})
    -- print("success add des event for " .. winName)
end

-- 窗口新增或者移动事件
-- 这里之所以处理移动事件，是因为获取不到其他space中的窗体时，切换space时，可以发现这些窗体
-- 因此，如果初次加载时，如果有全屏或者其他space的窗体时，要切换下
local winCreateOrMoveEventHandler = function(win, event, _, appName)
    if isStandardWin(win) and addWinInfo(win) then
        -- 添加成功
        print(appName .. " create a new window")
        addDestroyWatcher(win)
    end
end

-- 唤起并绑定窗口创建事件
function lauchAndBindWindowWatcher(appName)
    print("lauchAndBindWindowWatcher " .. appName)
    local bundleId = getBundleId(appName)
    hs.application.launchOrFocusByBundleID(bundleId)
    local lauchedApp = hs.application.get(bundleId)

    if lauchedApp ~= nil then
        lauchedApp:newWatcher(winCreateOrMoveEventHandler, appName):start(
            {elWat.windowCreated, elWat.windowMoved})
    else
        print("找不到" .. bundleId)
    end
end

-- 选择框
local chooser = hs.chooser.new(function(choice)
    if choice then
        if choice.hasWin then
            local curWin = getWinById(tostring(choice.content), choice.appName)
            if curWin:isVisible() == false then curWin:raise() end

            curWin:focus()
        else
            local appName = choice.appName
            lauchAndBindWindowWatcher(appName)
        end
    end
end)

-- 查询内容变更时回调事件
-- 这里如果输入的是数字，则触发相应的行的快捷键
-- 否则则更加输入的内容，进行过滤筛选
chooser:queryChangedCallback(function(query)
    local queryNum = tonumber(query)
    if queryNum ~= nil and queryNum > 0 and #query == 1 then
        chooser:query(nil) -- 清空
        hs.eventtap.keyStroke({"cmd"}, query)
    elseif query then
        local finalChoices = {}
        forValue(currChoices, function(v)
            if string.find(string.lower(v.text), string.lower(query)) ~= nil then
                table.insert(finalChoices, 1, v)
            end
        end)

        chooser:choices(finalChoices)
    else
        -- 为空
        local finalChoices = currChoices
        chooser:choices(finalChoices)
    end
end)

-- 禁用已经绑定的快捷键
function disableHotKey()
    print('disable hot key')
    for k, v in pairs(keyObj) do v.hotKeyObject:disable() end
end

-- 重新启用已经绑定的快捷键
function enableHotKey()
    print('re enable hot key')
    for k, v in pairs(keyObj) do v.hotKeyObject:enable() end
end

-- 全局函数
hs.chooser.globalCallback = function(choose, name)
    if 'didClose' == name then enableHotKey() end
end

function createItem(win, appName, withAppName)
    local item = {}
    local title = appName;
    local text = title;
    item.hasWin = false
    if win ~= nil then
        item.hasWin = true
        title = win:title();
        -- print("title:"..title)
        if not title or title == "" then
            title = win:application():title()
        end

        text = string.gsub(title, "[\r\n]+", " ")
        item.content = win:id()
    end

    if withAppName then
        item.text = appName .. "->" .. text
    else
        item.text = text
    end

    item.appName = appName
    return item
end

function getBundleId(appName)
    local bundleId = appInfo[appName]
    if bundleId == nil then
        bundleId = getBundleId(appName)
        appInfo[appName] = bundleId
    end

    return bundleId
end

-- 计算table大小
function getCount(t)
    if t == nil then return 0 end
    local count = 0
    for k, v in pairs(t) do count = count + 1 end

    return count
end

-- 获取窗体的id
function getWinStringId(win) return tostring(win:id()) end

-- 获取窗体名称，没有时使用应用的名称
function getWinName(win)
    if win:title() == nil or win:title() == "" then
        return win:application():title()
    end

    return win:title()
end

-- 获取一个应用所有窗体信息
function getWinInfo(appName)
    local bundleId = getBundleId(appName)
    local winInfo = appWinInfo[bundleId]
    if winInfo == nil then
        winInfo = {}
        appWinInfo[bundleId] = winInfo
    end

    return winInfo
end

-- 获取窗体
function getWinById(winId, appName)
    local winInfo = getWinInfo(appName)
    return winInfo[winId]
end

-- 添加记录一个窗体信息
function addWinInfo(win)
    local winInfo = getWinInfo(win:application():title())
    local winId = getWinStringId(win)
    if winInfo[winId] == nil then
        winInfo[winId] = win
        return true
    end

    return false
end

-- 移除一个记录的窗体（销毁事件触发时调用）
function removeWinInfo(win)
    local winInfo = getWinInfo(win:application():title())
    winInfo[getWinStringId(win)] = nil
end

-- 判断是否是标准窗体应用
function isStandardWin(win)
    local isS = string.find(tostring(win), "hs.uielement") == nil and
                    win:isStandard()
    return isS
end

-- 获取应用信息
function getApplication(name)
    local bundleId = getBundleId(name)
    return hs.application.get(name)
end

-- 通过AppleScript获取bundleId
function getBundleId(name)
    local source = 'tell application "' .. name ..
                       '" \nset wins to id \nend tell \nreturn wins'
    local _, bundleId, _ = hs.osascript._osascript(source, "AppleScript")
    return bundleId
end

function clearChooserQueryIfNeed(appName)
    if lastCallAppName ~= appName then chooser:query(nil) end

    lastCallAppName = appName
end

-- 初始化应用信息
function initAppWinInfo(appName)
    local app = getApplication(appName)
    if app ~= nil then
        local wins = app:allWindows()
        print(appName .. " has " .. tostring(getCount(wins)))
        forValue(wins, function(win)
            if isStandardWin(win) and addWinInfo(win) then
                addDestroyWatcher(win)
            end
        end)

        if not initedTable[appName] then
            app:newWatcher(winCreateOrMoveEventHandler, appName):start(
                {elWat.windowCreated, elWat.windowMoved})

            initedTable[appName] = true
        end

    else
        print("can not find app[" .. appName .. "]")
    end
end

-- appName用于get app用，而name用于launch用
switcher.bindApp = function(hyper, key, appName)
    initAppWinInfo(appName)
    bindedSpecialApp[appName] = true

    local hotKeyObject = hk.bind(hyper, key, function()
        clearChooserQueryIfNeed(appName)

        currChoices = {}
        local wins = getWinInfo(appName)
        if getCount(wins) <= 1 then
            lauchAndBindWindowWatcher(appName)
        else
            disableHotKey()
            for k, v in pairs(wins) do
                table.insert(currChoices, 1, createItem(v, appName))
            end
            -- hs.alert.show(chooser == nil)@
            chooser:choices(currChoices)
            chooser:show()
            print('show choices')
        end
    end)

    local item = {}
    item.hotKeyObject = hotKeyObject
    table.insert(keyObj, 1, item)

end

-- 设置需要跟踪的应用
switcher.addTrackerApp = function(tmpTrackApp)
    for i = 1, #tmpTrackApp do
        trackApp[#trackApp + 1] = tmpTrackApp[i]
        initAppWinInfo(tmpTrackApp[i])
    end
end

-- 下面的热键触发时，是否也展示已经绑定了特殊热键的的应用
switcher.showBindApp = false

-- 绑定触发的热键
switcher.bindHotKey = function(hyper, key)
    -- body
    hk.bind(hyper, key, function()
        clearChooserQueryIfNeed(anotherAppName)

        currChoices = {}
        print("trackAppSize:" .. tostring(getCount(trackApp)))
        disableHotKey()
        for i = 1, #trackApp do
            local appName = trackApp[i]
            if switcher.showBindApp or not bindedSpecialApp[appName] then
                local winInfo = getWinInfo(appName)
                if getCount(winInfo) == 0 then
                    table.insert(currChoices, 1, createItem(nil, appName))
                else
                    for k1, v1 in pairs(winInfo) do
                        table.insert(currChoices, 1,
                                     createItem(v1, appName, true))
                    end
                end
            end
        end

        chooser:choices(history)
        chooser:show()
    end)
end

return switcher
