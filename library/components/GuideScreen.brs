' TV guide: channels down the side, what's on now and next across. Only the
' rows near the highlight fetch their schedule, so it stays light.

sub init()
    m.list = m.top.findNode("list")
    m.catName = m.top.findNode("catName")
    m.status = m.top.findNode("status")
    m.catName.font = makeFont(44, true)
    m.top.findNode("catHint").font = makeFont(26, false)
    m.top.findNode("colNow").font = makeFont(22, true)
    m.top.findNode("colNext").font = makeFont(22, true)
    m.status.font = makeFont(32, false)
    m.list.numRows = 8
    m.list.itemSize = [1720, 96]
    m.list.itemSpacing = [0, 6]
    m.list.drawFocusFeedback = false
    m.list.vertFocusAnimationStyle = "floatingFocus"
    m.list.observeField("itemFocused", "onFocusIdx")
    m.list.observeField("itemSelected", "onPick")
    m.top.observeField("focusedChild", "onFocusChanged")

    m.cats = []
    m.catIdx = 0
    m.reqId = 0
    m.epg = {}
    m.epgQueue = []
    m.epgLoading = {}
    m.epgRunning = 0
    m.tasks = {}
    m.byId = {}
    m.channels = invalid
    m.counter = 0
    m.started = false
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

sub startLoading()
    if m.started then return
    m.started = true
    m.status.text = "Loading..."
    m.status.visible = true
    t = CreateObject("roSGNode", "DataTask")
    t.xtream = m.top.xtream
    t.userAgent = m.top.userAgent
    t.request = { mode: "categories", kind: "sports" }
    t.observeField("result", "onCats")
    m.catTask = t
    t.control = "RUN"
end sub

sub onCats()
    cats = m.catTask.result.cats
    m.cats = []
    if cats <> invalid then
        for each c in cats
            id = asStr(c.id)
            if Left(id, 6) <> "games:" and Left(id, 5) <> "soon:" then m.cats.Push({ id: id, name: asStr(c.name) })
        end for
    end if
    if m.cats.Count() = 0 then
        m.status.text = "No channels to show yet."
        return
    end if
    loadCategory(0)
end sub

sub loadCategory(i as Integer)
    n = m.cats.Count()
    if n = 0 then return
    if i < 0 then i = n - 1
    if i >= n then i = 0
    m.catIdx = i
    m.catName.text = m.cats[i].name
    m.reqId = m.reqId + 1
    m.epgQueue = []
    m.channels = invalid
    m.list.content = invalid
    m.status.text = "Loading..."
    m.status.visible = true
    t = CreateObject("roSGNode", "DataTask")
    t.xtream = m.top.xtream
    t.userAgent = m.top.userAgent
    t.request = { mode: "items", kind: "sports", categoryId: m.cats[i].id, rowIndex: m.reqId }
    t.observeField("result", "onItems")
    m.itemTask = t
    t.control = "RUN"
end sub

sub onItems(event as Object)
    r = event.getData()
    if r.rowIndex <> m.reqId then return ' a newer category was picked meanwhile
    t = event.getRoSGNode()
    node = t.node
    if node = invalid or node.getChildCount() = 0 then
        m.status.text = "Nothing in this category."
        return
    end if
    root = CreateObject("roSGNode", "ContentNode")
    root.title = m.cats[m.catIdx].name
    kids = node.getChildren(-1, 0)
    root.appendChildren(kids)
    m.byId = {}
    for each k in root.getChildren(-1, 0)
        k.addFields({ nowTitle: "", nowSub: "", nextText: "", progress: 0.0, epgStamp: "" })
        m.byId[k.id] = k
    end for
    m.channels = root
    m.list.content = root
    m.status.visible = false
    if m.top.hasFocus() then m.list.setFocus(true)
    ensureEpg(0)
end sub

sub onFocusIdx()
    idx = m.list.itemFocused
    if m.channels = invalid or idx < 0 then return
    item = m.channels.getChild(idx)
    if item <> invalid then m.top.focusedItem = item
    ensureEpg(idx)
end sub

sub onPick()
    idx = m.list.itemSelected
    if m.channels = invalid or idx < 0 then return
    item = m.channels.getChild(idx)
    if item <> invalid then m.top.selectedInfo = { item: item, row: m.channels, index: idx }
end sub

sub onJumpStart()
    if m.channels <> invalid then m.list.jumpToItem = 0
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "left" then
        loadCategory(m.catIdx - 1)
        return true
    else if key = "right" then
        loadCategory(m.catIdx + 1)
        return true
    end if
    return false
end function

' ---------- schedules ----------

sub ensureEpg(idx as Integer)
    if m.channels = invalid then return
    lo = idx - 2
    if lo < 0 then lo = 0
    for i = lo to idx + 7
        node = m.channels.getChild(i)
        if node <> invalid then
            sid = node.id
            g = freshGuide(m.epg, sid)
            if g <> invalid then
                if node.epgStamp = "" then applyEpg(node, g)
            else if m.epgLoading[sid] <> true then
                m.epgLoading[sid] = true
                m.epgQueue.Push(sid)
            end if
        end if
    end for
    pumpEpg()
end sub

sub pumpEpg()
    while m.epgRunning < 2 and m.epgQueue.Count() > 0
        sid = m.epgQueue.Shift()
        t = CreateObject("roSGNode", "EpgTask")
        t.xtream = m.top.xtream
        t.userAgent = m.top.userAgent
        t.streamId = sid
        t.observeField("result", "onEpg")
        m.tasks[sid] = t
        m.epgRunning = m.epgRunning + 1
        t.control = "RUN"
    end while
end sub

sub onEpg(event as Object)
    r = event.getData()
    sid = r.streamId
    m.epgRunning = m.epgRunning - 1
    m.epgLoading.Delete(sid)
    m.tasks.Delete(sid)
    if m.epg.Count() > 150 then m.epg = {}
    entry = { fetched: CreateObject("roDateTime").AsSeconds(), items: r.items }
    m.epg[sid] = entry
    node = m.byId[sid]
    if node <> invalid then applyEpg(node, entry)
    pumpEpg()
end sub

sub applyEpg(node as Object, entry as Object)
    lines = guideLines(entry)
    if entry.items.Count() = 0 then
        node.nowTitle = "No guide info"
        node.nowSub = ""
        node.nextText = ""
        node.progress = 0.0
    else
        node.nowTitle = lines.now
        node.nowSub = lines.time
        node.nextText = lines.next
        node.progress = lines.progress
    end if
    m.counter = m.counter + 1
    node.epgStamp = m.counter.ToStr()
end sub
