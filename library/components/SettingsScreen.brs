' Settings: a few maintenance actions plus version info.

sub init()
    m.list = m.top.findNode("list")
    m.msg = m.top.findNode("msg")
    m.top.findNode("heading").font = makeFont(44, true)
    m.top.findNode("info").font = makeFont(28, false)
    m.msg.font = makeFont(30, true)
    m.list.font = makeFont(32, false)
    root = CreateObject("roSGNode", "ContentNode")
    for each t in ["Clear cache", "Change IPTV login", "Clear Continue Watching", "Clear Your Channels"]
        root.createChild("ContentNode").title = t
    end for
    m.list.content = root
    m.list.observeField("itemSelected", "onPick")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

sub startLoading()
    user = ""
    if m.top.xtream <> invalid then user = asStr(m.top.xtream.user)
    m.top.findNode("info").text = "Version " + m.top.version + Chr(10) + "Signed in as " + user + Chr(10) + Chr(10) + "Keys while watching live TV:" + Chr(10) + "  OK  channel strip" + Chr(10) + "  Up / Down  change channel" + Chr(10) + "  Left or Replay  previous channel" + Chr(10) + "  *  add to Your Channels"
end sub

sub onPick()
    i = m.list.itemSelected
    if i = 1 then
        m.top.action = "login"
        return
    end if
    m.pending = i
    texts = ["Clear the saved lineup? It rebuilds the next time you open the app.", "", "Clear everything in Continue Watching?", "Remove all channels from Your Channels?"]
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "Are you sure?"
    dlg.message = [texts[i]]
    dlg.buttons = ["Yes", "Cancel"]
    dlg.observeField("buttonSelected", "onConfirm")
    m.top.getScene().dialog = dlg
end sub

sub onConfirm()
    dlg = m.top.getScene().dialog
    pressed = dlg.buttonSelected
    dlg.close = true
    m.list.setFocus(true)
    if pressed <> 0 then return
    runAction(m.pending)
end sub

sub runAction(i as Integer)
    sec = CreateObject("roRegistrySection", "IPTVPlayer")
    if i = 0 then
        fs = CreateObject("roFileSystem")
        files = fs.ListDir("cachefs:/")
        if files <> invalid then
            for each f in files
                if Left(f, 5) = "cats_" then fs.Delete("cachefs:/" + f)
            end for
        end if
        m.msg.text = "Cache cleared. Close and reopen the app to rebuild the lineup."
    else if i = 2 then
        sec.Delete("resume")
        sec.Flush()
        m.msg.text = "Continue Watching cleared"
        m.top.action = "continue"
    else if i = 3 then
        sec.Delete("favs")
        sec.Flush()
        m.msg.text = "Your Channels cleared"
        m.top.action = "favs"
    end if
end sub
