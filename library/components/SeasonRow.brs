sub init()
    m.pill = m.top.findNode("pill")
    m.name = m.top.findNode("name")
    m.name.font = makeFont(30, true)
    m.cur = invalid
end sub

sub onContent()
    if m.cur <> invalid then
        m.cur.unobserveField("sel")
        m.cur.unobserveField("act")
    end if
    m.cur = m.top.itemContent
    if m.cur = invalid then return
    m.name.text = m.cur.title
    m.cur.observeField("sel", "render")
    m.cur.observeField("act", "render")
    render()
end sub

sub render()
    ' bright pill only while the season list itself has focus; dim pill otherwise
    sel = false
    act = false
    if m.cur <> invalid then
        if m.cur.sel = true then sel = true
        if m.cur.act = true then act = true
    end if
    if sel and act then
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
