' Movie page (Play button) or show page (seasons + episodes).

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
    m.plot = m.top.findNode("plot")
    m.playBtn = m.top.findNode("playBtn")
    m.seasons = m.top.findNode("seasons")
    m.episodes = m.top.findNode("episodes")
    m.status = m.top.findNode("status")
    m.title.font = makeFont(62, true)
    m.meta.font = makeFont(28, false)
    m.plot.font = makeFont(28, false)
    m.status.font = makeFont(28, false)
    m.top.findNode("playLabel").font = makeFont(32, true)
    m.seasons.font = makeFont(28, true)
    m.seasons.focusedFont = makeFont(28, true)
    m.episodes.font = makeFont(28, false)
    m.episodes.focusedFont = makeFont(28, true)
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
    else if m.seriesData <> invalid and m.seriesData.seasons.Count() > 0 then
        m.seasons.setFocus(true)
    end if
end sub

sub onItem()
    item = m.top.item
    m.mode = item.kind
    m.title.text = item.title
    m.meta.text = ""
    m.plot.text = item.Description
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
        m.meta.text = joinParts([r.year, r.genre, r.duration, ratingText(r.rating)])
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
    for each e in list
        c = content.createChild("ContentNode")
        label = e.title
        if e.num <> "" then label = e.num + ".   " + label
        if e.duration <> "" then label = label + "   (" + e.duration + ")"
        c.title = label
    end for
    m.episodes.content = content
end sub

sub onEpisodeSelected()
    list = m.seriesData.episodes[m.currentSeason]
    e = list[m.episodes.itemSelected]
    if e = invalid then return
    m.top.playRequest = { url: e.url, title: e.title, format: e.fmt, subtitle: m.top.item.title + "  ·  Season " + m.currentSeason }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.mode = "movie" then
        if key = "OK" and m.playBtn.hasFocus() then
            item = m.top.item
            m.top.playRequest = { url: item.url, title: item.title, format: item.fmt, subtitle: m.meta.text }
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
