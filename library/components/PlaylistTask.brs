' Downloads and parses an M3U / M3U8 playlist off the render thread.

sub init()
    m.top.functionName = "loadPlaylistTask"
end sub

sub loadPlaylistTask()
    m.top.error = ""
    agents = [
        "VLC/3.0.20 LibVLC/3.0.20",
        "IPTVSmartersPlayer",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
        ""
    ]
    lastError = ""

    ' Xtream Codes accounts: use the player API (what IPTV apps use).
    creds = parseXtream(m.top.url)
    if creds <> invalid then
        for each ua in agents
            m.top.progress = "Logging in to your IPTV account..."
            m.top.error = ""
            root = loadXtream(creds, ua)
            if root <> invalid and root.getChildCount() > 0 then
                m.top.userAgent = ua
                m.top.result = root
                m.top.error = ""
                m.top.done = true
                return
            end if
            if m.top.error <> "" then lastError = m.top.error
        end for
    end if

    urls = buildUrlVariants(m.top.url)
    attempt = 0
    total = urls.Count() * agents.Count()
    for each u in urls
        for each ua in agents
            attempt = attempt + 1
            m.top.progress = "Loading playlist... (try " + attempt.ToStr() + " of " + total.ToStr() + ")"
            m.top.error = ""
            text = fetchText(u, ua)
            if text <> invalid and (Instr(1, text, "#EXTINF") > 0 or Instr(1, text, "#EXTM3U") > 0) then
                m.top.progress = "Reading channels..."
                root = parseM3U(text)
                if root.getChildCount() > 0 then
                    m.top.userAgent = ua
                    m.top.result = root
                    m.top.error = ""
                    m.top.done = true
                    return
                end if
                lastError = "No channels found in that playlist."
            else if m.top.error <> "" then
                lastError = m.top.error
            else
                lastError = "The server didn't send a playlist."
            end if
        end for
    end for
    m.top.error = lastError
    m.top.done = true
end sub

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

function loadXtream(c as Object, ua as String) as Dynamic
    api = c.base + "/player_api.php?username=" + c.user + "&password=" + c.pass

    text = fetchText(api, ua)
    if text = invalid then return invalid
    info = ParseJson(text)
    if info = invalid or info.user_info = invalid then
        m.top.error = "The server's login reply wasn't understood."
        return invalid
    end if
    if info.user_info.auth <> invalid and asStr(info.user_info.auth) = "0" then
        m.top.error = "Login rejected - check your username and password."
        return invalid
    end if

    m.top.progress = "Loading categories..."
    names = {}
    order = []
    text = fetchText(api + "&action=get_live_categories", ua)
    if text <> invalid then
        cats = ParseJson(text)
        if type(cats) = "roArray" then
            for each cat in cats
                id = asStr(cat.category_id)
                names[id] = asStr(cat.category_name)
                order.Push(id)
            end for
        end if
    end if

    m.top.progress = "Loading channels (big lists can take a minute)..."
    text = fetchText(api + "&action=get_live_streams", ua)
    if text = invalid then return invalid
    streams = ParseJson(text)
    if type(streams) <> "roArray" then
        m.top.error = "The server's channel list wasn't understood."
        return invalid
    end if

    m.top.progress = "Building channel list..."
    byCat = {}
    for each st in streams
        id = asStr(st.category_id)
        if byCat[id] = invalid then
            byCat[id] = []
            if names[id] = invalid then
                names[id] = "Other"
                order.Push(id)
            end if
        end if
        byCat[id].Push(st)
    end for

    root = CreateObject("roSGNode", "ContentNode")
    for each id in order
        list = byCat[id]
        if list <> invalid then
            g = root.createChild("ContentNode")
            g.title = names[id]
            for each st in list
                ch = g.createChild("ContentNode")
                ch.title = asStr(st.name)
                ch.HDPosterUrl = asStr(st.stream_icon)
                ch.url = c.base + "/live/" + c.user + "/" + c.pass + "/" + asStr(st.stream_id) + ".m3u8"
                ch.streamFormat = "hls"
            end for
        end if
    end for
    return root
end function

function asStr(v as Dynamic) as String
    if v = invalid then return ""
    t = type(v)
    if t = "String" or t = "roString" then return v
    if t = "Integer" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return v.ToStr()
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(v).ToStr()
    if t = "Boolean" or t = "roBoolean" then
        if v then return "1"
        return "0"
    end if
    return ""
end function

' For Xtream-style get.php links, also try the other common formats.
function buildUrlVariants(url as String) as Object
    list = [url]
    if Instr(1, LCase(url), "get.php") = 0 then return list
    typeRe = CreateObject("roRegex", "type=[^&]*", "i")
    outRe = CreateObject("roRegex", "output=[^&]*", "i")
    combos = [["m3u_plus", "m3u8"], ["m3u", "m3u8"], ["m3u_plus", "hls"], ["m3u_plus", "ts"], ["m3u", "ts"]]
    for each c in combos
        v = url
        if typeRe.IsMatch(v) then v = typeRe.Replace(v, "type=" + c[0]) else v = v + "&type=" + c[0]
        if outRe.IsMatch(v) then v = outRe.Replace(v, "output=" + c[1]) else v = v + "&output=" + c[1]
        dup = false
        for each existing in list
            if existing = v then dup = true
        end for
        if not dup then list.Push(v)
    end for
    return list
end function

function fetchText(url as String, ua as String) as Dynamic
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    ' Many IPTV hosts have self-signed or mismatched certificates.
    xfer.EnablePeerVerification(false)
    xfer.EnableHostVerification(false)
    xfer.EnableEncodings(true)
    xfer.RetainBodyOnError(true)
    if ua <> "" then xfer.AddHeader("User-Agent", ua)

    if not xfer.AsyncGetToString() then
        m.top.error = "Could not start the download."
        return invalid
    end if

    msg = wait(90000, port)
    if type(msg) <> "roUrlEvent" then
        xfer.AsyncCancel()
        m.top.error = "Timed out downloading the playlist."
        return invalid
    end if

    code = msg.GetResponseCode()
    if code <> 200 then
        m.top.error = "Server returned " + code.ToStr() + " " + msg.GetFailureReason()
        return invalid
    end if
    return msg.GetString()
end function

function parseM3U(text as String) as Object
    root = CreateObject("roSGNode", "ContentNode")
    groups = {}
    attrRegex = CreateObject("roRegex", "([\w-]+)=""([^""]*)""", "")
    pending = invalid

    for each raw in text.Tokenize(Chr(10) + Chr(13))
        line = raw.Trim()
        if line = "" then
            ' skip blank lines
        else if Left(line, 8) = "#EXTINF:" then
            pending = parseExtInf(line, attrRegex)
        else if Left(line, 8) = "#EXTGRP:" then
            if pending <> invalid then pending.group = Mid(line, 9).Trim()
        else if Left(line, 1) <> "#" then
            if pending = invalid then pending = { title: line, group: "Uncategorized", logo: "" }
            addChannel(root, groups, pending, line)
            pending = invalid
        end if
    end for
    return root
end function

function parseExtInf(line as String, attrRegex as Object) as Object
    info = { title: "", group: "", logo: "", tvgName: "" }
    for each match in attrRegex.MatchAll(line)
        key = LCase(match[1])
        if key = "group-title" then
            info.group = match[2]
        else if key = "tvg-logo" then
            info.logo = match[2]
        else if key = "tvg-name" then
            info.tvgName = match[2]
        end if
    end for

    comma = findTitleComma(line)
    if comma > 0 then info.title = Mid(line, comma + 1).Trim()
    if info.title = "" then info.title = info.tvgName
    if info.title = "" then info.title = "Channel"
    if info.group = "" then info.group = "Uncategorized"
    return info
end function

' The title follows the first comma that is not inside a quoted attribute.
function findTitleComma(line as String) as Integer
    inQuote = false
    for i = 1 to Len(line)
        c = Mid(line, i, 1)
        if c = Chr(34) then
            inQuote = not inQuote
        else if c = "," and not inQuote then
            return i
        end if
    end for
    return 0
end function

sub addChannel(root as Object, groups as Object, info as Object, url as String)
    groupNode = groups[info.group]
    if groupNode = invalid then
        groupNode = root.createChild("ContentNode")
        groupNode.title = info.group
        groups[info.group] = groupNode
    end if
    ch = groupNode.createChild("ContentNode")
    ch.title = info.title
    ch.HDPosterUrl = info.logo
    ' Roku can't play raw MPEG-TS links well; Xtream servers also serve them as HLS.
    if LCase(Right(url, 3)) = ".ts" and Instr(1, url, "/live/") > 0 then
        url = Left(url, Len(url) - 3) + ".m3u8"
    end if
    ch.url = url
    ch.streamFormat = guessFormat(url)
end sub

function guessFormat(url as String) as String
    u = LCase(url)
    q = Instr(1, u, "?")
    if q > 0 then u = Left(u, q - 1)
    ext = Right(u, 4)
    if ext = ".mpd" then return "dash"
    if ext = ".mp4" or ext = ".m4v" or ext = ".mov" then return "mp4"
    if ext = ".mkv" then return "mkv"
    if ext = ".mp3" then return "mp3"
    return "hls"
end function
