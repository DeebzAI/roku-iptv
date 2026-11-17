sub init()
    m.bg = m.top.findNode("bg")
    m.num = m.top.findNode("num")
    m.title = m.top.findNode("title")
    m.dur = m.top.findNode("dur")
    m.progBg = m.top.findNode("progBg")
    m.prog = m.top.findNode("prog")
    m.num.font = makeFont(26, false)
    m.title.font = makeFont(30, false)
    m.dur.font = makeFont(26, false)
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.num.text = c.epNum
    m.title.text = c.title
    m.dur.text = c.dur
    hasBar = (c.progress <> invalid and c.progress > 0)
    m.progBg.visible = hasBar
    m.prog.visible = hasBar
    if hasBar then m.prog.width = Int(1030 * c.progress)
    onFocus()
end sub

sub onFocus()
    fp = m.top.focusPercent
    m.bg.opacity = fp
    if fp > 0.5 then
        m.title.color = "0xFFFFFFFF"
        m.num.color = "0xFFFFFFFF"
    else
        m.title.color = "0xE5E5E7FF"
        m.num.color = "0x8E8E93FF"
    end if
end sub
