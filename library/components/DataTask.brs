' All talking to the IPTV server happens here, off the UI thread.

sub init()
    m.top.functionName = "execute"
    m.ukRe = CreateObject("roRegex", "(^|[^A-Z])(UK|GB|U\.K|BRITISH|ENGLAND|SCOTLAND|WALES|NORTHERN IRELAND)([^A-Z]|$)", "i")
    m.usRe = CreateObject("roRegex", "(^|[^A-Z])(US|USA|UNITED STATES|AMERICA|AMERICAN)([^A-Z]|$)", "i")
    m.sportsRe = CreateObject("roRegex", "SPORT|NFL|NBA|WNBA|MLB|NHL|NCAA|ESPN|UFC|PPV|MLS|WWE|AEW|GOLF|TENNIS|BOXING|F1|FORMULA|NASCAR|INDYCAR|FOOTBALL|BASKETBALL|BASEBALL|HOCKEY|SOCCER|DAZN|FANDUEL|BALLY|BIG ?TEN|BIG ?12|SEC NETWORK|ACC NETWORK|PAC|FIGHT|RACING|MMA|OLYMPIC|GAME ?PASS|SUNDAY TICKET|LEAGUE|NFHS|FLOW|MILB|NJCAA|FITE", "i")
    m.adultRe = CreateObject("roRegex", "ADULT|XXX|18\+|PORN|FOR ADULTS", "i")
    m.ieRe = CreateObject("roRegex", "(^|[^A-Z])(IE|IRELAND|IRISH)([^A-Z]|$)", "i")
    m.spanishCatRe = CreateObject("roRegex", "LATIN|TELEMUNDO|UNIVISION|TUDN|ESPA(N|Ñ)OL|DEPORTES|MEXIC", "i")
    m.junkLiveRe = CreateObject("roRegex", "KIDS|BABY", "i")
    m.localCatRe = CreateObject("roRegex", "(ABC|CBS|FOX|NBC|PBS) NETWORK|CW & MY", "i")
    m.spanishChanRe = CreateObject("roRegex", "DEPORTES|ESPA(N|Ñ)OL|TUDN|TELEMUNDO|UNIVISION|UNIMAS|GALAVISION|\(ES\)|SPANISH", "i")
    m.audioRe = CreateObject("roRegex", "RADIO|AUDIO|SIRIUS|MUSIC CHOICE|STINGRAY|PODCAST", "i")
    m.bostonRe = CreateObject("roRegex", "BOSTON|WCVB|WBZ|WFXT|WBTS|WHDH|WGBH|WLVI|WSBK|NECN", "i")
    m.prefixRe = CreateObject("roRegex", "^(US|USA|UK|CA)\s*[:|\-]\s*", "i")
    m.qualityRe = CreateObject("roRegex", "(^|\s|\(|\[)(SD|HD|FHD|UHD|4K|HEVC|H265|RAW|HQ|LQ|1080P?|720P?|60FPS|50FPS)(?=$|\s|\)|\])", "i")
    m.spacesRe = CreateObject("roRegex", "[\s\(\)\[\]]+", "")
    m.notEventCatRe = CreateObject("roRegex", "SPORT\+|FANDUEL|REPLAY|TEAMS|NETWORK", "i")
    m.vsRe = CreateObject("roRegex", "\s(VS\.?|V\.?|@)\s", "i")
    m.noEventRe = CreateObject("roRegex", "NO EVENT|NO GAME|OFF ?AIR|NO STREAM|STAND ?BY|COMING SOON", "i")
    m.leaguePrefixRe = CreateObject("roRegex", "^([A-Z+]{2,10}\s*[|:\-]?\s*){0,3}\d{1,3}\s*[:|\-](?!\d)\s*", "")
    m.isoRe = CreateObject("roRegex", "(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})(:\d{2})?", "")
    m.timeRe = CreateObject("roRegex", "(\d{1,2}):(\d{2})\s*([AP]\.?M\.?)?\s*(ET|EST|EDT|PT|PST|PDT|CT|CST|CDT|MT|MST|MDT|UK|GMT|BST|UTC|CET|CEST)?", "i")
    m.dateRe = CreateObject("roRegex", "\b(\d{1,2})[/.](\d{1,2})([/.]\d{2,4})?\b", "")
    m.monthNameRe = CreateObject("roRegex", "\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s+(\d{1,2})\b", "i")
    m.dayMonthNameRe = CreateObject("roRegex", "\b(\d{1,2})(ST|ND|RD|TH)?\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\b", "i")
    m.zoneRe = CreateObject("roRegex", "\b(ET|EST|EDT|PT|PST|PDT|CT|CST|CDT|MT|MST|MDT|UK|GMT|BST|UTC|CET|CEST)\b", "i")
    m.dayNameRe = CreateObject("roRegex", "\b(MON|TUE|TUES|WED|THU|THUR|THURS|FRI|SAT|SUN)(DAY)?\b\.?", "i")
    m.emptyParensRe = CreateObject("roRegex", "\(\s*\)|\[\s*\]", "")
    m.sdRe = CreateObject("roRegex", "(^|\s|\(|\[)SD($|\s|\)|\])", "i")
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
    kept = []
    localIds = []
    eventIds = []
    idx = 0
    if type(data) = "roArray" then
        for each c in data
            raw = asStr(c.category_name).Trim()
            up = UCase(raw)
            idx = idx + 1
            if raw <> "" and not m.ukRe.IsMatch(raw) and not m.ieRe.IsMatch(raw) and not m.adultRe.IsMatch(raw) and not m.spanishCatRe.IsMatch(raw) then
                sporty = m.sportsRe.IsMatch(raw)
                keep = true
                if (kind = "sports" or kind = "later") and not sporty then keep = false
                if kind = "live" and sporty then keep = false
                if kind = "live" and m.junkLiveRe.IsMatch(raw) then keep = false
                if keep then
                    cid = asStr(c.category_id)
                    if kind = "live" and m.localCatRe.IsMatch(raw) then localIds.Push(cid)
                    if (kind = "sports" or kind = "later") and not m.notEventCatRe.IsMatch(raw) then
                        eventIds.Push({ id: cid, league: leagueGroup(up) })
                    end if
                    rank = categoryRank(kind, up)
                    if not m.usRe.IsMatch(raw) and rank >= 90 then rank = rank + 50
                    kept.Push({ id: cid, name: prettyName(raw), sortKey: rank * 10000 + idx })
                end if
            end if
        end for
    end if
    if kind = "live" and localIds.Count() > 0 then
        ids = ""
        for each i in localIds
            if ids <> "" then ids = ids + ","
            ids = ids + i
        end for
        kept.Push({ id: "local:" + ids, name: "Boston Local", sortKey: 0 })
    end if
    if kind = "sports" and eventIds.Count() > 0 then
        ' tag each category: 0 = NFL/NBA/NHL/MLB, 1 = everything else
        ' only NFL / NBA / NHL / MLB categories feed Games On Now
        ids = ""
        for each e in eventIds
            if e.league <= 3 then
                if ids <> "" then ids = ids + ","
                ids = ids + e.id + "~0"
            end if
        end for
        if ids <> "" then kept.Push({ id: "games:" + ids, name: "Games On Now", sortKey: 0 })
    end if
    if kind = "later" then
        groupNames = ["NFL", "NBA", "NHL", "MLB", "College Football", "College Basketball", "UFC & Boxing", "Soccer", "Other Sports"]
        out = []
        for g = 0 to groupNames.Count() - 1
            ids = ""
            for each e in eventIds
                if e.league = g then
                    if ids <> "" then ids = ids + ","
                    ids = ids + e.id
                end if
            end for
            if ids <> "" then out.Push({ id: "soon:" + ids, name: groupNames[g] })
        end for
        m.top.result = { cats: out }
        return
    end if
    kept.SortBy("sortKey")
    out = []
    for each k in kept
        out.Push({ id: k.id, name: k.name })
    end for
    m.top.result = { cats: out }
end sub

' Which league bucket a sports category belongs to (index into the Later Today rows).
function leagueGroup(up as String) as Integer
    if Instr(1, up, "NFL") > 0 then return 0
    if Instr(1, up, "NBA") > 0 and Instr(1, up, "WNBA") = 0 then return 1
    if Instr(1, up, "NHL") > 0 then return 2
    if Instr(1, up, "MLB") > 0 and Instr(1, up, "MILB") = 0 then return 3
    if Instr(1, up, "NCAAF") > 0 then return 4
    if Instr(1, up, "NCAAB") > 0 or Instr(1, up, "NCAAW") > 0 or Instr(1, up, "NJCAA") > 0 then return 5
    if Instr(1, up, "UFC") > 0 or Instr(1, up, "BOXING") > 0 or Instr(1, up, "FITE") > 0 then return 6
    if Instr(1, up, "MLS") > 0 or Instr(1, up, "SOCCER") > 0 then return 7
    return 8
end function

' Lower rank = higher up the screen.
function categoryRank(kind as String, up as String) as Integer
    r = 90
    if kind = "sports" then
        rules = [["SPORT+", 1], ["FANDUEL", 2], ["NFL", 10], ["NCAAF", 12], ["WNBA", 45], ["NBA", 14], ["NCAAW", 46], ["NCAAB", 16], ["NHL", 18], ["MILB", 60], ["MLB", 20], ["UFC", 25], ["BOXING", 26], ["PAY PER VIEW", 28], ["PPV", 30], ["ESPN", 32], ["PEACOCK", 34], ["PARAMOUNT", 34], ["SLING", 35], ["MLS", 40], ["SOCCER", 41], ["TENNIS", 50], ["COLLEGE BASEBALL", 52], ["FLOW", 55], ["MOTOGP", 56], ["MXGP", 56], ["NJCAA", 62], ["SOFTBALL", 62]]
        for each rule in rules
            if Instr(1, up, rule[0]) > 0 then
                r = rule[1]
                exit for
            end if
        end for
        if not inSeason(up) then r = r + 40
        if Instr(1, up, "REPLAY") > 0 then r = r + 100
    else if kind = "live" then
        rules = [["24/7", 50], ["OD REALITY", 45], ["OD ", 60], ["NEWS", 10], ["ENTERTAINMENT", 20], ["HBO", 31], ["SHOWTIME", 32], ["STARZ", 33], ["MOVIES", 30], ["DOCU", 40], ["REALITY", 45], ["OD ", 60], ["SPECTRUM", 70], ["ABC NETWORK", 80], ["CBS NETWORK", 81], ["FOX NETWORK", 82], ["NBC NETWORK", 83], ["PBS", 84], ["CW", 85], ["HALLMARK", 95], ["MUSIC", 96]]
        for each rule in rules
            if Instr(1, up, rule[0]) > 0 then
                r = rule[1]
                exit for
            end if
        end for
    end if
    return r
end function

' Rough league seasons by month (1-12). Leagues not listed are treated as in season.
function inSeason(up as String) as Boolean
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    mo = dt.GetMonth()
    seasons = [["WNBA", [5, 6, 7, 8, 9, 10]], ["NCAAF", [8, 9, 10, 11, 12, 1]], ["NFL", [8, 9, 10, 11, 12, 1, 2]], ["NCAAW", [11, 12, 1, 2, 3, 4]], ["NCAAB", [11, 12, 1, 2, 3, 4]], ["NJCAA", [11, 12, 1, 2, 3, 4]], ["NBA", [10, 11, 12, 1, 2, 3, 4, 5, 6]], ["NHL", [10, 11, 12, 1, 2, 3, 4, 5, 6]], ["MILB", [4, 5, 6, 7, 8, 9]], ["MLB", [2, 3, 4, 5, 6, 7, 8, 9, 10]], ["COLLEGE BASEBALL", [2, 3, 4, 5, 6]], ["SOFTBALL", [2, 3, 4, 5, 6]], ["MLS", [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]]]
    for each sea in seasons
        if Instr(1, up, sea[0]) > 0 then
            for each mth in sea[1]
                if mth = mo then return true
            end for
            return false
        end if
    end for
    return true
end function

' "┃USA┃ DOCU | LIFESTYLE" -> "Docs & Lifestyle"
function prettyName(raw as String) as String
    name = stripBoxPrefix(raw)
    up = UCase(name)
    special = { "SPORT+": "Sports Channels", "NEWS NETWORK": "News", "DOCU | LIFESTYLE": "Docs & Lifestyle", "MOVIES | SERIES": "Movies & Series", "FANDUEL SPORTS NETWORK": "FanDuel Sports (Regional)", "CW & MY": "CW & MyNetwork Stations", "OD REALITY SHOW": "Reality Shows", "PAY PER VIEW": "Pay-Per-View", "PAY PER VIEW REPLAY": "Pay-Per-View Replays" }
    if special.DoesExist(up) then return special[up]
    if Left(up, 3) = "OD " then name = Mid(name, 4) + " (On Demand)"
    if Right(up, 8) = " NETWORK" and Len(up) <= 12 then name = Left(name, Len(name) - 8) + " Stations"
    name = name.Replace(" | ", " · ")
    return titleCase(name)
end function

function stripBoxPrefix(raw as String) as String
    bar = Chr(&h2503)
    name = raw.Trim()
    if Left(name, 1) = bar then
        p = Instr(2, name, bar)
        if p > 0 then name = Mid(name, p + 1).Trim()
    end if
    return name
end function

function titleCase(s as String) as String
    keepUpper = { NFL: 1, NBA: 1, WNBA: 1, NHL: 1, MLB: 1, MILB: 1, MLS: 1, UFC: 1, PPV: 1, HBO: 1, ABC: 1, CBS: 1, NBC: 1, PBS: 1, CW: 1, MY: 1, NCAAF: 1, NCAAB: 1, NCAA: 1, NJCAA: 1, ESPN: 1, "ESPN+": 1, "BET+": 1, ALLBLK: 1, TV: 1, "TV+": 1, VIP: 1, FITE: 1, MXGP: 1, MOTOGP: 1, "24/7": 1, "APPLE+": 1, USA: 1, US: 1 }
    out = ""
    for each w in s.Tokenize(" ")
        uw = UCase(w)
        if keepUpper.DoesExist(uw) then
            word = uw
            if uw = "MOTOGP" then word = "MotoGP"
            if uw = "MILB" then word = "MiLB"
            if uw = "APPLE+" then word = "Apple TV+"
        else if Len(w) > 0 then
            word = UCase(Left(w, 1)) + LCase(Mid(w, 2))
        else
            word = w
        end if
        if out <> "" then out = out + " "
        out = out + word
    end for
    return out
end function

' Channel name cleanup: drop "USA: " / "US| " / "┃US┃ " prefixes.
function cleanChannelName(raw as String) as String
    name = stripBoxPrefix(raw)
    if m.prefixRe.IsMatch(name) then name = m.prefixRe.Replace(name, "")
    return name.Trim()
end function

' Big national sports channels first (base names are uppercase, quality tags removed).
function channelPriority(base as String) as Integer
    if m.priorityRes = invalid then
        pats = ["^ESPN$", "REDZONE", "^ESPN ?2$", "^(FS1|FOX SPORTS 1)$", "^NFL NETWORK", "^TNT( SPORTS)?$", "^TBS$", "^NBA ?TV$", "^NHL NETWORK", "^NESN", "NBC SPORTS BOSTON|^NBCSB", "^MLB NETWORK", "^CBS SPORTS", "^ESPNU$", "^SEC NETWORK", "^(BIG TEN|BTN)", "^ACC NETWORK", "^ESPN ?N?EWS", "^(FS2|FOX SPORTS 2)$", "^GOLF", "^TENNIS CHANNEL"]
        m.priorityRes = []
        for each p in pats
            m.priorityRes.Push(CreateObject("roRegex", p, "i"))
        end for
    end if
    for i = 0 to m.priorityRes.Count() - 1
        if m.priorityRes[i].IsMatch(base) then return i + 1
    end for
    return 99
end function

function baseChannelName(name as String) as String
    b = m.qualityRe.ReplaceAll(UCase(name), " ")
    b = m.spacesRe.ReplaceAll(b, " ")
    return b.Trim()
end function

sub doItems(req as Object)
    kind = req.kind
    c = m.top.xtream
    row = CreateObject("roSGNode", "ContentNode")
    count = 0

    if kind = "movies" or kind = "series" then
        action = "get_vod_streams"
        if kind = "series" then action = "get_series"
        data = getJson(apiUrl(action) + "&category_id=" + req.categoryId, m.top.userAgent)
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
                    else
                        item.id = asStr(st.series_id)
                        item.HDPosterUrl = asStr(st.cover)
                        item.Description = asStr(st.plot)
                        bd = ""
                        if type(st.backdrop_path) = "roArray" and st.backdrop_path.Count() > 0 then bd = asStr(st.backdrop_path[0])
                        year = Left(asStr(st.releaseDate), 4)
                        if year = "" then year = Left(asStr(st.release_date), 4)
                        item.addFields({ kind: "series", cardType: "poster", url: "", fmt: "", rating: asStr(st.rating), backdrop: bd, genre: asStr(st.genre), year: year })
                    end if
                    count = count + 1
                end if
            end for
        end if
        m.top.node = row
        m.top.result = { rowIndex: req.rowIndex, count: count }
        return
    end if

    ' ----- live / sports channels -----
    catId = req.categoryId
    if Left(catId, 6) = "games:" then
        doGamesRow(req, Mid(catId, 7), "live")
        return
    end if
    if Left(catId, 5) = "soon:" then
        doGamesRow(req, Mid(catId, 6), "soon")
        return
    end if
    streams = []
    bostonOnly = false
    if Left(catId, 6) = "local:" then
        bostonOnly = true
        for each oneId in Mid(catId, 7).Tokenize(",")
            part = getJson(apiUrl("get_live_streams") + "&category_id=" + oneId, m.top.userAgent)
            if type(part) = "roArray" then streams.Append(part)
        end for
    else
        part = getJson(apiUrl("get_live_streams") + "&category_id=" + catId, m.top.userAgent)
        if type(part) = "roArray" then streams = part
    end if

    ' First pass: clean names, drop junk, note which channels have a non-SD copy.
    entries = []
    hasGood = {}
    for each st in streams
        raw = asStr(st.name).Trim()
        name = cleanChannelName(raw)
        skip = (name = "") or m.spanishChanRe.IsMatch(raw) or m.audioRe.IsMatch(raw) or m.ukRe.IsMatch(Left(raw, 8))
        if not skip and bostonOnly and not m.bostonRe.IsMatch(raw) then skip = true
        if not skip and Left(name, 4) = "####" then skip = true ' divider rows some providers use
        if not skip then
            base = baseChannelName(name)
            isSD = m.sdRe.IsMatch(name)
            if not isSD then hasGood[base] = true
            entries.Push({ st: st, name: name, base: base, sd: isSD })
        end if
    end for

    if kind = "sports" then
        n = 0
        for each e in entries
            n = n + 1
            e.sortKey = channelPriority(e.base) * 100000 + n
        end for
        entries.SortBy("sortKey")
    end if

    for each e in entries
        if count >= 300 then exit for
        if not (e.sd and hasGood[e.base] = true) then
            st = e.st
            sid = asStr(st.stream_id)
            item = row.createChild("ContentNode")
            item.title = e.name
            item.id = sid
            item.HDPosterUrl = asStr(st.stream_icon)
            item.addFields({ kind: "live", cardType: "tile", url: c.base + "/live/" + c.user + "/" + c.pass + "/" + sid + ".m3u8", fmt: "hls" })
            count = count + 1
        end if
    end for
    m.top.node = row
    m.top.result = { rowIndex: req.rowIndex, count: count }
end sub

' ---------- Games On Now ----------

sub doGamesRow(req as Object, idList as String, mode as String)
    c = m.top.xtream
    nowTs = CreateObject("roDateTime").AsSeconds()
    games = []
    seen = {}
    for each token in idList.Tokenize(",")
        bits = token.Tokenize("~")
        oneId = bits[0]
        pri = 1
        if bits.Count() > 1 then pri = bits[1].ToInt()
        part = getJson(apiUrl("get_live_streams") + "&category_id=" + oneId, m.top.userAgent)
        if type(part) = "roArray" then
            for each st in part
                raw = asStr(st.name)
                if m.vsRe.IsMatch(raw) and not m.noEventRe.IsMatch(raw) and not m.spanishChanRe.IsMatch(raw) then
                    name = cleanChannelName(raw)
                    ts = parseEventTime(name, nowTs)
                    state = ""
                    if ts = 0 then
                        state = "" ' no readable time: skip rather than guess
                    else if ts <= nowTs and nowTs - ts < 4 * 3600 then
                        state = "live"
                    else if ts > nowTs and ts - nowTs < 12 * 3600 then
                        state = "soon"
                    end if
                    if state <> mode then state = ""
                    if state <> "" then
                        matchup = matchupText(name)
                        key = UCase(matchup)
                        if matchup <> "" and not seen.DoesExist(key) then
                            seen[key] = true
                            order = ts
                            if mode = "live" and pri = 1 then order = ts + 100000000 ' big four leagues first
                            games.Push({ st: st, name: name, matchup: matchup, ts: ts, state: state, sortKey: order })
                        end if
                    end if
                end if
            end for
        end if
    end for
    games.SortBy("sortKey")

    row = CreateObject("roSGNode", "ContentNode")
    count = 0
    for each g in games
        if count >= 60 then exit for
        sid = asStr(g.st.stream_id)
        label = "LIVE"
        if g.state = "soon" then label = fmtTime(g.ts)
        item = row.createChild("ContentNode")
        item.title = label + "  ·  " + g.matchup
        item.id = sid
        item.HDPosterUrl = asStr(g.st.stream_icon)
        item.Description = g.name
        item.addFields({ kind: "live", cardType: "tile", url: c.base + "/live/" + c.user + "/" + c.pass + "/" + sid + ".m3u8", fmt: "hls" })
        count = count + 1
    end for
    m.top.node = row
    m.top.result = { rowIndex: req.rowIndex, count: count }
end sub

' "NFL 03: Buffalo Bills vs Kansas City Chiefs @ 4:25 PM ET" -> "Buffalo Bills vs Kansas City Chiefs"
function matchupText(name as String) as String
    t = m.leaguePrefixRe.Replace(name, "")
    t = m.isoRe.ReplaceAll(t, " ")
    t = m.timeRe.ReplaceAll(t, " ")
    t = m.dateRe.ReplaceAll(t, " ")
    t = m.monthNameRe.ReplaceAll(t, " ")
    t = m.dayMonthNameRe.ReplaceAll(t, " ")
    t = m.dayNameRe.ReplaceAll(t, " ")
    t = m.zoneRe.ReplaceAll(t, " ")
    t = m.emptyParensRe.ReplaceAll(t, " ")
    t = m.spacesRe.ReplaceAll(t, " ").Trim()
    ' trim dangling separators left behind by removed times
    while Len(t) > 0 and Instr(1, "-|@:,.", Right(t, 1)) > 0
        t = Left(t, Len(t) - 1).Trim()
    end while
    while Len(t) > 0 and Instr(1, "-|@:,.", Left(t, 1)) > 0
        t = Mid(t, 2).Trim()
    end while
    return t
end function

function pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' Reads a start time out of an event name. Returns 0 if no usable time is found.
' Times count as US Eastern unless marked (PT/CT/MT, UK/GMT/BST, CET).
function parseEventTime(name as String, nowTs as Integer) as Integer
    today = CreateObject("roDateTime")
    today.ToLocalTime()
    y = today.GetYear()
    mo = today.GetMonth()
    d = today.GetDayOfMonth()
    h = -1
    mi = 0
    zone = ""
    dateGiven = false
    europeZone = false

    iso = m.isoRe.Match(name)
    if iso.Count() >= 6 then
        y = iso[1].ToInt()
        mo = iso[2].ToInt()
        d = iso[3].ToInt()
        h = iso[4].ToInt()
        mi = iso[5].ToInt()
        dateGiven = true
        zm = m.zoneRe.Match(name)
        if zm.Count() >= 2 then zone = UCase(zm[1])
    else
        tm = m.timeRe.Match(name)
        if tm.Count() < 3 then return 0
        hourText = tm[1]
        h = hourText.ToInt()
        mi = tm[2].ToInt()
        ampm = ""
        if tm.Count() > 3 then ampm = UCase(tm[3])
        if tm.Count() > 4 then zone = UCase(tm[4])
        if zone = "" then
            zm = m.zoneRe.Match(name)
            if zm.Count() >= 2 then zone = UCase(zm[1])
        end if
        europeZone = (zone = "UK" or zone = "GMT" or zone = "BST" or zone = "UTC" or zone = "CET" or zone = "CEST")
        if Left(ampm, 1) = "P" and h < 12 then h = h + 12
        if Left(ampm, 1) = "A" and h = 12 then h = 0
        ' "7:30" with no AM/PM is probably evening; "01:30" or a UK/EU time is a 24-hour clock
        if ampm = "" and not europeZone and Left(hourText, 1) <> "0" and h >= 1 and h <= 11 then h = h + 12

        md = monthDay(name, mo, d)
        if md <> invalid then
            mo = md.mo
            d = md.d
            dateGiven = true
        end if
    end if
    if h < 0 or h > 23 or mi > 59 or mo < 1 or mo > 12 or d < 1 or d > 31 then return 0

    ' convert the stated zone to Eastern
    if zone = "PT" or zone = "PST" or zone = "PDT" then h = h + 3
    if zone = "CT" or zone = "CST" or zone = "CDT" then h = h + 1
    if zone = "MT" or zone = "MST" or zone = "MDT" then h = h + 2
    if zone = "UK" or zone = "GMT" or zone = "BST" or zone = "UTC" then h = h - 5
    if zone = "CET" or zone = "CEST" then h = h - 6

    dt = CreateObject("roDateTime")
    dt.FromISO8601String(y.ToStr() + "-" + pad2(mo) + "-" + pad2(d) + "T00:00:00")
    ts = dt.AsSeconds() + h * 3600 + mi * 60
    ts = ts + CreateObject("roDateTime").GetTimeZoneOffset() * 60
    if not dateGiven then
        ' a weekday like "Wed" with no date: move to that day
        wd = m.dayNameRe.Match(name)
        if wd.Count() >= 2 then
            days = { SUN: 0, MON: 1, TUE: 2, WED: 3, THU: 4, FRI: 5, SAT: 6 }
            target = days[UCase(Left(wd[1], 3))]
            if target <> invalid then
                ahead = (target - today.GetDayOfWeek() + 7) MOD 7
                ' UK-time listings for late US games carry the next day's name
                if ahead = 1 and europeZone = true and h <= 6 then ahead = 0
                ts = ts + ahead * 86400
                return ts
            end if
        end if
        if ts < nowTs - 6 * 3600 then ts = ts + 86400
    end if
    return ts
end function

' Finds a month/day in the name. Handles 11/15, 15/11, 15.11, "Nov 15", "15 Nov".
' Ambiguous numeric dates pick whichever is closest to today.
function monthDay(name as String, curMo as Integer, curD as Integer) as Dynamic
    months = { JAN: 1, FEB: 2, MAR: 3, APR: 4, MAY: 5, JUN: 6, JUL: 7, AUG: 8, SEP: 9, OCT: 10, NOV: 11, DEC: 12 }
    mn = m.monthNameRe.Match(name)
    if mn.Count() >= 3 then
        mo = months[UCase(Left(mn[1], 3))]
        if mo <> invalid then return { mo: mo, d: mn[2].ToInt() }
    end if
    nm = m.dayMonthNameRe.Match(name)
    if nm.Count() >= 3 then
        mo = months[UCase(Left(nm[3], 3))]
        if mo <> invalid then return { mo: mo, d: nm[1].ToInt() }
    end if
    nd = m.dateRe.Match(name)
    if nd.Count() >= 3 then
        a = nd[1].ToInt()
        b = nd[2].ToInt()
        if a > 12 and b <= 12 then return { mo: b, d: a }
        if b > 12 and a <= 12 then return { mo: a, d: b }
        if a <= 12 and b <= 12 then
            ' both readings possible: choose the one nearer today
            dist1 = Abs((a - curMo) * 31 + (b - curD))
            dist2 = Abs((b - curMo) * 31 + (a - curD))
            if dist2 < dist1 then return { mo: b, d: a }
            return { mo: a, d: b }
        end if
    end if
    return invalid
end function

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
    out = { id: req.id, plot: "", year: "", genre: "", duration: "", rating: "", backdrop: "", cast: "", quality: "", size: "" }
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
        out.quality = qualityLabel(i.video)
        secs = asStr(i.duration_secs).ToInt()
        kbps = asStr(i.bitrate).ToInt()
        if secs > 0 and kbps > 0 then
            gb = (kbps * secs) / 8.0 / 1000000.0
            if gb >= 1 then
                out.size = Str(Int(gb * 10) / 10.0).Trim() + " GB"
            else
                out.size = Int(gb * 1000).ToStr() + " MB"
            end if
        end if
    end if
    m.top.result = out
end sub

function qualityLabel(v as Dynamic) as String
    if type(v) <> "roAssociativeArray" then return ""
    w = asStr(v.width).ToInt()
    h = asStr(v.height).ToInt()
    label = ""
    if w >= 3200 or h >= 1800 then
        label = "4K"
    else if w >= 1800 or h >= 1000 then
        label = "1080p"
    else if w >= 1200 or h >= 700 then
        label = "720p"
    else if w > 0 or h > 0 then
        label = "SD"
    end if
    codec = LCase(asStr(v.codec_name))
    if codec = "hevc" or codec = "h265" then label = label + " HEVC"
    return label.Trim()
end function

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
                list.Push({ id: eid, num: asStr(e.episode_num), title: title, duration: dur, url: c.base + "/series/" + c.user + "/" + c.pass + "/" + eid + "." + ext, fmt: formatFor(ext) })
            end for
        end if
        if list.Count() > 0 then
            out.seasons.Push(key)
            out.episodes[key] = list
        end if
    end for
    m.top.result = out
end sub
