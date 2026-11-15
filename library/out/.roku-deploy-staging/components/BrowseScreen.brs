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
    m.heroTitle.font = makeFont(62, true)
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
    m.heroTimer.duration = 0.45
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
        ph = row.createChild("ContentNode")
        ph.title = "Loading..."
        ph.addFields({ cardType: m.cardType })
    end for
    m.rows.content = root
    m.status.visible = false
    queueRow(0)
    queueRow(1)
    queueRow(2)
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
    while m.running < 3 and m.queue.Count() > 0
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
    t = event.getRoSGNode()
    r = event.getData()
    i = r.rowIndex
    key = i.ToStr()
    m.running = m.running - 1
    m.loading.Delete(key)
    m.loaded[key] = true
    m.tasks.Delete(key)
    root = m.rows.content
    node = t.node
    old = root.getChild(i)
    if node <> invalid and node.getChildCount() > 0 and old <> invalid then
        node.title = old.title
        node.id = old.id
        root.replaceChild(node, i)
    else if old <> invalid then
        ph = old.getChild(0)
        if ph <> invalid then ph.title = "Nothing here"
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
    rf = m.rows.rowItemFocused
    if rf = invalid or rf.Count() < 2 then return
    queueRow(rf[0] + 1)
    queueRow(rf[0] + 2)
    item = itemAt(rf[0], rf[1])
    if item = invalid then return
    m.heroItem = item
    m.heroRowTitle = m.rows.content.getChild(rf[0]).title
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
        m.heroMeta.text = ""
        m.heroDesc.text = ""
        hideArt()
        return
    end if
    if kind = "live" then
        hideArt()
        m.heroLogo.uri = item.HDPosterUrl
        m.heroLogo.visible = true
        m.heroMeta.text = m.heroRowTitle
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

sub hideArt()
    m.heroBackdrop.visible = false
    m.heroPoster.visible = false
    m.heroLogo.visible = false
end sub

sub showBackdrop(url as String)
    hideArt()
    m.heroBackdrop.uri = url
    m.heroBackdrop.visible = true
end sub

sub showPosterArt(url as String)
    hideArt()
    if url = invalid or url = "" then return
    m.heroPoster.uri = url
    m.heroPoster.visible = true
end sub

sub applyInfo(item as Object, info as Object)
    m.heroMeta.text = joinParts([info.year, info.genre, info.duration, ratingText(info.rating)])
    m.heroDesc.text = info.plot
    if info.backdrop <> "" then showBackdrop(info.backdrop) else showPosterArt(item.HDPosterUrl)
end sub

sub showGuide(g as Object)
    lines = guideLines(g)
    if g.items.Count() = 0 then
        m.heroDesc.text = "No guide info for this channel"
        return
    end if
    m.heroDesc.text = "Now:  " + lines.now + Chr(10) + lines.time + Chr(10) + lines.next
    m.heroBarBg.visible = true
    m.heroBar.visible = true
    m.heroBar.width = Int(420 * lines.progress)
end sub

sub loadHeroDetails()
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
    r = event.getData()
    m.pendingInfo.Delete("epg" + r.streamId)
    m.tasks.Delete("epg" + r.streamId)
    entry = { fetched: CreateObject("roDateTime").AsSeconds(), items: r.items }
    m.epgCache[r.streamId] = entry
    if m.heroItem <> invalid and m.heroItem.kind = "live" and m.heroItem.id = r.streamId then showGuide(entry)
end sub

sub onVodInfo(event as Object)
    r = event.getData()
    m.pendingInfo.Delete("vod" + r.id)
    m.tasks.Delete("vod" + r.id)
    m.infoCache[r.id] = r
    if m.heroItem <> invalid and m.heroItem.kind = "movie" and m.heroItem.id = r.id then applyInfo(m.heroItem, r)
end sub

' ---------- selection ----------

sub onItemSelected()
    rs = m.rows.rowItemSelected
    if rs = invalid or rs.Count() < 2 then return
    item = itemAt(rs[0], rs[1])
    if item = invalid or item.kind = invalid then return
    m.top.selectedInfo = { item: item, row: m.rows.content.getChild(rs[0]), index: rs[1] }
end sub
