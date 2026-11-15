sub init()
    m.card = m.top.findNode("card")
    m.bg = m.top.findNode("bg")
    m.placeholder = m.top.findNode("placeholder")
    m.mask = m.top.findNode("mask")
    m.img = m.top.findNode("img")
    m.logo = m.top.findNode("logo")
    m.ring = m.top.findNode("ring")
    m.title = m.top.findNode("title")
    m.title.font = makeFont(24, false)
    m.placeholder.font = makeFont(24, true)
    m.w = 360
    m.h = 202
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    cardType = c.cardType
    if cardType = invalid then cardType = "tile"
    if cardType = "poster" then
        m.w = 230
        m.h = 345
    else
        m.w = 360
        m.h = 202
    end if
    m.bg.width = m.w
    m.bg.height = m.h
    m.placeholder.width = m.w - 30
    m.placeholder.height = m.h - 30
    m.placeholder.translation = [15, 15]
    m.placeholder.text = c.title
    m.ring.translation = [-7, -7]
    m.ring.width = m.w + 14
    m.ring.height = m.h + 14
    m.card.scaleRotateCenter = [m.w / 2, m.h / 2]

    url = c.HDPosterUrl
    if url = invalid then url = ""
    if cardType = "poster" then
        m.logo.visible = false
        m.mask.maskSize = [m.w, m.h]
        m.img.width = m.w
        m.img.height = m.h
        m.img.uri = url
        m.mask.visible = (url <> "")
    else
        m.mask.visible = false
        m.logo.translation = [36, 30]
        m.logo.width = m.w - 72
        m.logo.height = m.h - 60
        m.logo.uri = url
        m.logo.visible = (url <> "")
        if url <> "" then m.placeholder.text = ""
    end if

    m.title.width = m.w
    m.title.text = c.title
    m.title.translation = [0, m.h + 14]
    onFocus()
end sub

sub onFocus()
    fp = m.top.focusPercent
    s = 1 + 0.09 * fp
    m.card.scale = [s, s]
    m.ring.opacity = fp
    m.title.translation = [0, m.h + 14 + m.h * 0.045 * fp]
    if fp > 0.5 then m.title.color = "0xFFFFFFFF" else m.title.color = "0x8D97A3FF"
end sub
