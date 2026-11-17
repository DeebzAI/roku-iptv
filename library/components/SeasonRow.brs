sub init()
    m.pill = m.top.findNode("pill")
    m.name = m.top.findNode("name")
    m.name.font = makeFont(30, true)
    m.cur = invalid
end sub

sub onContent()
    if m.cur <> invalid then m.cur.unobserveField("sel")
    m.cur = m.top.itemContent
    if m.cur = invalid then return
    m.name.text = m.cur.title
    m.cur.observeField("sel", "render")
    render()
end sub

sub render()
    fp = m.top.focusPercent
    sel = false
    if m.cur <> invalid and m.cur.sel = true then sel = true
    if fp > 0.5 then
        m.pill.opacity = 1.0
        m.name.color = "0x1A1A1AFF"
    else if sel then
        m.pill.opacity = 0.18
        m.name.color = "0xFFFFFFFF"
    else
        m.pill.opacity = 0
        m.name.color = "0x8E8E93FF"
    end if
end sub
