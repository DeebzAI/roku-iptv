' One line of the guide: channel | now playing (with progress) | up next.

sub init()
    m.bg = m.top.findNode("bg")
    m.accent = m.top.findNode("accent")
    m.logo = m.top.findNode("logo")
    m.name = m.top.findNode("name")
    m.nowTitle = m.top.findNode("nowTitle")
    m.nowSub = m.top.findNode("nowSub")
    m.progBg = m.top.findNode("progBg")
    m.prog = m.top.findNode("prog")
    m.nextText = m.top.findNode("nextText")
    m.name.font = makeFont(28, true)
    m.nowTitle.font = makeFont(30, true)
    m.nowSub.font = makeFont(24, false)
    m.nextText.font = makeFont(24, false)
    m.cur = invalid
end sub

sub onContent()
    c = m.top.itemContent
    if m.cur <> invalid then m.cur.unobserveField("epgStamp")
    m.cur = c
    if c = invalid then return
    m.name.text = c.title
    url = c.HDPosterUrl
    if url = invalid then url = ""
    m.logo.uri = url
    c.observeField("epgStamp", "render")
    render()
    onFocus()
end sub

sub render()
    c = m.cur
    if c = invalid then return
    nt = c.nowTitle
    if nt = invalid or nt = "" then
        m.nowTitle.text = "Loading guide..."
        m.nowTitle.color = "0xFFFFFF59"
        m.nowSub.text = ""
        m.nextText.text = ""
        m.progBg.visible = false
        m.prog.visible = false
        return
    end if
    m.nowTitle.text = nt
    m.nowTitle.color = "0xFFFFFFFF"
    m.nowSub.text = c.nowSub
    m.nextText.text = c.nextText
    hasBar = (c.progress <> invalid and c.progress > 0)
    m.progBg.visible = hasBar
    m.prog.visible = hasBar
    if hasBar then m.prog.width = Int(230 * c.progress)
end sub

sub onFocus()
    fp = m.top.focusPercent
    m.accent.opacity = fp
    if fp > 0.5 then m.bg.color = "0xFFFFFF29" else m.bg.color = "0xFFFFFF14"
end sub
