sub init()
    m.groupList = m.top.findNode("groupList")
    m.channelList = m.top.findNode("channelList")
    m.status = m.top.findNode("status")
    m.video = m.top.findNode("video")
    m.groups = invalid
    m.currentIndex = 0

    m.groupList.observeField("itemFocused", "onGroupFocused")
    m.groupList.observeField("itemSelected", "onGroupSelected")
    m.channelList.observeField("itemSelected", "onChannelSelected")
    m.video.observeField("state", "onVideoState")

    url = loadSetting("playlistUrl")
    if url = "" then
        showUrlDialog()
    else
        loadPlaylist(url)
    end if
end sub

' ---------- playlist ----------

sub loadPlaylist(url as String)
    m.status.text = "Loading playlist..."
    m.status.visible = true
    m.task = CreateObject("roSGNode", "IPTVLib:PlaylistTask")
    if m.task = invalid then m.task = CreateObject("roSGNode", "PlaylistTask")
    m.task.url = url
    m.task.observeField("done", "onPlaylistLoaded")
    m.task.observeField("progress", "onPlaylistProgress")
    m.task.control = "RUN"
end sub

sub onPlaylistProgress()
    m.status.text = m.task.progress
end sub

sub onPlaylistLoaded()
    if m.task.error <> "" then
        m.status.text = "Couldn't load playlist:" + Chr(10) + m.task.error + Chr(10) + Chr(10) + "Press * to edit the URL."
        m.status.visible = true
        m.top.setFocus(true)
        return
    end if

    m.groups = m.task.result
    m.userAgent = m.task.userAgent
    groupContent = CreateObject("roSGNode", "ContentNode")
    for i = 0 to m.groups.getChildCount() - 1
        g = m.groups.getChild(i)
        item = groupContent.createChild("ContentNode")
        item.title = g.title + "  (" + g.getChildCount().ToStr() + ")"
    end for

    m.status.visible = false
    m.groupList.content = groupContent
    m.channelList.content = m.groups.getChild(0)
    m.groupList.setFocus(true)
end sub

sub onGroupFocused()
    if m.groups = invalid then return
    m.channelList.content = m.groups.getChild(m.groupList.itemFocused)
    m.channelList.jumpToItem = 0
end sub

sub onGroupSelected()
    m.channelList.setFocus(true)
end sub

' ---------- playback ----------

sub onChannelSelected()
    playChannel(m.channelList.itemSelected)
end sub

sub playChannel(index as Integer)
    group = m.channelList.content
    if group = invalid or group.getChildCount() = 0 then return
    count = group.getChildCount()
    if index < 0 then index = count - 1
    if index >= count then index = 0
    m.currentIndex = index
    ch = group.getChild(index)

    content = CreateObject("roSGNode", "ContentNode")
    content.url = ch.url
    content.title = ch.title
    content.streamFormat = ch.streamFormat
    content.live = true
    if m.userAgent <> invalid and m.userAgent <> "" then
        content.HttpHeaders = ["User-Agent:" + m.userAgent]
    end if

    m.video.control = "stop"
    m.video.content = content
    m.video.visible = true
    m.video.setFocus(true)
    m.video.control = "play"
    m.channelList.jumpToItem = index
end sub

sub stopVideo()
    m.video.control = "stop"
    m.video.visible = false
    m.channelList.setFocus(true)
end sub

sub onVideoState()
    if m.video.state = "error" then
        msg = m.video.errorMsg
        stopVideo()
        m.status.text = "Playback error: " + msg
        m.status.visible = true
        m.statusTimer = CreateObject("roSGNode", "Timer")
        m.statusTimer.duration = 4
        m.statusTimer.observeField("fire", "hideStatus")
        m.statusTimer.control = "start"
    end if
end sub

sub hideStatus()
    if m.groups <> invalid then m.status.visible = false
end sub

' ---------- playlist URL dialog ----------

sub showUrlDialog()
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = "Playlist URL"
    dlg.message = ["Enter your M3U playlist URL. Tip: the Roku mobile app lets you type with your phone keyboard."]
    dlg.buttons = ["Load", "Cancel"]
    current = loadSetting("playlistUrl")
    if current = "" then current = "http://"
    dlg.text = current
    dlg.observeField("buttonSelected", "onDialogButton")
    m.top.getScene().dialog = dlg
end sub

sub onDialogButton()
    dlg = m.top.getScene().dialog
    url = dlg.text.Trim()
    pressed = dlg.buttonSelected
    dlg.close = true

    if pressed = 0 and url <> "" and url <> "http://" then
        saveSetting("playlistUrl", url)
        loadPlaylist(url)
    else if m.groups = invalid then
        m.status.text = "No playlist loaded." + Chr(10) + "Press * to add one."
        m.status.visible = true
        m.top.setFocus(true)
    else
        m.groupList.setFocus(true)
    end if
end sub

' ---------- remote keys ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.video.visible then
        if key = "back" then
            stopVideo()
            return true
        else if key = "up" then
            playChannel(m.currentIndex - 1)
            return true
        else if key = "down" then
            playChannel(m.currentIndex + 1)
            return true
        end if
        return false
    end if

    if key = "options" then
        showUrlDialog()
        return true
    else if key = "right" and m.groupList.hasFocus() then
        m.channelList.setFocus(true)
        return true
    else if key = "left" and m.channelList.hasFocus() then
        m.groupList.setFocus(true)
        return true
    end if
    return false
end function

' ---------- settings ----------

function loadSetting(key as String) as String
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    if sec.Exists(key) then return sec.Read(key)
    return ""
end function

sub saveSetting(key as String, value as String)
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    sec.Write(key, value)
    sec.Flush()
end sub
