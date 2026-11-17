' Lightweight poster card for Movies / TV Shows (few nodes = little memory).

sub init()
    m.card = m.top.findNode("card")
    m.bg = m.top.findNode("bg")
    m.placeholder = m.top.findNode("placeholder")
    m.img = m.top.findNode("img")
    m.ring = m.top.findNode("ring")
    m.title = m.top.findNode("title")
    m.progBg = m.top.findNode("progBg")
    m.prog = m.top.findNode("prog")
    m.placeholder.font = makeFont(28, true)
    m.title.font = makeFont(27, false)
    m.card.scaleRotateCenter = [115, 172]
    m.img.observeField("loadStatus", "onArt")
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.img.visible = false
    m.progBg.visible = false
    m.prog.visible = false
    m.placeholder.text = ""
    m.title.text = ""
    if c.skeleton = true then
        m.bg.color = "0xFFFFFF0D"
        return
    end if
    m.bg.color = "0xFFFFFF14"
    if c.hint = true then
        m.placeholder.text = c.title
        return
    end if
    m.title.text = c.title
    url = c.HDPosterUrl
    if url = invalid then url = ""
    if url <> "" then
        m.placeholder.text = c.title ' shown until the picture arrives
        m.img.uri = url
        m.img.visible = true
    else
        m.placeholder.text = c.title
    end if
    if c.progress <> invalid and c.progress > 0 then
        m.progBg.visible = true
        m.prog.visible = true
        m.prog.width = Int(198 * c.progress)
    end if
    onFocus()
end sub

sub onArt(event as Object)
    st = event.getData()
    if st = "ready" then
        m.placeholder.text = ""
    else if st = "failed" then
        m.img.visible = false
        c = m.top.itemContent
        if c <> invalid then m.placeholder.text = c.title
    end if
end sub

sub onFocus()
    fp = m.top.focusPercent
    s = 1 + 0.08 * fp
    m.card.scale = [s, s]
    m.ring.opacity = fp
    m.title.translation = [0, 359 + 15 * fp]
    if fp > 0.5 then m.title.color = "0xFFFFFFFF" else m.title.color = "0xFFFFFF99"
end sub
