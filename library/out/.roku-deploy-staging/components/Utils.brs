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

function makeFont(size as Integer, bold as Boolean) as Object
    f = CreateObject("roSGNode", "Font")
    if bold then f.uri = "font:BoldSystemFontFile" else f.uri = "font:SystemFontFile"
    f.size = size
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
