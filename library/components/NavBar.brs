sub init()
    m.tabs = m.top.findNode("tabs")
    m.tabW = 200
    m.pills = []
    m.labels = []
    m.fontOn = makeFont(28, true)
    m.fontOff = makeFont(28, false)
end sub

sub build()
    m.tabs.removeChildrenIndex(m.tabs.getChildCount(), 0)
    m.pills = []
    m.labels = []
    items = m.top.items
    startX = Int((1920 - m.tabW * items.Count()) / 2)
    for i = 0 to items.Count() - 1
        g = m.tabs.createChild("Group")
        g.translation = [startX + i * m.tabW, 0]
        pill = g.createChild("Poster")
        pill.uri = "libpkg:/images/pill.9.png"
        pill.width = m.tabW - 24
        pill.height = 54
        pill.translation = [12, 0]
        lbl = g.createChild("Label")
        lbl.width = m.tabW
        lbl.height = 54
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        lbl.text = items[i]
        m.pills.Push(pill)
        m.labels.Push(lbl)
    end for
    refresh()
end sub

sub refresh()
    sel = m.top.selectedIndex
    active = m.top.active
    for i = 0 to m.labels.Count() - 1
        pill = m.pills[i]
        lbl = m.labels[i]
        if i = sel then
            lbl.font = m.fontOn
            if active then
                pill.visible = true
                pill.opacity = 1.0
                lbl.color = "0x0E1116FF"
            else
                pill.visible = true
                pill.opacity = 0.18
                lbl.color = "0xFFFFFFFF"
            end if
        else
            pill.visible = false
            lbl.font = m.fontOff
            lbl.color = "0x8D97A3FF"
        end if
    end for
end sub
