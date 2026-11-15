sub init()
    m.groupList = m.top.findNode("groupList")
    m.channelList = m.top.findNode("channelList")
    m.status = m.top.findNode("status")
    m.video = m.top.findNode("video")
    m.groups = invalid
    m.currentIndex = 0
    m.xtream = invalid
    m.epgCache = {}
    m.guide = m.top.findNode("guide")
    m.osd = m.top.findNode("osd")

    ' Wait briefly after the highlight moves before asking for guide data.
    m.guideTimer = CreateObject("roSGNode", "Timer")
    m.guideTimer.duration = 0.35
    m.guideTimer.observeField("fire", "requestGuideForFocused")
    m.osdTimer = CreateObject("roSGNode", "Timer")
    m.osdTimer.duration = 6
    m.osdTimer.observeField("fire", "hideOsd")
    m.channelList.observeField("itemFocused", "onChannelFocused")

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
    m.xtream = m.task.xtream
    if m.xtream <> invalid and m.xtream.base = invalid then m.xtream = invalid
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
    showOsd(ch)
end sub

sub stopVideo()
    m.video.control = "stop"
    m.video.visible = false
    hideOsd()
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

' ---------- TV guide (now / next) ----------

sub onChannelFocused()
    m.guideTimer.control = "stop"
    if m.xtream = invalid then return
    m.guideTimer.control = "start"
end sub

sub requestGuideForFocused()
    group = m.channelList.content
    if group = invalid then return
    ch = group.getChild(m.channelList.itemFocused)
    if ch = invalid then return
    m.guideChannelId = ch.id
    cached = cachedGuide(ch.id)
    if cached <> invalid then
        renderGuide(cached)
    else
        m.top.findNode("guideNow").text = "Loading guide..."
        m.top.findNode("guideTime").text = ""
        m.top.findNode("guideNext").text = ""
        m.top.findNode("guideBar").width = 0
        m.guide.visible = true
        fetchGuide(ch.id)
    end if
end sub

function cachedGuide(sid as String) as Dynamic
    e = m.epgCache[sid]
    if e = invalid then return invalid
    now = CreateObject("roDateTime").AsSeconds()
    ' Refetch after 10 minutes or once the current show has ended.
    if now - e.fetched > 600 then return invalid
    if e.items.Count() > 0 and e.items[0].stop <= now then return invalid
    return e
end function

sub fetchGuide(sid as String)
    if sid = "" then return
    if m.pending = invalid then m.pending = {}
    if m.pending[sid] <> invalid then return
    t = CreateObject("roSGNode", "IPTVLib:EpgTask")
    if t = invalid then t = CreateObject("roSGNode", "EpgTask")
    if t = invalid then return
    t.xtream = m.xtream
    t.streamId = sid
    t.userAgent = m.userAgent
    t.observeField("result", "onGuideResult")
    m.pending[sid] = t ' keep a reference so it isn't freed
    t.control = "RUN"
end sub

sub onGuideResult(event as Object)
    r = event.getData()
    if r = invalid then return
    if m.pending <> invalid then m.pending.Delete(r.streamId)
    now = CreateObject("roDateTime").AsSeconds()
    items = []
    for each it in r.items
        if it.stop > now then items.Push(it)
    end for
    entry = { fetched: now, items: items }
    m.epgCache[r.streamId] = entry
    if r.streamId = m.guideChannelId then renderGuide(entry)
    if m.osd.visible and r.streamId = m.osdChannelId then renderOsd(entry)
end sub

sub renderGuide(entry as Object)
    info = guideLines(entry)
    m.top.findNode("guideNow").text = info.now
    m.top.findNode("guideTime").text = info.time
    m.top.findNode("guideNext").text = info.next
    m.top.findNode("guideBar").width = Int(400 * info.progress)
    m.guide.visible = true
end sub

sub showOsd(ch as Object)
    m.osdChannelId = ch.id
    m.top.findNode("osdChannel").text = ch.title
    m.top.findNode("osdNow").text = ""
    m.top.findNode("osdTime").text = ""
    m.top.findNode("osdNext").text = ""
    m.top.findNode("osdBar").width = 0
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
    if m.xtream = invalid then return
    cached = cachedGuide(ch.id)
    if cached <> invalid then
        renderOsd(cached)
    else
        m.top.findNode("osdNow").text = "Loading guide..."
        fetchGuide(ch.id)
    end if
end sub

sub renderOsd(entry as Object)
    info = guideLines(entry)
    m.top.findNode("osdNow").text = info.now
    m.top.findNode("osdTime").text = info.time
    m.top.findNode("osdNext").text = info.next
    m.top.findNode("osdBar").width = Int(600 * info.progress)
end sub

sub hideOsd()
    m.osd.visible = false
end sub

function guideLines(entry as Object) as Object
    out = { now: "No guide info for this channel", time: "", next: "", progress: 0 }
    items = entry.items
    if items = invalid or items.Count() = 0 then return out
    cur = items[0]
    nowTs = CreateObject("roDateTime").AsSeconds()
    out.now = "Now: " + cur.title
    out.time = fmtTime(cur.start) + " - " + fmtTime(cur.stop)
    minsLeft = Int((cur.stop - nowTs) / 60)
    if minsLeft >= 0 then out.time = out.time + "   (" + minsLeft.ToStr() + " min left)"
    if cur.stop > cur.start then
        p = (nowTs - cur.start) / (cur.stop - cur.start)
        if p < 0 then p = 0
        if p > 1 then p = 1
        out.progress = p
    end if
    if items.Count() > 1 then out.next = "Next: " + fmtTime(items[1].start) + "  " + items[1].title
    return out
end function

function fmtTime(ts as Integer) as String
    dt = CreateObject("roDateTime")
    dt.FromSeconds(ts)
    dt.ToLocalTime()
    h = dt.GetHours()
    mins = dt.GetMinutes()
    suffix = "AM"
    if h >= 12 then suffix = "PM"
    h = h MOD 12
    if h = 0 then h = 12
    mm = mins.ToStr()
    if mins < 10 then mm = "0" + mm
    return h.ToStr() + ":" + mm + " " + suffix
end function
