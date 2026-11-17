' Movie page (Play button) or show page (seasons + episodes).

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
    m.plot = m.top.findNode("plot")
    m.playBtn = m.top.findNode("playBtn")
    m.restartBtn = m.top.findNode("restartBtn")
    m.playPill = m.top.findNode("playPill")
    m.restartPill = m.top.findNode("restartPill")
    m.playLabel = m.top.findNode("playLabel")
    m.restartLabel = m.top.findNode("restartLabel")
    m.top.findNode("restartLabel").font = makeFont(32, true)
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.status = m.top.findNode("status")
    m.stars = m.top.findNode("stars")
    m.top.findNode("starNum").font = makeFont(26, false)
    m.resBg = m.top.findNode("resBg")
    m.resBar = m.top.findNode("resBar")
    m.resLeft = m.top.findNode("resLeft")
    m.resLeft.font = makeFont(26, false)
    m.cast = m.top.findNode("cast")
    m.cast.font = makeFont(26, false)
    m.title.font = makeFont(62, true)
    m.meta.font = makeFont(30, false)
    m.plot.font = makeFont(30, false)
    m.status.font = makeFont(28, false)
    m.top.findNode("playLabel").font = makeFont(32, true)
    m.seasons.font = makeFont(30, true)
    m.seasons.focusedFont = makeFont(30, true)
    m.episodes.font = makeFont(30, false)
    m.episodes.focusedFont = makeFont(30, true)
    m.mode = "movie"
    m.seriesData = invalid
    m.seasons.observeField("itemFocused", "onSeasonFocused")
    m.episodes.observeField("itemSelected", "onEpisodeSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if not m.top.hasFocus() then return
    if m.mode = "movie" then
        m.playBtn.setFocus(true)
        styleButtons()
    else if m.seriesData <> invalid and m.seriesData.seasons.Count() > 0 then
        m.seasons.setFocus(true)
    end if
end sub

sub onItem()
    item = m.top.item
    m.mode = item.kind
    m.title.text = cleanTitle(item.title)
    m.meta.text = ""
    m.plot.text = item.Description
    m.cast.visible = false
    layoutFor(item.kind)
    if item.backdrop <> invalid and item.backdrop <> "" then
        showBackdrop(item.backdrop)
    else
        showPoster(item.HDPosterUrl)
    end if

    t = CreateObject("roSGNode", "DataTask")
    t.xtream = m.top.xtream
    t.userAgent = m.top.userAgent
    if m.mode = "movie" then
        m.playBtn.visible = true
        refreshResume()
        t.request = { mode: "vodinfo", id: item.id }
    else
        m.playBtn.visible = false
        m.status.text = "Loading episodes..."
        t.request = { mode: "seriesinfo", id: item.id }
    end if
    t.observeField("result", "onInfo")
    m.task = t
    t.control = "RUN"
end sub

' Provider titles often carry tags like "|EN|" (and box characters the font lacks).
function cleanTitle(s as Dynamic) as String
    if s = invalid then return ""
    out = ""
    for i = 1 to Len(s)
        ch = Mid(s, i, 1)
        code = Asc(ch)
        if code < &h2000 or code = &h2013 or code = &h2014 or code = &h2018 or code = &h2019 or code = &h201C or code = &h201D or code = &h2022 then
            out = out + ch
        else
            out = out + " "
        end if
    end for
    out = out.Trim()
    re = CreateObject("roRegex", "^\|?\s*(EN|ENG|US|USA|UK|MULTI)\s*\|?\s+", "i")
    if re.IsMatch(out) then out = re.Replace(out, "")
    re2 = CreateObject("roRegex", "^\|?\s*(EN|ENG|US|USA|UK)\s*\|\s*", "i")
    out = re2.Replace(out, "")
    return out.Trim()
end function

' Movies: text sits low on the left over the artwork. Shows keep the list layout.
sub layoutFor(kind as String)
    if kind = "movie" then
        m.title.translation = [100, 330]
        m.title.height = 150
        m.title.vertAlign = "bottom"
        m.title.wrap = true
        m.title.maxLines = 2
        m.meta.translation = [100, 494]
        m.plot.translation = [100, 596]
        m.plot.height = 140
        m.plot.maxLines = 4
        m.cast.translation = [100, 742]
        m.playBtn.translation = [100, 796]
        m.restartBtn.translation = [470, 796]
    end if
end sub

' Rating as five stars (0-10 -> 0-5), dimmed when empty.
sub showStars(rating as Dynamic)
    v = 0.0
    if rating <> invalid and rating <> "" then v = Val(rating)
    if v <= 0 then
        m.stars.visible = false
        return
    end if
    filled = Int(v / 2 + 0.5)
    for i = 1 to 5
        st = m.top.findNode("star" + i.ToStr())
        if i <= filled then st.opacity = 1.0 else st.opacity = 0.25
    end for
    m.top.findNode("starNum").text = Str(Int(v * 10) / 10.0).Trim()
    m.stars.visible = true
end sub

sub showBackdrop(url as String)
    m.poster.visible = false
    m.backdrop.uri = url
    m.backdrop.visible = true
end sub

sub showPoster(url as Dynamic)
    m.backdrop.visible = false
    if url = invalid or url = "" then return
    m.poster.uri = url
    m.poster.visible = true
end sub

function ratingText(r as Dynamic) as String
    if r = invalid or r = "" or r = "0" then return ""
    return "Rated " + r + "/10"
end function

sub onInfo()
    r = m.task.result
    item = m.top.item
    if r.plot <> invalid and r.plot <> "" then m.plot.text = r.plot
    if r.backdrop <> invalid and r.backdrop <> "" then showBackdrop(r.backdrop)
    if m.mode = "movie" then
        m.meta.text = joinParts([r.year, r.genre, r.duration, r.quality])
        showStars(r.rating)
        if r.cast <> invalid and r.cast <> "" then
            m.cast.text = "Starring  " + r.cast
            m.cast.visible = true
        end if
        return
    end if

    m.meta.text = joinParts([r.year, r.genre, ratingText(r.rating)])
    m.seriesData = r
    if r.seasons.Count() = 0 then
        m.status.text = "No episodes found for this show."
        return
    end if
    m.status.text = ""
    content = CreateObject("roSGNode", "ContentNode")
    for each s in r.seasons
        c = content.createChild("ContentNode")
        c.title = "Season " + s
    end for
    m.seasons.content = content
    m.seasons.visible = true
    m.episodes.visible = true
    fillEpisodes(0)
    if m.top.isInFocusChain() then m.seasons.setFocus(true)
end sub

sub onSeasonFocused()
    fillEpisodes(m.seasons.itemFocused)
end sub

sub fillEpisodes(idx as Integer)
    if m.seriesData = invalid then return
    if idx < 0 or idx >= m.seriesData.seasons.Count() then return
    key = m.seriesData.seasons[idx]
    m.currentSeason = key
    list = m.seriesData.episodes[key]
    content = CreateObject("roSGNode", "ContentNode")
    saved = resumeTable() ' read once, not once per episode
    for each e in list
        c = content.createChild("ContentNode")
        label = e.title
        if e.num <> "" then label = e.num + ".   " + label
        if e.duration <> "" then label = label + "   (" + e.duration + ")"
        posSecs = 0
        hit = saved["e" + e.id]
        if hit <> invalid and hit.p <> invalid then posSecs = hit.p
        if posSecs > 0 then label = label + "   ·  resume at " + fmtClock(posSecs)
        c.title = label
    end for
    m.episodes.content = content
end sub

sub onEpisodeSelected()
    list = m.seriesData.episodes[m.currentSeason]
    e = list[m.episodes.itemSelected]
    if e = invalid then return
    m.top.playRequest = { url: e.url, title: e.title, format: e.fmt, subtitle: m.top.item.title + "  ·  Season " + m.currentSeason, resumeKey: "e" + e.id, startAt: getResume("e" + e.id), poster: m.top.item.HDPosterUrl }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.mode = "movie" then
        item = m.top.item
        if key = "OK" and m.playBtn.hasFocus() then
            m.top.playRequest = { url: item.url, title: item.title, format: item.fmt, subtitle: m.meta.text, resumeKey: "m" + item.id, startAt: getResume("m" + item.id), poster: item.HDPosterUrl }
            return true
        else if key = "OK" and m.restartBtn.hasFocus() then
            m.top.playRequest = { url: item.url, title: item.title, format: item.fmt, subtitle: m.meta.text, resumeKey: "m" + item.id, startAt: 0, poster: item.HDPosterUrl }
            return true
        else if key = "right" and m.playBtn.hasFocus() and m.restartBtn.visible then
            m.restartBtn.setFocus(true)
            styleButtons()
            return true
        else if key = "left" and m.restartBtn.hasFocus() then
            m.playBtn.setFocus(true)
            styleButtons()
            return true
        end if
    else
        if key = "right" and m.seasons.hasFocus() then
            m.episodes.setFocus(true)
            return true
        else if key = "left" and m.episodes.hasFocus() then
            m.seasons.setFocus(true)
            return true
        end if
    end if
    return false
end function

sub showResumeBar(posSecs as Integer, dur as Integer)
    on = (posSecs > 0 and dur > posSecs)
    m.resBg.visible = on
    m.resBar.visible = on
    m.resLeft.visible = on
    if not on then return
    m.resBar.width = Int(370 * posSecs / dur)
    left = dur - posSecs
    h = Int(left / 3600)
    mi = Int((left MOD 3600) / 60)
    if h > 0 then
        m.resLeft.text = h.ToStr() + "h " + mi.ToStr() + "m left"
    else
        m.resLeft.text = mi.ToStr() + " min left"
    end if
end sub

' Movie buttons: "Resume (32:10)" + "Start Over" when there's a saved spot.
sub refreshResume()
    item = m.top.item
    if item = invalid then return
    if m.mode = "movie" then
        posSecs = getResume("m" + item.id)
        dur = getResumeDur("m" + item.id)
        showResumeBar(posSecs, dur)
        if posSecs > 0 then
            m.playLabel.text = "Resume from " + fmtClock(posSecs)
            m.restartBtn.visible = true
        else
            m.playLabel.text = "Play"
            m.restartBtn.visible = false
            if m.restartBtn.hasFocus() then m.playBtn.setFocus(true)
        end if
        styleButtons()
    else if m.seriesData <> invalid then
        sel = m.episodes.itemFocused
        fillEpisodes(m.seasons.itemFocused)
        if sel >= 0 then m.episodes.jumpToItem = sel
    end if
end sub

sub styleButtons()
    focusedPlay = not m.restartBtn.hasFocus()
    if focusedPlay then
        m.playPill.opacity = 1.0
        m.playLabel.color = "0x1A1A1AFF"
        m.restartPill.opacity = 0.18
        m.restartLabel.color = "0xFFFFFFFF"
    else
        m.playPill.opacity = 0.18
        m.playLabel.color = "0xFFFFFFFF"
        m.restartPill.opacity = 1.0
        m.restartLabel.color = "0x1A1A1AFF"
    end if
end sub
