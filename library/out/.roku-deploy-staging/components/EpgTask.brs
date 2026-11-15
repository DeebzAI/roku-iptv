' Fetches "now / next" for one channel from the Xtream player API.

sub init()
    m.top.functionName = "loadEpg"
end sub

sub loadEpg()
    c = m.top.xtream
    sid = m.top.streamId
    out = { streamId: sid, items: [] }
    if c = invalid or sid = "" then
        m.top.result = out
        return
    end if

    url = c.base + "/player_api.php?username=" + c.user + "&password=" + c.pass + "&action=get_short_epg&stream_id=" + sid + "&limit=4"
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if m.top.userAgent <> invalid and m.top.userAgent <> "" then xfer.AddHeader("User-Agent", m.top.userAgent)
    if xfer.AsyncGetToString() then
        msg = wait(15000, port)
        if type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200 then
            data = ParseJson(msg.GetString())
            if data <> invalid and type(data.epg_listings) = "roArray" then
                now = CreateObject("roDateTime").AsSeconds()
                for each e in data.epg_listings
                    startTs = toInt(e.start_timestamp)
                    stopTs = toInt(e.stop_timestamp)
                    if stopTs > now then
                        out.items.Push({ title: decode64(e.title), desc: decode64(e.description), start: startTs, stop: stopTs })
                    end if
                end for
            end if
        else
            xfer.AsyncCancel()
        end if
    end if
    m.top.result = out
end sub

function decode64(v as Dynamic) as String
    if v = invalid then return ""
    s = v
    if type(s) <> "String" and type(s) <> "roString" then return ""
    ba = CreateObject("roByteArray")
    ba.FromBase64String(s)
    txt = ba.ToAsciiString()
    if txt = "" then return s
    return txt
end function

function toInt(v as Dynamic) as Integer
    if v = invalid then return 0
    t = type(v)
    if t = "String" or t = "roString" then return v.ToInt()
    if t = "Integer" or t = "roInteger" then return v
    if t = "LongInteger" or t = "roLongInteger" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(v)
    return 0
end function
