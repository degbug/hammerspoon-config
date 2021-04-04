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
local currChoicesHolder = {}

-- 上一次触发的应用名
local lastCallAppName

-- 绑定了特定热键的应用
local bindedSpecialApp = {}

-- 已经初始化的应用
local initedTable = {}

local lastQueryTable = {}

function pairsByKeys(t, f)
    local a = {}
    for k,v in pairs(t) do 
        local n = {}
        n.key = k
        n.value = v
        table.insert(a, n) 
    end
    table.sort(a, f)

    local i = 0                 -- iterator variable
    local iter = function ()    -- iterator function
       i = i + 1
       if a[i] == nil then return nil
       else return a[i].key, a[i].value
       end
    end
    return iter
end

function sortFunc(a , b)
    if a.value.order > b.value.order then 
        return true
    end
end

function sortFuncInverse(a , b)
    if a.value.order < b.value.order then 
        return true
    end
end

-- 循环Value内容
function forValue(myTable, processFun)
    if getCount(myTable) > 0 then
        for k, v in pairs(myTable) do processFun(v) end
    end
end


-- 唤起应用（单窗口时使用）
function lauchApplication(appName)
    print("lauchApplication " .. appName)
    local bundleId = getBundleId(appName)
    hs.application.launchOrFocusByBundleID(bundleId)
end

-- 选择框
local chooser = hs.chooser.new(function(choice)
    if choice then
        if choice.hasWin then
            local curWin = getWinById(tostring(choice.content), choice.appName)
            if curWin:isVisible() == false then curWin:raise() end

            curWin:focus()

            -- 鼠标移动到当前屏幕，当当前鼠标不在当前屏幕时
            local winScreen = curWin:screen()
            if(winScreen:id() ~= hs.mouse.getCurrentScreen():id()) then
                print("设置鼠标位置")
                local rec = winScreen:frame()
                hs.mouse.setRelativePosition(hs.geometry(rec.w -200,rec.h/2), winScreen)
             end
           
        else
            local appName = choice.appName
            lauchApplication(appName)
        end
    end
end)

function refreshChooser(appName)
    local winInfo = getWinInfo(appName)
    currChoicesHolder.currChoices = {}
    if getCount(winInfo) == 0 then
        table.insert(currChoicesHolder.currChoices, createItem(nil, appName))
    else

        for k1, v1 in pairsByKeys(winInfo, sortFuncInverse) do
            print("refresh order "..v1.order)
            table.insert(currChoicesHolder.currChoices,
                            createItem(v1, appName))
        end
    end

    chooser:choices(currChoicesHolder.currChoices)
end

-- 置底部
function pushToEnd(_, item)
    local winInfo = getWinInfo(item.appName)
    local winId = item.id
    local winObj = item.winObj
    local reOrder = winObj.order
    local max = 1
    for k, v in  pairs(winInfo) do
        if k ~= winId and v.order > max then
            max = v.order
        end
    end


    for k, v in pairs(winInfo) do
        if k == winId then
            print("pushEND the old order is "..tostring(v.order).." the new order is "..tostring(max))
            v.order = max
            print("reolder .. "..tostring(reOrder))
        elseif v.order > reOrder then
            v.order = v.order - 1
        end
    end

    refreshChooser(item.appName)

end

-- 置顶
function pushToTop(_, item)
    local winInfo = getWinInfo(item.appName)
    local winId = item.id
    local winObj = item.winObj
    local reOrder = winObj.order
    for k, v in pairs(winInfo) do
        if k == winId then
            print("pushTOP: the old order is "..tostring(v.order).." the new order is "..tostring(1))
            v.order = 1
            print("reolder .. "..tostring(reOrder))
        else 
            if v.order < reOrder then
                v.order = v.order + 1
            end
        end
    end

    refreshChooser(item.appName)

end

function renameWindow(_, item)
    local winInfo = getWinInfo(item.appName)
    local winId = item.id
    local winObj = item.winObj
    local reOrder = winObj.order
    local btn, result = hs.dialog.textPrompt("重命名", "", getWinName(winObj.win), "确定", "取消")
    print("btn"..btn)
    print("resutl:"..result)
    if btn == "确定" then
        winInfo[winId].alterText = result
    end

    refreshChooser(item.appName)
end

function createMenuItem(winObj, operName, fn)

    local item = {}
    item.title = operName..tostring(winObj.order)..getWinName(winObj.win)
    if winObj.alterText then
        item.title = operName.."["..tostring(winObj.order).."]"..winObj.alterText
    end
    item.winObj = winObj
    item.id = tostring(winObj.win:id())
    item.appName = currChoicesHolder.appName
    item.fn = fn

    return item
    -- body
end



chooser:rightClickCallback(function(row)

    if currChoicesHolder.appName == anotherAppName then return end

    local winInfo = getWinInfo(currChoicesHolder.appName)

    local subMenuOfTop = {}
    for k, winObj in pairsByKeys(winInfo, sortFunc) do
        table.insert(subMenuOfTop, 1, createMenuItem(winObj, "置顶", pushToTop))
    end

    local subMenuOfEnd = {}
    for k, winObj in pairsByKeys(winInfo, sortFunc) do
        table.insert(subMenuOfEnd, 1, createMenuItem(winObj, "置底", pushToEnd))
    end

    local subMenuOfRename = {}
    for k, winObj in pairsByKeys(winInfo, sortFunc) do
        table.insert(subMenuOfRename, 1, createMenuItem(winObj, "重命名", renameWindow))
    end

    local menu = {{ title = "修改名称", menu=subMenuOfRename },
                    {title = "-"},
                    {title="置顶调整",menu=subMenuOfTop},
                    {title="-"},
                    {title="置底调整",menu=subMenuOfEnd}}
    

   local menubar = hs.menubar.new(false):setMenu(menu)

   menubar:popupMenu(hs.mouse.getAbsolutePosition())
end)

-- 查询内容变更时回调事件
-- 这里如果输入的是数字，则触发相应的行的快捷键
-- 否则则更加输入的内容，进行过滤筛选
chooser:queryChangedCallback(function(query)
    local queryNum = tonumber(query)
    lastQueryTable[currChoicesHolder.appName] = nil
    if queryNum ~= nil and queryNum > 0 and #query == 1 then
        chooser:query(nil) -- 清空
        hs.eventtap.keyStroke({"cmd"}, query)
    elseif query then
        local finalChoices = {}
        forValue(currChoicesHolder.currChoices, function(v)
            if string.find(string.lower(v.text), string.lower(query)) ~= nil then
                table.insert(finalChoices, 1, v)
            end
        end)
        
        lastQueryTable[currChoicesHolder.appName] = query
        chooser:choices(finalChoices)
    else
        -- 为空
        local finalChoices = currChoicesHolder.currChoices
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



function createItem(winObj, appName, withAppName, bundleId)
    local item = {}
    local title = appName;
    local text = title;
    item.hasWin = false
    local winId = 0
    if winObj ~= nil then
        item.hasWin = true
        local win = winObj.win
        title = win:title();
        winId = win:id()
        -- print("title:"..title)
        if title == nil or title == "" then
            title = win:application():title()
        end

        if title == nil then title = "未知标题" end

        text = string.gsub(title, "[\r\n]+", " ")
        -- text = tostring(winObj.order)..text
        item.content = win:id()
        item.order = winObj.order
    end

    if winObj and winObj.alterText then
        text = winObj.alterText
    end

    if withAppName then
        item.text = appName .. "->" .. text
    else
        item.text = text
    end


    item.appName = appName
    item.bundleId = bundleId
    return item
end

function getBundleId(appName)
    if appName == 'Royal TSX' then
        return "com.lemonmojo.RoyalTSX.App"
    end
    local bundleId = appInfo[appName]
    if bundleId == nil then
        bundleId = getBundleIdWithAppleScript(appName)
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

function getWinInfoWithApp(app)
    local winInfo = {}
    if app == nil then
        return winInfo;
    end

    local wins = app:allWindows()

    local max = 0
    for k,win in pairs(wins) do
        
        local winObj = newWinObj(win)
        winObj.order = max
        max = max + 1

        local winId = getWinStringId(win)
        winInfo[winId] = winObj

    end

    return winInfo
end

-- 获取一个应用所有窗体信息
function getWinInfo(appName)
    local app = getApplication(appName)
    local winInfo = {}
    if app == nil then
        return winInfo;
    end

    local wins = app:allWindows()

    local max = 0
    for k,win in pairs(wins) do
        -- if win:isStandard() then
            local winObj = newWinObj(win)
            winObj.order = max
            max = max + 1

            local winId = getWinStringId(win)
            winInfo[winId] = winObj
        -- end

    end

    return winInfo
end

-- 获取窗体
function getWinById(winId, appName)
    local winInfo = getWinInfo(appName)
    return winInfo[winId].win
end

function newWinObj(win)
    return {win=win}
end

-- 添加记录一个窗体信息
function addWinInfo(win)
    print("add win info "..win:application():name())
    local winInfo = getWinInfo(win:application():title())
    local winId = getWinStringId(win)
    if winInfo[winId] == nil then

        local max = 0
        if getCount(winInfo)>0 then
            for k, v in pairs(winInfo) do
                if v.order > max then max = v.order end
            end
        end

        print(winId.." order = "..tostring(max))

        local winObj = newWinObj(win)
        winObj.order = max + 1

        winInfo[winId] = winObj

        print(tostring(getCount(winInfo)))
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
    print(win:isStandard())
    local isS = string.find(tostring(win), "hs.uielement") == nil and
                    win:isStandard()
    return isS
end

-- 获取应用信息
function getApplication(name)
    local bundleId = getBundleId(name)
    if bundleId == nil then
        print(name.."的bundleId is nil")
        return hs.application.get(name)
    end

    return hs.application.get(bundleId)
end

-- 通过AppleScript获取bundleId
function getBundleIdWithAppleScript(name)
    local source = 'tell application "' .. name ..
                       '" \nset wins to id \nend tell \nreturn wins'
    -- print(source)
    local _, bundleId, _ = hs.osascript._osascript(source, "AppleScript")
    -- print(name.." bundleId is : "..tostring(bundleId))
    return bundleId
end


function clearChooserQueryIfNeed(appName)
    if lastCallAppName ~= appName then chooser:query(nil) end

    if(lastQueryTable[appName] ~= nil and #lastQueryTable[appName]>0) then
        chooser:query(lastQueryTable[appName])
    end

    lastCallAppName = appName
end

local specialKeyMap = {}

switcher.addSpecialKeyMap = function(appName, keyTable)
    local bundleId = getBundleId(appName)
    specialKeyMap[bundleId] = keyTable 
end


-- appName用于get app用，而name用于launch用
switcher.bindApp = function(hyper, key, appName)
    bindedSpecialApp[appName] = true

    local hotKeyObject = hk.bind(hyper, key, function()
        clearChooserQueryIfNeed(appName)

        currChoicesHolder.currChoices = {}
        currChoicesHolder.appName = appName
        local wins = getWinInfo(appName)
        print("数量是"..tostring(getCount(wins)))
        print(getCount(wins))
        if getCount(wins) <= 1 then
            lauchApplication(appName)
            
            
            if(getCount(wins) == 1) then
                for k, win in pairs(wins) do
                    local winScreen = win.win:screen()
                    if(winScreen:id() ~= hs.mouse.getCurrentScreen():id()) then
                        print("设置鼠标位置")
                        local rec = winScreen:frame()
                        hs.mouse.setRelativePosition(hs.geometry(rec.w -200,rec.h/2), winScreen)
                    end
                end
            end
        else
            -- 处理独立查词窗口
            local isShaLa = false
            if appName == 'Microsoft Edge' and getCount(wins) == 2 then
                local curWin
                for k, v in pairsByKeys(wins, sortFunc) do
                    local win = v.win
                    if win:title() == '沙拉查词-独立查词窗口' or win:title() == '沙拉查词-独立查词窗口 - 睡眠' then
                        isShaLa = true
                    else
                        curWin = win
                    end
                end

                if isShaLa == true then
                    if curWin:isVisible() == false then curWin:raise() end
                     curWin:focus()
                end
            end

            if isShaLa == false then
                disableHotKey()
                for k, v in pairsByKeys(wins, sortFunc) do
                    table.insert(currChoicesHolder.currChoices, createItem(v, appName))
                end
                -- hs.alert.show(chooser == nil)@
                chooser:choices(currChoicesHolder.currChoices)
                chooser:show()
                print('show choices')
            end
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
    end
end

-- 下面的热键触发时，是否也展示已经绑定了特殊热键的的应用
switcher.showBindApp = false

local currenQueryId = 0

function ContainChinese(str) 
    local l = #string.gsub(str, "[^\128-\191]", "")
    return (l ~= 0)
end

local historyApp = {}

function showHistory(chooser)
    local currChoices = {}
    for appName, _ in pairs(historyApp) do
      local app = getApplication(appName)
        local winInfo = getWinInfoWithApp(app)
        if getCount(winInfo) == 0 then
            table.insert(currChoices, createItem(nil, appName, false, bundleId))
        else
            for k1, v1 in pairsByKeys(winInfo, sortFunc) do
                -- if isStandardWin(v1) then
                        table.insert(currChoices,
                                createItem(v1, appName, true, bundleId))
                -- end
            end
        end
    end

    chooser:choices(currChoices)
end

function search()
-- 选择框
    local chooser = hs.chooser.new(function(choice)
        if choice then
            historyApp[choice.appName] = 1
            if choice.hasWin then
                local curWin = getWinById(tostring(choice.content), choice.appName)
                if curWin:isVisible() == false then curWin:raise() end
                curWin:focus()
            else
                if choice.bundleId ~= nil then
                    hs.application.launchOrFocusByBundleID(choice.bundleId)
                else
                    local appName = choice.appName
                    lauchApplication(appName)
                end
            end
        end
    end)

    -- 查询内容变更时回调事件
    -- 这里如果输入的是数字，则触发相应的行的快捷键
    -- 否则则更加输入的内容，进行过滤筛选
    chooser:queryChangedCallback(function(query)
        if query and #query>= 1 then
            if #query <= 2 then
                if ContainChinese(query) == false then
                    chooser:choices({})
                    return
                end

            end
            currenQueryId = currenQueryId+1;
            searchForChooser(chooser, currenQueryId, query)
        else
            showHistory(chooser)
        end
       
    end)

    showHistory(chooser)

    chooser:show()
    
end

function searchForChooser(chooser, queryIndex, query)
    local spotlight = hs.spotlight.new()
    print(type(spotlight))
    spotlight:setCallback(function(obj, mes)
        if(currenQueryId ~= queryIndex) then
            print("取消当前操作"..queryIndex.."当前："..currenQueryId)
            obj:stop()
            return
        end

        if "didFinish" == mes then
            -- print(obj:count())
            print(obj:count())
            if(obj:count()>0) then
                local currChoices = {}
                local repeatT = {}
                for i=1, obj:count(), 1 do
                    if(currenQueryId ~= queryIndex) then
                        print("取消当前操作")
                        obj:stop()
                        return
                    end

                    local itemObj = obj:resultAtIndex(1)
                    local bundleId = itemObj:valueForAttribute("kMDItemCFBundleIdentifier")
                    local appName = itemObj:valueForAttribute("kMDItemDisplayName")
                    if repeatT[bundleId] == nil then
                        if switcher.showBindApp or not bindedSpecialApp[appName] then
                            local app = hs.application.get(bundleId)
                            local winInfo = getWinInfoWithApp(app)
                            if getCount(winInfo) == 0 then
                                table.insert(currChoices, createItem(nil, appName, false, bundleId))
                            else
                                for k1, v1 in pairsByKeys(winInfo, sortFunc) do
                                    -- if isStandardWin(v1.win) then
                                         table.insert(currChoices,
                                                    createItem(v1, appName, true, bundleId))
                                    -- end
                                end
                            end
                        end
                    end

                    repeatT[bundleId] = 1
                   
                end
                
                if(currenQueryId ~= queryIndex) then
                    print("取消当前操作")
                    obj:stop()
                    return
                end

                chooser:choices(currChoices)
            end

            obj:stop()
        end
    end)

    spotlight:queryString([[ (kMDItemDisplayName like [c] "*]]..query..[[*" || kMDItemFSName like [c] "*]]..query..[[*") && kMDItemContentType == "com.apple.application-bundle" ]])
    spotlight:start()
end

-- 绑定触发的热键
switcher.bindHotKey = function(hyper, key)
    -- body
    hk.bind(hyper, key, function()
        search()
        -- clearChooserQueryIfNeed(anotherAppName)

        -- currChoicesHolder.currChoices = {}
        -- currChoicesHolder.appName = anotherAppName
        -- print("trackAppSize:" .. tostring(getCount(trackApp)))
        -- disableHotKey()
        -- for i = 1, #trackApp do
        --     local appName = trackApp[i]
        --     if switcher.showBindApp or not bindedSpecialApp[appName] then
        --         local winInfo = getWinInfo(appName)
        --         if getCount(winInfo) == 0 then
        --             table.insert(currChoicesHolder.currChoices, createItem(nil, appName))
        --         else
        --             for k1, v1 in pairsByKeys(winInfo, sortFunc) do
        --                 table.insert(currChoicesHolder.currChoices,
        --                              createItem(v1, appName, true))
        --             end
        --         end
        --     end
        -- end

        -- chooser:choices(currChoicesHolder.currChoices)
        -- chooser:show()
    end)
end




return switcher
