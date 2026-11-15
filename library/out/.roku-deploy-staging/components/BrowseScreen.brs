' One tab: big preview ("hero") on top, rows of cards below.
' Rows are fetched only when you scroll near them.

sub init()
    m.rows = m.top.findNode("rows")
    m.status = m.top.findNode("status")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroDesc = m.top.findNode("heroDesc")
    m.heroBackdrop = m.top.findNode("heroBackdrop")
    m.heroPoster = m.top.findNode("heroPoster")
    m.heroLogo = m.top.findNode("heroLogo")
    m.heroBar = m.top.findNode("heroBar")
    m.heroBarBg = m.top.findNode("heroBarBg")
    m.heroTitle.font = makeFont(56, true)
    m.heroMeta.font = makeFont(28, false)
    m.heroDesc.font = makeFont(28, false)
    m.status.font = makeFont(32, false)

    m.loaded = {}
    m.loading = {}
    m.queue = []
    m.running = 0
    m.tasks = {}
    m.infoCache = {}
    m.epgCache = {}
    m.pendingInfo = {}
    m.heroItem = invalid
    m.started = false

    m.heroTimer = CreateObject("roSGNode", "Timer")
    m.heroTimer.duration = 0.4
    m.heroTimer.observeField("fire", "loadHeroDetails")

    m.rows.observeField("rowItemFocused", "onItemFocused")
    m.rows.observeField("rowItemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.rows.setFocus(true)
end sub

sub startLoading()
    if m.started then return
    m.started = true
    configureRows()
    m.status.text = "Loading..."
    m.status.visible = true
    t = CreateObject("roSGNode", "DataTask")
    t.xtream = m.top.xtream
    t.userAgent = m.top.userAgent
    t.request = { mode: "categories", kind: m.top.kind }
    t.observeField("result", "onCategories")
    m.catTask = t
    t.control = "RUN"
end sub

sub configureRows()
    m.rows.itemComponentName = "PosterCard"
    m.rows.numRows = 3
    m.rows.drawFocusFeedback = false
    m.rows.showRowLabel = [true]
    m.rows.rowLabelOffset = [[0, 18]]
    m.rows.rowLabelColor = "0xE6E9EDFF"
    m.rows.rowLabelFont = makeFont(32, true)
    m.rows.rowFocusAnimationStyle = "floatingFocus"
    m.rows.itemSpacing = [0, 26]
    if m.top.kind = "movies" or m.top.kind = "series" then
        m.cardType = "poster"
        m.rows.itemSize = [1820, 470]
        m.rows.rowItemSize = [[230, 345]]
        m.rows.rowItemSpacing = [[34, 0]]
    else
        m.cardType = "tile"
        m.rows.itemSize = [1820, 330]
        m.rows.rowItemSize = [[360, 202]]
        m.rows.rowItemSpacing = [[40, 0]]
    end if
end sub

sub onCategories()
    try
        onCategoriesImpl()
    catch e
        reportError("onCategories", e)
    end try
end sub

sub onCategoriesImpl()
    r = m.catTask.result
    cats = r.cats
    if cats = invalid or cats.Count() = 0 then
        m.status.text = "Nothing here yet."
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    for each c in cats
        row = root.createChild("ContentNode")
        row.title = c.name
        row.id = c.id
        addSkeletons(row)
    end for
    if m.top.kind = "sports" then
        favRow = CreateObject("roSGNode", "ContentNode")
        favRow.title = "Your Channels"
        favRow.id = "favs"
        insertAt = 1
        if root.getChildCount() < 1 then insertAt = 0
        root.insertChild(favRow, insertAt)
        m.favIndex = insertAt
        fillFavs(favRow)
        m.loaded[insertAt.ToStr()] = true
    end if
    m.rows.content = root
    m.status.visible = false
    ' keep live game rows fresh
    m.refreshTimer = CreateObject("roSGNode", "Timer")
    m.refreshTimer.duration = 300
    m.refreshTimer.repeat = true
    m.refreshTimer.observeField("fire", "refreshGameRows")
    m.refreshTimer.control = "start"
    queueRow(0)
    queueRow(1)
end sub

sub addSkeletons(row as Object)
    for i = 1 to 6
        sk = row.createChild("ContentNode")
        sk.title = ""
        sk.addFields({ cardType: m.cardType, skeleton: true })
    end for
end sub

' ---------- favorites row (Sports) ----------

sub fillFavs(row as Object)
    row.removeChildrenIndex(row.getChildCount(), 0)
    favs = loadFavs()
    if favs.Count() = 0 then
        hint = row.createChild("ContentNode")
        hint.title = "Press * on any channel to add it here"
        hint.addFields({ cardType: "tile", hint: true })
        return
    end if
    for each f in favs
        it = row.createChild("ContentNode")
        it.title = f.title
        it.id = f.id
        it.HDPosterUrl = f.logo
        it.addFields({ kind: "live", cardType: "tile", url: f.url, fmt: "hls" })
    end for
end sub

sub onRefreshFavs()
    if m.favIndex = invalid or m.rows.content = invalid then return
    row = m.rows.content.getChild(m.favIndex)
    if row <> invalid then fillFavs(row)
end sub

sub refreshGameRows()
    if not m.top.visible or m.rows.content = invalid then return
    for i = 0 to m.rows.content.getChildCount() - 1
        r = m.rows.content.getChild(i)
        if r <> invalid and r.id <> invalid and (Left(r.id, 6) = "games:" or Left(r.id, 5) = "soon:") then
            m.loaded.Delete(i.ToStr())
            queueRow(i)
        end if
    end for
end sub

' ---------- lazy row loading ----------

sub queueRow(i as Integer)
    root = m.rows.content
    if root = invalid then return
    if i < 0 or i >= root.getChildCount() then return
    key = i.ToStr()
    if m.loaded[key] = true or m.loading[key] = true then return
    m.loading[key] = true
    m.queue.Push(i)
    pump()
end sub

sub pump()
    while m.running < 2 and m.queue.Count() > 0
        i = m.queue.Shift()
        row = m.rows.content.getChild(i)
        t = CreateObject("roSGNode", "DataTask")
        t.xtream = m.top.xtream
        t.userAgent = m.top.userAgent
        t.request = { mode: "items", kind: m.top.kind, categoryId: row.id, rowIndex: i }
        t.observeField("result", "onRowLoaded")
        m.tasks[i.ToStr()] = t
        m.running = m.running + 1
        t.control = "RUN"
    end while
end sub

sub onRowLoaded(event as Object)
    try
        onRowLoadedImpl(event)
    catch e
        reportError("onRowLoaded", e)
    end try
end sub

sub onRowLoadedImpl(event as Object)
    t = event.getRoSGNode()
    r = event.getData()
    i = r.rowIndex
    key = i.ToStr()
    m.running = m.running - 1
    m.loading.Delete(key)
    m.loaded[key] = true
    m.tasks.Delete(key)
    root = m.rows.content
    if root = invalid then return
    node = t.node
    old = root.getChild(i)
    if old = invalid then return
    oldCount = old.getChildCount()
    if node <> invalid and node.getChildCount() > 0 then
        kids = node.getChildren(-1, 0)
        old.appendChildren(kids)
        old.removeChildrenIndex(oldCount, 0) ' drop the placeholders / previous list
    else
        old.removeChildrenIndex(oldCount, 0)
        msg = old.createChild("ContentNode")
        msg.title = "Nothing here right now"
        if m.top.kind = "later" then msg.title = "No more games today"
        if Left(old.id, 6) = "games:" then msg.title = "No games on right now"
        msg.addFields({ cardType: "tile", hint: true })
    end if
    pump()
    rf = m.rows.rowItemFocused
    if rf <> invalid and rf.Count() = 2 and rf[0] = i then onItemFocused()
end sub

' ---------- hero preview ----------

function itemAt(r as Integer, c as Integer) as Dynamic
    root = m.rows.content
    if root = invalid then return invalid
    row = root.getChild(r)
    if row = invalid then return invalid
    return row.getChild(c)
end function

sub onItemFocused()
    try
        onItemFocusedImpl()
    catch e
        reportError("onItemFocused", e)
    end try
end sub

sub onItemFocusedImpl()
    rf = m.rows.rowItemFocused
    if rf = invalid or rf.Count() < 2 then return
    queueRow(rf[0] + 1)
    if rf[0] < 0 or rf[1] < 0 then return
    item = itemAt(rf[0], rf[1])
    if item = invalid then return
    m.heroItem = item
    m.top.focusedItem = item
    rowNode = m.rows.content.getChild(rf[0])
    m.heroRowTitle = ""
    if rowNode <> invalid then m.heroRowTitle = rowNode.title
    showHero(item)
    m.heroTimer.control = "stop"
    m.heroTimer.control = "start"
end sub

sub showHero(item as Object)
    m.heroTitle.text = item.title
    kind = item.kind
    m.heroBar.visible = false
    m.heroBarBg.visible = false
    if kind = invalid then
        if item.skeleton = true then m.heroTitle.text = ""
        m.heroMeta.text = ""
        m.heroDesc.text = ""
        queueArt("none", "")
        return
    end if
    if kind = "live" then
        queueArt("logo", item.HDPosterUrl)
        m.heroMeta.text = m.heroRowTitle
        if item.cardType = "game" then
            if item.team2 <> "" then m.heroTitle.text = item.team1 + "  " + item.sep + "  " + item.team2
            m.heroMeta.text = joinParts([item.badge, item.league])
        end if
        g = freshGuide(m.epgCache, item.id)
        if g <> invalid then showGuide(g) else m.heroDesc.text = ""
    else if kind = "movie" then
        info = m.infoCache[item.id]
        if info <> invalid then
            applyInfo(item, info)
        else
            m.heroMeta.text = ratingText(item.rating)
            m.heroDesc.text = ""
            showPosterArt(item.HDPosterUrl)
        end if
    else if kind = "series" then
        m.heroMeta.text = joinParts([item.year, item.genre, ratingText(item.rating)])
        m.heroDesc.text = item.Description
        if item.backdrop <> "" then showBackdrop(item.backdrop) else showPosterArt(item.HDPosterUrl)
    end if
end sub

function ratingText(r as Dynamic) as String
    if r = invalid or r = "" or r = "0" then return ""
    return "Rated " + r + "/10"
end function

' Artwork is applied only after the highlight settles (see loadHeroDetails).
sub queueArt(kind as String, url as Dynamic)
    if url = invalid then url = ""
    m.artKind = kind
    m.artUrl = url
end sub

sub applyArt()
    if m.artKind = invalid then return
    if m.artKind = "backdrop" and m.artUrl <> "" then
        if m.heroBackdrop.uri <> m.artUrl then m.heroBackdrop.uri = m.artUrl
        m.heroPoster.visible = false
        m.heroLogo.visible = false
        m.heroBackdrop.visible = true
    else if m.artKind = "poster" and m.artUrl <> "" then
        if m.heroPoster.uri <> m.artUrl then m.heroPoster.uri = m.artUrl
        m.heroBackdrop.visible = false
        m.heroLogo.visible = false
        m.heroPoster.visible = true
    else if m.artKind = "logo" and m.artUrl <> "" then
        if m.heroLogo.uri <> m.artUrl then m.heroLogo.uri = m.artUrl
        m.heroBackdrop.visible = false
        m.heroPoster.visible = false
        m.heroLogo.visible = true
    else
        hideArt()
    end if
end sub

sub hideArt()
    m.heroBackdrop.visible = false
    m.heroPoster.visible = false
    m.heroLogo.visible = false
end sub

sub showBackdrop(url as String)
    queueArt("backdrop", url)
end sub

sub showPosterArt(url as Dynamic)
    queueArt("poster", url)
end sub

sub applyInfo(item as Object, info as Object)
    m.heroMeta.text = joinParts([info.year, info.genre, info.duration, info.quality, ratingText(info.rating)])
    m.heroDesc.text = info.plot
    if info.backdrop <> "" then showBackdrop(info.backdrop) else showPosterArt(item.HDPosterUrl)
end sub

sub showGuide(g as Object)
    lines = guideLines(g)
    if g.items.Count() = 0 then
        ' no guide data: show the provider's full channel name instead (titles get cut off)
        m.heroDesc.text = ""
        return
    end if
    m.heroDesc.text = "Now:  " + lines.now + Chr(10) + lines.time + Chr(10) + lines.next
    m.heroBarBg.visible = true
    m.heroBar.visible = true
    m.heroBar.width = Int(420 * lines.progress)
end sub

sub loadHeroDetails()
    try
        loadHeroDetailsImpl()
    catch e
        reportError("loadHeroDetails", e)
    end try
end sub

sub loadHeroDetailsImpl()
    applyArt()
    item = m.heroItem
    if item = invalid or item.kind = invalid then return
    if item.kind = "live" then
        if freshGuide(m.epgCache, item.id) <> invalid then return
        if m.pendingInfo["epg" + item.id] = true then return
        m.pendingInfo["epg" + item.id] = true
        t = CreateObject("roSGNode", "EpgTask")
        t.xtream = m.top.xtream
        t.streamId = item.id
        t.userAgent = m.top.userAgent
        t.observeField("result", "onEpg")
        m.tasks["epg" + item.id] = t
        t.control = "RUN"
    else if item.kind = "movie" then
        if m.infoCache[item.id] <> invalid then return
        if m.pendingInfo["vod" + item.id] = true then return
        m.pendingInfo["vod" + item.id] = true
        t = CreateObject("roSGNode", "DataTask")
        t.xtream = m.top.xtream
        t.userAgent = m.top.userAgent
        t.request = { mode: "vodinfo", id: item.id }
        t.observeField("result", "onVodInfo")
        m.tasks["vod" + item.id] = t
        t.control = "RUN"
    end if
end sub

sub onEpg(event as Object)
    try
        onEpgImpl(event)
    catch e
        reportError("onEpg", e)
    end try
end sub

sub onEpgImpl(event as Object)
    r = event.getData()
    m.pendingInfo.Delete("epg" + r.streamId)
    m.tasks.Delete("epg" + r.streamId)
    entry = { fetched: CreateObject("roDateTime").AsSeconds(), items: r.items }
    m.epgCache[r.streamId] = entry
    if m.heroItem <> invalid and m.heroItem.kind = "live" and m.heroItem.id = r.streamId then showGuide(entry)
end sub

sub onVodInfo(event as Object)
    try
        onVodInfoImpl(event)
    catch e
        reportError("onVodInfo", e)
    end try
end sub

sub onVodInfoImpl(event as Object)
    r = event.getData()
    m.pendingInfo.Delete("vod" + r.id)
    m.tasks.Delete("vod" + r.id)
    m.infoCache[r.id] = r
    if m.heroItem <> invalid and m.heroItem.kind = "movie" and m.heroItem.id = r.id then
        applyInfo(m.heroItem, r)
        applyArt()
    end if
end sub

' ---------- selection ----------

sub onItemSelected()
    try
        onItemSelectedImpl()
    catch e
        reportError("onItemSelected", e)
    end try
end sub

sub onItemSelectedImpl()
    rs = m.rows.rowItemSelected
    if rs = invalid or rs.Count() < 2 then return
    item = itemAt(rs[0], rs[1])
    if item = invalid or item.kind = invalid then return
    m.top.selectedInfo = { item: item, row: m.rows.content.getChild(rs[0]), index: rs[1] }
end sub

sub reportError(where as String, e as Object)
    msg = where + ": " + asStr(e.message)
    if e.backtrace <> invalid and e.backtrace.Count() > 0 then
        b = e.backtrace[e.backtrace.Count() - 1]
        msg = msg + " (" + asStr(b.filename) + " line " + asStr(b.line_number) + ")"
    end if
    print "IPTV error: "; msg
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    sec.Write("lastError", msg)
    sec.Flush()
end sub
