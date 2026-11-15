' IPTV Player v7 - Apple TV style shell: tabs, screens, details, playback.

sub init()
    m.screensHost = m.top.findNode("screens")
    m.detailsHost = m.top.findNode("detailsHost")
    m.nav = m.top.findNode("nav")
    m.status = m.top.findNode("status")
    m.video = m.top.findNode("video")
    m.osd = m.top.findNode("osd")
    m.clock = m.top.findNode("clock")
    m.status.font = makeFont(34, false)
    m.clock.font = makeFont(30, false)
    m.top.findNode("osdChannel").font = makeFont(48, true)
    m.top.findNode("osdNow").font = makeFont(32, false)
    m.top.findNode("osdTime").font = makeFont(26, false)
    m.top.findNode("osdNext").font = makeFont(26, false)

    m.tabNames = ["Sports", "Live TV", "Movies", "TV Shows"]
    m.tabKinds = ["sports", "live", "movies", "series"]
    m.screens = [invalid, invalid, invalid, invalid]
    m.current = 0
    m.details = invalid
    m.epgCache = {}
    m.pending = {}
    m.playingLive = false
    m.xtream = invalid
    m.ua = ""

    m.nav.items = m.tabNames

    m.osdTimer = CreateObject("roSGNode", "Timer")
    m.osdTimer.duration = 6
    m.osdTimer.observeField("fire", "hideOsd")
    m.clockTimer = CreateObject("roSGNode", "Timer")
    m.clockTimer.duration = 20
    m.clockTimer.repeat = true
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    updateClock()

    m.video.observeField("state", "onVideoState")

    url = loadSetting("playlistUrl")
    if url = "" then
        showUrlDialog()
    else
        startWithUrl(url)
    end if
end sub

sub updateClock()
    m.clock.text = fmtTime(CreateObject("roDateTime").AsSeconds())
end sub

' ---------- sign in ----------

sub startWithUrl(url as String)
    for each s in m.screens
        if s <> invalid then m.screensHost.removeChild(s)
    end for
    m.screens = [invalid, invalid, invalid, invalid]
    m.nav.visible = false
    m.xtream = parseXtream(url)
    if m.xtream = invalid then
        showMessage("This app needs an Xtream Codes login link." + Chr(10) + "Press * to enter it.")
        return
    end if
    showMessage("Signing in...  (v7.2)")
    t = CreateObject("roSGNode", "DataTask")
    t.xtream = m.xtream
    t.request = { mode: "login" }
    t.observeField("result", "onLogin")
    m.loginTask = t
    t.control = "RUN"
end sub

sub showMessage(text as String)
    m.status.text = text
    m.status.visible = true
    m.top.setFocus(true)
end sub

sub onLogin()
    r = m.loginTask.result
    if r.ok <> true then
        showMessage("Couldn't sign in: " + r.error + Chr(10) + "Press * to check your login.")
        return
    end if
    m.ua = r.ua
    m.status.visible = false
    m.nav.visible = true
    switchTab(0)
    focusScreen()
end sub

' ---------- tabs ----------

sub switchTab(i as Integer)
    n = m.tabKinds.Count()
    if i < 0 then i = n - 1
    if i >= n then i = 0
    for each s in m.screens
        if s <> invalid then s.visible = false
    end for
    if m.screens[i] = invalid then
        s = CreateObject("roSGNode", "BrowseScreen")
        s.kind = m.tabKinds[i]
        s.xtream = m.xtream
        s.userAgent = m.ua
        s.observeField("selectedInfo", "onSelected")
        m.screensHost.appendChild(s)
        m.screens[i] = s
        s.start = true
    end if
    m.screens[i].visible = true
    m.current = i
    m.nav.selectedIndex = i
end sub

sub focusNav()
    m.nav.active = true
    m.nav.setFocus(true)
end sub

sub focusScreen()
    m.nav.active = false
    s = m.screens[m.current]
    if s <> invalid then s.setFocus(true)
end sub

' ---------- selection / details ----------

sub onSelected(event as Object)
    info = event.getData()
    item = info.item
    if item.kind = "live" then
        playLive(info.row, info.index)
    else
        openDetails(item)
    end if
end sub

sub openDetails(item as Object)
    d = CreateObject("roSGNode", "DetailsScreen")
    d.xtream = m.xtream
    d.userAgent = m.ua
    d.observeField("playRequest", "onPlayRequest")
    m.detailsHost.appendChild(d)
    d.item = item
    m.details = d
    m.nav.visible = false
    m.clock.visible = false
    d.setFocus(true)
end sub

sub closeDetails()
    if m.details = invalid then return
    m.detailsHost.removeChild(m.details)
    m.details = invalid
    m.nav.visible = true
    m.clock.visible = true
    focusScreen()
end sub

sub onPlayRequest(event as Object)
    req = event.getData()
    m.playingLive = false
    startPlayback(req.url, req.title, req.format, false)
    showOsdText(req.title, req.subtitle)
end sub

' ---------- playback ----------

sub startPlayback(url as String, title as String, fmt as String, isLive as Boolean)
    ' Remember the request so a failed movie/episode can be retried differently.
    m.playReq = { url: url, title: title, fmt: fmt, live: isLive }
    m.attempt = 0
    playAttempt()
end sub

function altFormat(fmt as String) as String
    if fmt = "mkv" then return "mp4"
    if fmt = "mp4" then return "mkv"
    if fmt = "hls" then return "mp4"
    return "mp4"
end function

sub playAttempt()
    req = m.playReq
    fmt = req.fmt
    sendUa = true
    ' attempt 0: as given  /  1: without the custom User-Agent  /  2: other container type
    if m.attempt = 1 then sendUa = false
    if m.attempt = 2 then fmt = altFormat(req.fmt)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = req.url
    content.title = req.title
    content.streamFormat = fmt
    content.live = req.live
    if sendUa and m.ua <> "" then content.HttpHeaders = ["User-Agent:" + m.ua]
    print "IPTV play attempt "; m.attempt; " fmt="; fmt; " ua="; sendUa; " url="; req.url
    m.video.control = "stop"
    m.video.content = content
    m.video.visible = true
    m.video.setFocus(true)
    m.video.control = "play"
end sub

sub playLive(row as Object, index as Integer)
    count = row.getChildCount()
    if count = 0 then return
    if index < 0 then index = count - 1
    if index >= count then index = 0
    ch = row.getChild(index)
    if ch.kind <> "live" then return
    m.zapRow = row
    m.zapIndex = index
    m.playingLive = true
    startPlayback(ch.url, ch.title, "hls", true)
    showOsd(ch)
end sub

sub stopVideo()
    m.video.control = "stop"
    m.video.visible = false
    hideOsd()
    if m.details <> invalid then
        m.details.setFocus(true)
    else
        focusScreen()
    end if
end sub

sub onVideoState()
    if m.video.state <> "error" then return
    code = m.video.errorCode
    msg = m.video.errorMsg
    detail = ""
    if m.video.errorStr <> invalid then detail = m.video.errorStr
    print "IPTV playback error "; code; " "; msg; " | "; detail
    if m.playReq <> invalid and not m.playReq.live and m.attempt < 2 then
        m.attempt = m.attempt + 1
        playAttempt()
        return
    end if
    stopVideo()
    text = "Couldn't play that (error " + asStr(code) + "): " + msg
    if detail <> "" then text = text + Chr(10) + detail
    toast(text)
end sub

sub toast(text as String)
    m.status.text = text
    m.status.visible = true
    m.toastTimer = CreateObject("roSGNode", "Timer")
    m.toastTimer.duration = 8
    m.toastTimer.observeField("fire", "hideToast")
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.status.visible = false
end sub

' ---------- on-screen info bar ----------

sub showOsdText(title as String, subtitle as Dynamic)
    m.osdChannelId = ""
    m.top.findNode("osdChannel").text = title
    if subtitle = invalid then subtitle = ""
    m.top.findNode("osdNow").text = subtitle
    m.top.findNode("osdTime").text = ""
    m.top.findNode("osdNext").text = ""
    m.top.findNode("osdBar").visible = false
    m.top.findNode("osdBarBg").visible = false
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
end sub

sub showOsd(ch as Object)
    showOsdText(ch.title, "")
    m.osdChannelId = ch.id
    g = freshGuide(m.epgCache, ch.id)
    if g <> invalid then
        renderOsd(g)
    else
        m.top.findNode("osdNow").text = "Loading guide..."
        fetchGuide(ch.id)
    end if
end sub

sub fetchGuide(sid as String)
    if sid = "" or m.pending[sid] <> invalid then return
    t = CreateObject("roSGNode", "EpgTask")
    t.xtream = m.xtream
    t.streamId = sid
    t.userAgent = m.ua
    t.observeField("result", "onGuideResult")
    m.pending[sid] = t
    t.control = "RUN"
end sub

sub onGuideResult(event as Object)
    r = event.getData()
    m.pending.Delete(r.streamId)
    entry = { fetched: CreateObject("roDateTime").AsSeconds(), items: r.items }
    m.epgCache[r.streamId] = entry
    if m.osd.visible and r.streamId = m.osdChannelId then renderOsd(entry)
end sub

sub renderOsd(entry as Object)
    lines = guideLines(entry)
    m.top.findNode("osdNow").text = lines.now
    m.top.findNode("osdTime").text = lines.time
    m.top.findNode("osdNext").text = lines.next
    hasShow = entry.items.Count() > 0
    m.top.findNode("osdBar").visible = hasShow
    m.top.findNode("osdBarBg").visible = hasShow
    m.top.findNode("osdBar").width = Int(600 * lines.progress)
end sub

sub hideOsd()
    m.osd.visible = false
end sub

' ---------- playlist URL ----------

sub showUrlDialog()
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = "IPTV login link"
    dlg.message = ["Enter your Xtream Codes link (http://server/get.php?username=...&password=...)."]
    dlg.buttons = ["Save", "Cancel"]
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
        startWithUrl(url)
    else if m.xtream = invalid then
        showMessage("No login set." + Chr(10) + "Press * to add one.")
    else
        focusScreen()
    end if
end sub

' ---------- remote ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.video.visible then
        if key = "back" then
            stopVideo()
            return true
        end if
        if m.playingLive then
            if key = "up" then
                playLive(m.zapRow, m.zapIndex - 1)
                return true
            else if key = "down" then
                playLive(m.zapRow, m.zapIndex + 1)
                return true
            else if key = "OK" or key = "info" then
                showOsd(m.zapRow.getChild(m.zapIndex))
                return true
            end if
        end if
        return false
    end if

    if key = "options" then
        showUrlDialog()
        return true
    end if

    if m.details <> invalid then
        if key = "back" then
            closeDetails()
            return true
        end if
        return false
    end if

    if not m.nav.visible then return false

    if m.nav.isInFocusChain() then
        if key = "left" then
            switchTab(m.current - 1)
            return true
        else if key = "right" then
            switchTab(m.current + 1)
            return true
        else if key = "down" or key = "OK" then
            focusScreen()
            return true
        end if
        return false
    end if

    if key = "up" or key = "back" then
        focusNav()
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
