' Shared helpers (included by several components).

function asStr(v as Dynamic) as String
    if v = invalid then return ""
    t = type(v)
    if t = "String" or t = "roString" then return v
    if t = "Integer" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return v.ToStr()
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then
        if v = Int(v) then return Int(v).ToStr()
        return Str(v).Trim()
    end if
    if t = "Boolean" or t = "roBoolean" then
        if v then return "1"
        return "0"
    end if
    return ""
end function

' One Font node per size/weight for the whole app (shared through m.global), so
' the font file is loaded a handful of times, not once per card.
function makeFont(size as Integer, bold as Boolean) as Object
    g = m.global
    tag = "r"
    if bold then tag = "b"
    key = "font_" + tag + size.ToStr()
    if g.hasField(key) then return g[key]
    if not g.hasField("interOk") then
        fs = CreateObject("roFileSystem")
        g.addFields({ interOk: fs.Exists("libpkg:/fonts/Inter-Regular.ttf") and fs.Exists("libpkg:/fonts/Inter-SemiBold.ttf") })
    end if
    f = CreateObject("roSGNode", "Font")
    if g.interOk then
        if bold then f.uri = "libpkg:/fonts/Inter-SemiBold.ttf" else f.uri = "libpkg:/fonts/Inter-Regular.ttf"
    else
        if bold then f.uri = "font:BoldSystemFontFile" else f.uri = "font:SystemFontFile"
    end if
    f.size = size
    fld = {}
    fld[key] = f
    g.addFields(fld)
    return f
end function

function fmtTime(ts as Integer) as String
    dt = CreateObject("roDateTime")
    dt.FromSeconds(ts)
    dt.ToLocalTime()
    h = dt.GetHours()
    mins = dt.GetMinutes()
    suffix = "AM"
    if h >= 12 then suffix = "PM"
    h = h MOD 12
    if h = 0 then h = 12
    mm = mins.ToStr()
    if mins < 10 then mm = "0" + mm
    return h.ToStr() + ":" + mm + " " + suffix
end function

function joinParts(parts as Object) as String
    out = ""
    for each p in parts
        if p <> invalid and p <> "" then
            if out <> "" then out = out + "   ·   "
            out = out + p
        end if
    end for
    return out
end function

' Turns cached guide entries into display lines.
function guideLines(entry as Object) as Object
    out = { now: "No guide info for this channel", time: "", next: "", progress: 0 }
    if entry = invalid then return out
    items = entry.items
    if items = invalid or items.Count() = 0 then return out
    cur = items[0]
    nowTs = CreateObject("roDateTime").AsSeconds()
    out.now = cur.title
    out.time = fmtTime(cur.start) + " - " + fmtTime(cur.stop)
    minsLeft = Int((cur.stop - nowTs) / 60)
    if minsLeft >= 0 then out.time = out.time + "   ·   " + minsLeft.ToStr() + " min left"
    if cur.stop > cur.start then
        p = (nowTs - cur.start) / (cur.stop - cur.start)
        if p < 0 then p = 0
        if p > 1 then p = 1
        out.progress = p
    end if
    if items.Count() > 1 then out.next = "Up next  " + fmtTime(items[1].start) + "   " + items[1].title
    return out
end function

function freshGuide(cache as Object, sid as String) as Dynamic
    e = cache[sid]
    if e = invalid then return invalid
    now = CreateObject("roDateTime").AsSeconds()
    if now - e.fetched > 600 then return invalid
    if e.items.Count() > 0 and e.items[0].stop <= now then return invalid
    return e
end function

function parseXtream(url as String) as Dynamic
    baseRe = CreateObject("roRegex", "^(https?://[^/?]+)", "i")
    userRe = CreateObject("roRegex", "[?&]username=([^&]+)", "i")
    passRe = CreateObject("roRegex", "[?&]password=([^&]+)", "i")
    b = baseRe.Match(url)
    u = userRe.Match(url)
    p = passRe.Match(url)
    if b.Count() < 2 or u.Count() < 2 or p.Count() < 2 then return invalid
    return { base: b[1], user: u[1], pass: p[1] }
end function

' ---------- resume positions (kept small: registry space is limited) ----------

function resumeTable() as Object
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    if sec.Exists("resume") then
        t = ParseJson(sec.Read("resume"))
        if type(t) = "roAssociativeArray" then return t
    end if
    return {}
end function

function getResume(key as String) as Integer
    if key = "" then return 0
    e = resumeTable()[key]
    if e = invalid then return 0
    return e.p
end function

sub saveResume(key as String, posSecs as Integer, dur as Integer, meta = invalid as Dynamic)
    if key = "" then return
    t = resumeTable()
    ' Forget it if barely started or basically finished.
    if posSecs < 60 or (dur > 0 and posSecs > dur * 0.94) then
        t.Delete(key)
    else
        e = { p: posSecs, d: dur, t: CreateObject("roDateTime").AsSeconds() }
        old = t[key]
        if meta <> invalid then
            e.n = meta.title
            e.i = meta.poster
            e.u = meta.url
            e.f = meta.format
            e.s = meta.subtitle
        else if old <> invalid then
            e.n = old.n
            e.i = old.i
            e.u = old.u
            e.f = old.f
            e.s = old.s
        end if
        t[key] = e
    end if
    ' Keep only the 20 most recent (registry space is small).
    while t.Count() > 20
        oldestKey = ""
        oldest = 2147483647
        for each k in t
            if t[k].t < oldest then
                oldest = t[k].t
                oldestKey = k
            end if
        end for
        t.Delete(oldestKey)
    end while
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    sec.Write("resume", FormatJson(t))
    sec.Flush()
end sub

function fmtClock(secs as Integer) as String
    h = Int(secs / 3600)
    mi = Int((secs MOD 3600) / 60)
    se = secs MOD 60
    ss = se.ToStr()
    if se < 10 then ss = "0" + ss
    if h > 0 then
        mm = mi.ToStr()
        if mi < 10 then mm = "0" + mm
        return h.ToStr() + ":" + mm + ":" + ss
    end if
    return mi.ToStr() + ":" + ss
end function

' ---------- favorites ("Your Channels") ----------

function loadFavs() as Object
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    if sec.Exists("favs") then
        a = ParseJson(sec.Read("favs"))
        if type(a) = "roArray" then return a
    end if
    return []
end function

function isFav(id as String) as Boolean
    for each f in loadFavs()
        if f.id = id then return true
    end for
    return false
end function

' Adds or removes a channel. Returns true if it was added.
function toggleFav(item as Object) as Boolean
    favs = loadFavs()
    kept = []
    removed = false
    for each f in favs
        if f.id = item.id then
            removed = true
        else
            kept.Push(f)
        end if
    end for
    if not removed then
        logo = item.HDPosterUrl
        if logo = invalid then logo = ""
        kept.Unshift({ id: item.id, title: item.title, logo: logo, url: item.url })
        while kept.Count() > 30
            kept.Pop()
        end while
    end if
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    sec.Write("favs", FormatJson(kept))
    sec.Flush()
    return not removed
end function

' Recent half-watched titles for the Continue Watching row. prefix: "m" movies, "e" episodes.
function continueList(prefix as String) as Object
    t = resumeTable()
    list = []
    for each k in t
        e = t[k]
        if Left(k, 1) = prefix and e.u <> invalid and e.u <> "" then
            list.Push({ key: k, title: e.n, poster: e.i, url: e.u, fmt: e.f, sub: e.s, pos: e.p, dur: e.d, t: e.t, sortKey: 0 - e.t })
        end if
    end for
    list.SortBy("sortKey")
    return list
end function
