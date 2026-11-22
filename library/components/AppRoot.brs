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
    m.liveBadge = m.top.findNode("liveBadge")
    m.liveBadge.font = makeFont(28, true)
    m.splash = m.top.findNode("splash")
    m.splashFade = m.top.findNode("splashFade")
    m.splashFade.observeField("state", "onSplashFade")
    m.top.findNode("splashTitle").font = makeFont(48, true)
    m.top.findNode("splashSub").font = makeFont(28, false)
    m.liveCount = 0
    m.top.findNode("osdChannel").font = makeFont(54, true)
    m.top.findNode("osdNow").font = makeFont(32, false)
    m.top.findNode("osdTime").font = makeFont(28, false)
    m.top.findNode("osdNext").font = makeFont(28, false)
    m.top.findNode("osdLiveText").font = makeFont(28, true)
    m.top.findNode("osdTag").font = makeFont(28, true)
    m.top.findNode("stripTitle").font = makeFont(32, true)
    m.strip = m.top.findNode("strip")
    m.stripList = m.top.findNode("stripList")
    m.stripList.itemComponentName = "PosterCard"
    m.stripList.numRows = 1
    m.stripList.itemSize = [1820, 300]
    m.stripList.rowItemSize = [[360, 202]]
    m.stripList.rowItemSpacing = [[40, 0]]
    m.stripList.drawFocusFeedback = false
    m.stripList.showRowLabel = [false]
    m.stripList.rowFocusAnimationStyle = "floatingFocus"
    m.stripList.observeField("rowItemSelected", "onStripSelected")

    m.tabNames = ["Sports", "Later Today", "Live TV", "Guide", "Movies", "TV Shows", "Settings"]
    m.tabKinds = ["sports", "later", "live", "guide", "movies", "series", "settings"]
    m.screens = [invalid, invalid, invalid, invalid, invalid, invalid, invalid]
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
    m.video.notificationInterval = 5
    m.video.observeField("position", "onVideoPosition")
    m.lastSave = 0

    url = loadSetting("playlistUrl")
    if url = "" then
        showUrlDialog()
    else
        startWithUrl(url)
    end if
end sub

sub onLiveCount(event as Object)
    m.liveCount = event.getData()
    updateLiveBadge()
end sub

sub updateLiveBadge()
    if false then
        m.liveBadge.text = "● " + m.liveCount.ToStr() + " live"
        m.liveBadge.visible = true
    else
        m.liveBadge.visible = false
    end if
end sub

function appVersion() as String
    return "v13.6"
end function

sub onSettingsAction(event as Object)
    a = event.getData()
    if a = "login" then
        showUrlDialog()
    else if a = "reload" then
        ' let the Settings screen finish its own handler before tearing everything down
        m.reloadTimer = CreateObject("roSGNode", "Timer")
        m.reloadTimer.duration = 0.5
        m.reloadTimer.observeField("fire", "doReload")
        m.reloadTimer.control = "start"
    else if a = "continue" then
        if m.screens[4] <> invalid then m.screens[4].refreshContinue = true
        if m.screens[5] <> invalid then m.screens[5].refreshContinue = true
    else if a = "favs" then
        if m.screens[0] <> invalid then m.screens[0].refreshFavs = true
    end if
end sub

sub doReload()
    saveSetting("lastTab", "0")
    url = loadSetting("playlistUrl")
    if url <> "" then startWithUrl(url)
end sub

sub updateClock()
    m.clock.text = fmtTime(CreateObject("roDateTime").AsSeconds())
end sub

' ---------- sign in ----------

sub startWithUrl(url as String)
    for each s in m.screens
        if s <> invalid then m.screensHost.removeChild(s)
    end for
    m.screens = [invalid, invalid, invalid, invalid, invalid, invalid, invalid]
    m.nav.visible = false
    m.xtream = parseXtream(url)
    if m.xtream = invalid then
        showMessage("This app needs an Xtream Codes login link." + Chr(10) + "Press * to enter it.")
        return
    end if
    showMessage("Signing in...  (" + appVersion() + ")")
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
    lastErr = loadSetting("lastError")
    m.nav.visible = true
    startTab = Val(loadSetting("lastTab"))
    if startTab < 0 or startTab >= m.tabKinds.Count() then startTab = 0
    switchTab(startTab)
    focusScreen()
    m.preloadTimer = CreateObject("roSGNode", "Timer")
    m.preloadTimer.duration = 2.5
    m.preloadTimer.observeField("fire", "preloadTabs")
    m.preloadTimer.control = "start"
    if lastErr <> "" then
        toast("Note for Claude - last error: " + lastErr)
        sec = CreateObject("roRegistrySection", "IPTVPlayer")
        sec.Delete("lastError")
        sec.Flush()
    end if
end sub

' ---------- tabs ----------

function isPosterTab(i as Integer) as Boolean
    k = m.tabKinds[i]
    return (k = "movies" or k = "series")
end function

function ensureScreen(i as Integer) as Object
    if m.screens[i] = invalid then
        if m.tabKinds[i] = "settings" then
            s = CreateObject("roSGNode", "SettingsScreen")
            s.version = appVersion()
            s.observeField("action", "onSettingsAction")
        else if m.tabKinds[i] = "guide" then
            s = CreateObject("roSGNode", "GuideScreen")
        else
            s = CreateObject("roSGNode", "BrowseScreen")
        end if
        s.kind = m.tabKinds[i]
        s.xtream = m.xtream
        s.userAgent = m.ua
        s.visible = false
        s.observeField("selectedInfo", "onSelected")
        m.screensHost.appendChild(s)
        m.screens[i] = s
        s.start = true
    end if
    return m.screens[i]
end function

' Build the other tabs quietly so switching is instant.
sub preloadTabs()
    ' only the light, channel-based tabs; poster tabs load when opened (memory)
    ' one tab at a time, 10s apart, so they don't fight over the provider's connection limit
    if isPosterTab(m.current) then return ' never rebuild the other tabs behind Movies / TV Shows
    for i = 0 to m.tabKinds.Count() - 1
        k = m.tabKinds[i]
        if k <> "movies" and k <> "series" and k <> "guide" and k <> "settings" and m.screens[i] = invalid then
            ensureScreen(i)
            m.preloadTimer.duration = 10
            m.preloadTimer.control = "start"
            return
        end if
    end for
end sub

sub switchTab(i as Integer)
    n = m.tabKinds.Count()
    if i < 0 then i = n - 1
    if i >= n then i = 0
    for each s in m.screens
        if s <> invalid then s.visible = false
    end for
    ' Memory: poster tabs (Movies / TV Shows) are heavy, so while one is open every
    ' other screen is thrown away, and leaving them throws the poster screens away.
    heavy = isPosterTab(i)
    for j = 0 to m.screens.Count() - 1
        if j <> i and m.screens[j] <> invalid then
            if heavy or isPosterTab(j) or m.tabKinds[j] = "guide" or m.tabKinds[j] = "settings" then
                m.screensHost.removeChild(m.screens[j])
                m.screens[j] = invalid
            end if
        end if
    end for
    ensureScreen(i)
    m.screens[i].visible = true
    m.current = i
    m.nav.selectedIndex = i
    saveSetting("lastTab", i.ToStr())
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
    else if item.kind = "resume" then
        playVodRequest({ url: item.url, title: item.title, format: item.fmt, subtitle: item.subline, resumeKey: item.resumeKey, startAt: item.startAt, poster: item.HDPosterUrl })
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
    m.liveBadge.visible = false
    d.setFocus(true)
end sub

sub closeDetails()
    if m.details = invalid then return
    m.detailsHost.removeChild(m.details)
    m.details = invalid
    m.nav.visible = true
    m.clock.visible = true
    updateLiveBadge()
    focusScreen()
end sub

sub onPlayRequest(event as Object)
    req = event.getData()
    playVodRequest(req)
end sub

sub playVodRequest(req as Object)
    m.playingLive = false
    m.resumeMeta = req
    m.resumeKey = ""
    if req.resumeKey <> invalid then m.resumeKey = req.resumeKey
    m.startAt = 0
    if req.startAt <> invalid then m.startAt = req.startAt
    m.nextLogo = ""
    if req.poster <> invalid then m.nextLogo = asStr(req.poster)
    startPlayback(req.url, req.title, req.format, false)
    sub2 = req.subtitle
    if m.startAt > 0 then sub2 = "Resuming at " + fmtClock(m.startAt)
    showOsdText(req.title, sub2)
end sub

' ---------- playback ----------

sub startPlayback(url as String, title as String, fmt as String, isLive as Boolean)
    ' Remember the request so a failed movie/episode can be retried differently.
    m.playReq = { url: url, title: title, fmt: fmt, live: isLive }
    m.attempt = 0
    logo = ""
    if m.nextLogo <> invalid then logo = m.nextLogo
    m.nextLogo = ""
    showSplash(title, logo)
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
    url = req.url
    ' live fallback: if the HLS playlist can't be decoded, try the raw transport stream once
    if req.live and m.attempt = 1 and Right(url, 5) = ".m3u8" then
        url = Left(url, Len(url) - 5) + ".ts"
        fmt = "ts"
    end if
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.title = req.title
    content.streamFormat = fmt
    content.live = req.live
    if sendUa and m.ua <> "" then content.HttpHeaders = ["User-Agent:" + m.ua]
    if not req.live and m.startAt <> invalid and m.startAt > 0 then content.PlayStart = m.startAt
    print "IPTV play attempt "; m.attempt; " fmt="; fmt; " ua="; sendUa; " url="; url
    ' live TV: the player must not seek on replay/rewind (replay = previous channel)
    m.video.enableTrickPlay = not req.live
    m.video.enableUI = not req.live
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
    ' remember the channel we're leaving (for the replay button)
    if m.playingLive and m.zapRow <> invalid then
        cur = m.zapRow.getChild(m.zapIndex)
        if cur <> invalid and cur.id <> ch.id then
            m.prevCh = { row: m.zapRow, index: m.zapIndex, id: cur.id, url: cur.url, title: cur.title, logo: asStr(cur.HDPosterUrl) }
        end if
    end if
    m.zapRow = row
    m.zapIndex = index
    m.playingLive = true
    m.resumeKey = ""
    m.startAt = 0
    m.nextLogo = asStr(ch.HDPosterUrl)
    startPlayback(ch.url, ch.title, "hls", true)
    showOsd(ch)
end sub

sub goPrevChannel()
    p = m.prevCh
    if p = invalid then
        banner("No previous channel yet")
        return
    end if
    ' same row still loaded and unchanged -> normal zap
    c = invalid
    if p.row <> invalid then c = p.row.getChild(p.index)
    if c <> invalid and c.id = p.id then
        playLive(p.row, p.index)
        return
    end if
    ' otherwise play it directly
    cur = m.zapRow.getChild(m.zapIndex)
    if cur <> invalid then m.prevCh = { row: m.zapRow, index: m.zapIndex, id: cur.id, url: cur.url, title: cur.title, logo: asStr(cur.HDPosterUrl) }
    m.nextLogo = p.logo
    startPlayback(p.url, p.title, "hls", true)
    showOsdText(p.title, "")
end sub

sub stopVideo()
    m.strip.visible = false
    saveProgress()
    m.video.control = "stop"
    m.video.visible = false
    hideSplash(false)
    hideOsd()
    ' Continue Watching rows pick up the new spot
    if m.screens[4] <> invalid then m.screens[4].refreshContinue = true
    if m.screens[5] <> invalid then m.screens[5].refreshContinue = true
    if m.details <> invalid then
        m.details.refresh = true
        m.details.setFocus(true)
    else
        focusScreen()
    end if
end sub

sub onVideoPosition()
    if m.playingLive or m.resumeKey = invalid or m.resumeKey = "" then return
    posSecs = Int(m.video.position)
    if Abs(posSecs - m.lastSave) >= 15 then saveProgress()
end sub

sub saveProgress()
    if m.playingLive or m.resumeKey = invalid or m.resumeKey = "" then return
    posSecs = Int(m.video.position)
    dur = Int(m.video.duration)
    if posSecs <= 0 then return
    m.lastSave = posSecs
    saveResume(m.resumeKey, posSecs, dur, m.resumeMeta)
end sub

sub showSplash(title as String, logo as String)
    m.splashFade.control = "stop"
    m.splash.opacity = 1.0
    m.top.findNode("splashTitle").text = title
    m.top.findNode("splashLogo").uri = logo
    m.splash.visible = true
end sub

sub hideSplash(fade as Boolean)
    if not m.splash.visible then return
    if fade then
        m.splashFade.control = "start"
    else
        m.splashFade.control = "stop"
        m.splash.visible = false
    end if
end sub

sub onSplashFade()
    if m.splashFade.state = "stopped" and m.splash.opacity < 0.05 then m.splash.visible = false
end sub

sub onVideoState()
    if m.video.state = "playing" then hideSplash(true)
    if m.video.state = "finished" then
        if m.resumeKey <> invalid and m.resumeKey <> "" then saveResume(m.resumeKey, 0, 0)
        m.resumeKey = ""
        stopVideo()
        return
    end if
    if m.video.state <> "error" then return
    code = m.video.errorCode
    msg = m.video.errorMsg
    detail = ""
    if m.video.errorStr <> invalid then detail = m.video.errorStr
    print "IPTV playback error "; code; " "; msg; " | "; detail
    liveRetry = (m.playReq <> invalid and m.playReq.live and m.attempt = 0 and Right(m.playReq.url, 5) = ".m3u8")
    if m.playReq <> invalid and not liveRetry and (m.playReq.live or m.attempt >= 2) then hideSplash(false)
    if liveRetry then
        m.attempt = 1
        playAttempt()
        return
    end if
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
    m.toastTimer.duration = 3
    m.toastTimer.observeField("fire", "hideToast")
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.status.visible = false
end sub

' Short confirmation pill near the top of the screen.
sub banner(text as String)
    b = m.top.findNode("banner")
    t = m.top.findNode("bannerText")
    bg = m.top.findNode("bannerBg")
    if m.bannerFont = invalid then m.bannerFont = makeFont(30, true)
    t.font = m.bannerFont
    w = 120 + Len(text) * 17
    if w > 1500 then w = 1500
    bg.width = w
    t.width = w
    b.translation = [Int((1920 - w) / 2), 160]
    t.text = text
    b.visible = true
    if m.bannerTimer = invalid then
        m.bannerTimer = CreateObject("roSGNode", "Timer")
        m.bannerTimer.duration = 2.5
        m.bannerTimer.observeField("fire", "hideBanner")
    end if
    m.bannerTimer.control = "stop"
    m.bannerTimer.control = "start"
end sub

sub hideBanner()
    m.top.findNode("banner").visible = false
end sub

' ---------- on-screen info bar ----------

sub showOsdText(title as String, subtitle as Dynamic)
    m.osdChannelId = ""
    m.top.findNode("osdChannel").text = title
    if subtitle = invalid then subtitle = ""
    m.top.findNode("osdNow").text = subtitle
    m.top.findNode("osdTime").text = ""
    m.top.findNode("osdNext").text = ""
    m.top.findNode("osdTag").text = ""
    m.top.findNode("osdLive").visible = false
    m.top.findNode("osdLogo").uri = ""
    m.top.findNode("osdBar").visible = false
    m.top.findNode("osdBarBg").visible = false
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
end sub

sub showOsd(ch as Object)
    title = ch.title
    if ch.cardType = "game" and ch.team2 <> invalid and ch.team2 <> "" then title = ch.team1 + "  " + ch.sep + "  " + ch.team2
    showOsdText(title, "")
    m.osdChannelId = ch.id
    m.top.findNode("osdLive").visible = true
    tag = ""
    if m.zapRow <> invalid and m.zapRow.title <> invalid then tag = m.zapRow.title
    if ch.cardType = "game" and ch.league <> invalid then tag = ch.league
    m.top.findNode("osdTag").text = tag
    if ch.HDPosterUrl <> invalid then m.top.findNode("osdLogo").uri = ch.HDPosterUrl
    g = freshGuide(m.epgCache, ch.id)
    if g <> invalid then
        renderOsd(g)
    else
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
    if m.epgCache.Count() > 60 then m.epgCache = {}
    m.epgCache[r.streamId] = entry
    if m.osd.visible and r.streamId = m.osdChannelId then renderOsd(entry)
end sub

sub renderOsd(entry as Object)
    lines = guideLines(entry)
    if entry.items.Count() = 0 then return ' nothing useful to add
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

sub openStrip()
    if m.zapRow = invalid then return
    root = CreateObject("roSGNode", "ContentNode")
    root.appendChild(m.zapRow.clone(true))
    m.stripList.content = root
    m.stripList.jumpToRowItem = [0, m.zapIndex]
    title = "More"
    if m.zapRow.title <> invalid and m.zapRow.title <> "" then title = m.zapRow.title
    m.top.findNode("stripTitle").text = title
    hideOsd()
    m.strip.visible = true
    m.stripList.setFocus(true)
end sub

sub closeStrip()
    m.strip.visible = false
    m.video.setFocus(true)
end sub

sub onStripSelected()
    sel = m.stripList.rowItemSelected
    if sel = invalid or sel.Count() < 2 then return
    m.strip.visible = false
    playLive(m.zapRow, sel[1])
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
        if m.strip.visible then
            if key = "back" or key = "down" or key = "up" then
                closeStrip()
                return true
            end if
            return false
        end if
        if key = "back" then
            stopVideo()
            return true
        end if
        if m.playingLive then
            if key = "replay" or key = "left" then
                goPrevChannel()
                return true
            else if key = "up" then
                playLive(m.zapRow, m.zapIndex - 1)
                return true
            else if key = "down" then
                playLive(m.zapRow, m.zapIndex + 1)
                return true
            else if key = "OK" then
                openStrip()
                return true
            else if key = "info" or key = "options" then
                showOsd(m.zapRow.getChild(m.zapIndex))
                return true
            end if
        end if
        return false
    end if

    if key = "options" then
        ' * on a channel: add/remove it from Your Channels; anywhere else: login settings
        if m.details = invalid and m.nav.visible and not m.nav.isInFocusChain() then
            s = m.screens[m.current]
            item = invalid
            if s <> invalid then item = s.focusedItem
            if item <> invalid and item.kind = "live" and item.id <> invalid and item.id <> "" then
                added = toggleFav(item)
                if added then banner("Added " + item.title + " to Your Channels") else banner("Removed " + item.title + " from Your Channels")
                if m.screens[0] <> invalid then m.screens[0].refreshFavs = true
                return true
            end if
        end if
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

    if key = "rewind" and not m.nav.isInFocusChain() then
        s = m.screens[m.current]
        if s <> invalid then s.jumpStart = true
        return true
    end if

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
