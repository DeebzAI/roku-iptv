' All talking to the IPTV server happens here, off the UI thread.

sub init()
    m.top.functionName = "execute"
    m.ukRe = CreateObject("roRegex", "(^|[^A-Z])(UK|GB|U\.K|BRITISH|ENGLAND|SCOTLAND|WALES|NORTHERN IRELAND)([^A-Z]|$)", "i")
    m.usRe = CreateObject("roRegex", "(^|[^A-Z])(US|USA|UNITED STATES|AMERICA|AMERICAN)([^A-Z]|$)", "i")
    m.sportsRe = CreateObject("roRegex", "SPORT|NFL|NBA|WNBA|MLB|NHL|NCAA|ESPN|UFC|PPV|MLS|WWE|AEW|GOLF|TENNIS|BOXING|F1|FORMULA|NASCAR|INDYCAR|FOOTBALL|BASKETBALL|BASEBALL|HOCKEY|SOCCER|DAZN|FANDUEL|BALLY|BIG ?TEN|BIG ?12|SEC NETWORK|ACC NETWORK|PAC|FIGHT|RACING|MMA|OLYMPIC|GAME ?PASS|SUNDAY TICKET|LEAGUE|NFHS", "i")
    m.adultRe = CreateObject("roRegex", "ADULT|XXX|18\+|PORN|FOR ADULTS", "i")
end sub

sub execute()
    req = m.top.request
    mode = req.mode
    if mode = "login" then
        doLogin()
    else if mode = "categories" then
        doCategories(req)
    else if mode = "items" then
        doItems(req)
    else if mode = "vodinfo" then
        doVodInfo(req)
    else if mode = "seriesinfo" then
        doSeriesInfo(req)
    end if
end sub

function apiUrl(action as String) as String
    c = m.top.xtream
    url = c.base + "/player_api.php?username=" + c.user + "&password=" + c.pass
    if action <> "" then url = url + "&action=" + action
    return url
end function

function getJson(url as String, ua as String) as Dynamic
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    if ua <> "" then xfer.AddHeader("User-Agent", ua)
    if not xfer.AsyncGetToString() then return invalid
    msg = wait(60000, port)
    if type(msg) <> "roUrlEvent" then
        xfer.AsyncCancel()
        m.lastError = "timed out"
        return invalid
    end if
    if msg.GetResponseCode() <> 200 then
        m.lastError = "server returned " + msg.GetResponseCode().ToStr()
        return invalid
    end if
    return ParseJson(msg.GetString())
end function

sub doLogin()
    agents = ["VLC/3.0.20 LibVLC/3.0.20", "IPTVSmartersPlayer", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", ""]
    m.lastError = "no response"
    for each ua in agents
        data = getJson(apiUrl(""), ua)
        if data <> invalid and data.user_info <> invalid then
            if asStr(data.user_info.auth) = "1" then
                m.top.result = { ok: true, ua: ua, status: asStr(data.user_info.status) }
                return
            end if
            m.top.result = { ok: false, error: "login rejected (" + asStr(data.user_info.status) + ")" }
            return
        end if
    end for
    m.top.result = { ok: false, error: m.lastError }
end sub

sub doCategories(req as Object)
    kind = req.kind
    action = "get_live_categories"
    if kind = "movies" then action = "get_vod_categories"
    if kind = "series" then action = "get_series_categories"
    data = getJson(apiUrl(action), m.top.userAgent)
    us = []
    other = []
    if type(data) = "roArray" then
        for each c in data
            name = asStr(c.category_name).Trim()
            if name <> "" and not m.ukRe.IsMatch(name) and not m.adultRe.IsMatch(name) then
                sporty = m.sportsRe.IsMatch(name)
                keep = true
                if kind = "sports" and not sporty then keep = false
                if kind = "live" and sporty then keep = false
                if keep then
                    entry = { id: asStr(c.category_id), name: name }
                    if m.usRe.IsMatch(name) then us.Push(entry) else other.Push(entry)
                end if
            end if
        end for
    end if
    us.Append(other)
    m.top.result = { cats: us }
end sub

sub doItems(req as Object)
    kind = req.kind
    action = "get_live_streams"
    if kind = "movies" then action = "get_vod_streams"
    if kind = "series" then action = "get_series"
    data = getJson(apiUrl(action) + "&category_id=" + req.categoryId, m.top.userAgent)
    c = m.top.xtream
    row = CreateObject("roSGNode", "ContentNode")
    count = 0
    if type(data) = "roArray" then
        for each st in data
            if count >= 150 then exit for
            name = asStr(st.name).Trim()
            if name <> "" and not m.ukRe.IsMatch(Left(name, 6)) then
                item = row.createChild("ContentNode")
                item.title = name
                if kind = "movies" then
                    sid = asStr(st.stream_id)
                    ext = asStr(st.container_extension)
                    if ext = "" then ext = "mp4"
                    item.id = sid
                    item.HDPosterUrl = asStr(st.stream_icon)
                    item.addFields({ kind: "movie", cardType: "poster", url: c.base + "/movie/" + c.user + "/" + c.pass + "/" + sid + "." + ext, fmt: formatFor(ext), rating: asStr(st.rating), backdrop: "" })
                else if kind = "series" then
                    item.id = asStr(st.series_id)
                    item.HDPosterUrl = asStr(st.cover)
                    item.Description = asStr(st.plot)
                    bd = ""
                    if type(st.backdrop_path) = "roArray" and st.backdrop_path.Count() > 0 then bd = asStr(st.backdrop_path[0])
                    year = Left(asStr(st.releaseDate), 4)
                    if year = "" then year = Left(asStr(st.release_date), 4)
                    item.addFields({ kind: "series", cardType: "poster", url: "", fmt: "", rating: asStr(st.rating), backdrop: bd, genre: asStr(st.genre), year: year })
                else
                    sid = asStr(st.stream_id)
                    item.id = sid
                    item.HDPosterUrl = asStr(st.stream_icon)
                    item.addFields({ kind: "live", cardType: "tile", url: c.base + "/live/" + c.user + "/" + c.pass + "/" + sid + ".m3u8", fmt: "hls" })
                end if
                count = count + 1
            end if
        end for
    end if
    m.top.node = row
    m.top.result = { rowIndex: req.rowIndex, count: count }
end sub

function formatFor(ext as String) as String
    e = LCase(ext)
    if e = "mkv" then return "mkv"
    if e = "m3u8" then return "hls"
    if e = "mpd" then return "dash"
    return "mp4"
end function

function fmtMinutes(v as Dynamic) as String
    s = asStr(v)
    if s = "" then return ""
    ' "01:52:00" or seconds
    parts = s.Tokenize(":")
    if parts.Count() >= 2 then
        h = parts[0].ToInt()
        mi = parts[1].ToInt()
        if h > 0 then return h.ToStr() + "h " + mi.ToStr() + "m"
        return mi.ToStr() + "m"
    end if
    secs = s.ToInt()
    if secs > 0 then
        h = Int(secs / 3600)
        mi = Int((secs MOD 3600) / 60)
        if h > 0 then return h.ToStr() + "h " + mi.ToStr() + "m"
        return mi.ToStr() + "m"
    end if
    return ""
end function

sub doVodInfo(req as Object)
    data = getJson(apiUrl("get_vod_info") + "&vod_id=" + req.id, m.top.userAgent)
    out = { id: req.id, plot: "", year: "", genre: "", duration: "", rating: "", backdrop: "", cast: "" }
    if data <> invalid and data.info <> invalid then
        i = data.info
        out.plot = asStr(i.plot)
        if out.plot = "" then out.plot = asStr(i.description)
        out.year = Left(asStr(i.releasedate), 4)
        out.genre = asStr(i.genre)
        out.duration = fmtMinutes(i.duration)
        if out.duration = "" then out.duration = fmtMinutes(i.duration_secs)
        out.rating = asStr(i.rating)
        out.cast = asStr(i.cast)
        if type(i.backdrop_path) = "roArray" and i.backdrop_path.Count() > 0 then out.backdrop = asStr(i.backdrop_path[0])
    end if
    m.top.result = out
end sub

sub doSeriesInfo(req as Object)
    data = getJson(apiUrl("get_series_info") + "&series_id=" + req.id, m.top.userAgent)
    c = m.top.xtream
    out = { id: req.id, plot: "", year: "", genre: "", rating: "", backdrop: "", seasons: [], episodes: {} }
    if data = invalid then
        m.top.result = out
        return
    end if
    if data.info <> invalid then
        i = data.info
        out.plot = asStr(i.plot)
        out.year = Left(asStr(i.releaseDate), 4)
        out.genre = asStr(i.genre)
        out.rating = asStr(i.rating)
        if type(i.backdrop_path) = "roArray" and i.backdrop_path.Count() > 0 then out.backdrop = asStr(i.backdrop_path[0])
    end if
    eps = data.episodes
    groups = {}
    if type(eps) = "roAssociativeArray" then
        for each k in eps
            groups[k] = eps[k]
        end for
    else if type(eps) = "roArray" then
        for idx = 0 to eps.Count() - 1
            groups[(idx + 1).ToStr()] = eps[idx]
        end for
    end if
    nums = []
    for each k in groups
        nums.Push(k.ToInt())
    end for
    nums.Sort()
    for each n in nums
        key = n.ToStr()
        list = []
        src = groups[key]
        if type(src) = "roArray" then
            for each e in src
                ext = asStr(e.container_extension)
                if ext = "" then ext = "mp4"
                eid = asStr(e.id)
                title = asStr(e.title)
                dur = ""
                if e.info <> invalid then dur = fmtMinutes(e.info.duration)
                list.Push({ num: asStr(e.episode_num), title: title, duration: dur, url: c.base + "/series/" + c.user + "/" + c.pass + "/" + eid + "." + ext, fmt: formatFor(ext) })
            end for
        end if
        if list.Count() > 0 then
            out.seasons.Push(key)
            out.episodes[key] = list
        end if
    end for
    m.top.result = out
end sub
