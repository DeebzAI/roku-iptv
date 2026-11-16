sub init()
    m.card = m.top.findNode("card")
    m.bg = m.top.findNode("bg")
    m.placeholder = m.top.findNode("placeholder")
    m.img = m.top.findNode("img")
    m.corners = m.top.findNode("corners")
    m.logo = m.top.findNode("logo")
    m.ring = m.top.findNode("ring")
    m.shadow = m.top.findNode("shadow")
    m.progBg = m.top.findNode("progBg")
    m.prog = m.top.findNode("prog")
    m.title = m.top.findNode("title")
    m.game = m.top.findNode("game")
    m.badgeBg = m.top.findNode("badgeBg")
    m.badge = m.top.findNode("badge")
    m.league = m.top.findNode("league")
    m.team1 = m.top.findNode("team1")
    m.team2 = m.top.findNode("team2")

    m.title.font = makeFont(27, false)
    m.placeholder.font = makeFont(30, true)
    m.nameFont = m.placeholder.font
    m.hintFont = makeFont(27, false)
    m.badge.font = makeFont(24, true)
    m.league.font = makeFont(24, true)
    m.team1.font = makeFont(36, true)
    m.team2.font = makeFont(32, false)

    m.logo.observeField("loadStatus", "onArtStatus")
    m.img.observeField("loadStatus", "onArtStatus")
    m.w = 360
    m.h = 202
    m.cardType = "tile"
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    cardType = c.cardType
    if cardType = invalid then cardType = "tile"
    m.cardType = cardType
    if cardType = "poster" then
        m.w = 230
        m.h = 345
    else
        m.w = 360
        m.h = 202
    end if
    m.bg.width = m.w
    m.bg.height = m.h
    m.placeholder.width = m.w - 36
    m.placeholder.height = m.h - 36
    m.placeholder.translation = [18, 18]
    m.ring.translation = [-7, -7]
    m.ring.width = m.w + 14
    m.ring.height = m.h + 14
    m.card.scaleRotateCenter = [m.w / 2, m.h / 2]
    m.shadow.visible = (cardType <> "poster") ' posters skip the shadow to save memory
    m.shadow.translation = [-40, -32]
    m.shadow.width = m.w + 80
    m.shadow.height = m.h + 80
    ' resume progress (Continue Watching)
    m.progBg.visible = false
    m.prog.visible = false
    if c.progress <> invalid and c.progress > 0 then
        m.progBg.translation = [16, m.h - 24]
        m.progBg.width = m.w - 32
        m.prog.translation = [16, m.h - 24]
        m.prog.width = Int((m.w - 32) * c.progress)
        m.progBg.visible = true
        m.prog.visible = true
    end if

    url = c.HDPosterUrl
    if url = invalid then url = ""

    m.bg.opacity = 1.0
    m.game.visible = false
    m.img.visible = false
    m.corners.visible = false
    m.logo.visible = false
    m.placeholder.visible = true
    m.placeholder.font = m.nameFont
    m.placeholder.text = c.title
    m.title.visible = true

    if c.skeleton = true then
        ' quiet grey placeholder while the row loads
        m.placeholder.visible = false
        m.title.visible = false
        m.bg.opacity = 0.55
    else if c.hint = true then
        m.placeholder.font = m.hintFont
        m.title.visible = false
    else if cardType = "game" then
        ' scoreboard card: badge, league, two team lines; no logo, no caption
        m.placeholder.visible = false
        m.title.visible = false
        m.game.visible = true
        badge = c.badge
        if badge = invalid then badge = ""
        m.badge.text = badge
        bw = 32 + Len(badge) * 14
        if bw < 76 then bw = 76
        m.badgeBg.width = bw
        m.badge.width = bw
        if badge = "LIVE" then
            m.badgeBg.blendColor = "0xE5484DFF"
        else
            m.badgeBg.blendColor = "0x3A4552FF"
        end if
        m.league.text = c.league
        m.team1.text = c.team1
        t2 = c.team2
        if t2 <> invalid and t2 <> "" then
            m.team2.text = c.sep + "  " + t2
        else
            m.team2.text = ""
        end if
    else if cardType = "poster" then
        m.img.width = m.w
        m.img.height = m.h
        if url <> "" then
            m.img.uri = url
            m.img.visible = true
            m.corners.visible = true
        end if
    else
        m.logo.translation = [36, 30]
        m.logo.width = m.w - 72
        m.logo.height = m.h - 60
        if url <> "" then
            m.logo.uri = url
            m.logo.visible = true
            ' keep the name visible until the logo actually loads
            if m.logo.loadStatus = "ready" then m.placeholder.visible = false
        end if
    end if

    m.title.width = m.w
    m.title.text = c.title
    m.title.translation = [0, m.h + 14]
    onFocus()
end sub

' Swap between artwork and the text fallback depending on whether the image loaded.
sub onArtStatus(event as Object)
    st = event.getData()
    if m.cardType = "game" then return
    if st = "ready" then
        m.placeholder.visible = false
    else if st = "failed" then
        m.placeholder.visible = true
        m.logo.visible = false
        m.img.visible = false
        m.corners.visible = false
    end if
end sub

sub onFocus()
    fp = m.top.focusPercent
    s = 1 + 0.09 * fp
    m.card.scale = [s, s]
    m.ring.opacity = fp
    m.shadow.opacity = fp
    m.title.translation = [0, m.h + 14 + m.h * 0.045 * fp]
    if fp > 0.5 then m.title.color = "0xFFFFFFFF" else m.title.color = "0x8D97A3FF"
end sub
