' Netflix-style search: on-screen keyboard on the left, live results on the
' right. Results reuse the catalog request (m.query / m.titles) so every
' catalog mode (Cinemeta, online HD, offline HD) keeps working.
'
' Keyboard indices: 0 = Espacio, 1 = Borrar (top row, 3 columns each),
' 2..37 = a-z then 1-9, 0 in a 6-column grid (rows 1..6).
function rpKbdKeys() as object
    keys = ["Espacio","Borrar"]
    for each c in "abcdefghijklmnopqrstuvwxyz1234567890".split("")
        keys.push(c)
    end for
    return keys
end function

sub openSearch()
    cancelRequest()
    stopLivePreview()
    if m.searchTimer = invalid
        m.searchTimer = m.top.findNode("searchDelay")
        m.searchTimer.observeField("fire","runSearch")
    end if
    origin = "home"
    if m.view = "browse" or m.view = "detail" or m.view = "episodes" then origin = m.kind
    if m.view = "search" then origin = m.searchOrigin
    m.searchOrigin = origin
    m.searchKind = "movie"
    if origin = "series" then m.searchKind = "series"
    m.searchKindCursor = 0
    if m.searchKind = "series" then m.searchKindCursor = 1
    m.view = "search"
    m.nav = 4
    m.zone = "kbd"
    m.note = ""
    m.titles = []
    m.cursor = 0
    runSearch()
    m.top.setFocus(true)
end sub

sub queueSearch()
    if m.searchTimer = invalid then return
    m.searchTimer.control = "stop"
    m.searchTimer.control = "start"
end sub

sub runSearch()
    if m.view <> "search" then return
    m.query = m.searchText.trim()
    m.kind = m.searchKind
    m.cursor = 0
    m.note = ""
    loadBrowsePage(0)
end sub

sub leaveSearch()
    if m.searchTimer <> invalid then m.searchTimer.control = "stop"
    cancelRequest()
    if m.searchOrigin = "movie" or m.searchOrigin = "series"
        openCatalog(m.searchOrigin)
    else
        goHome()
    end if
end sub

' The "Buscar" pill shown on Home, Películas and Series.
function searchButtonKey(key as string) as boolean
    if key = "OK" then openSearch(): return true
    if key = "left" then m.zone = "nav"
    if key = "down"
        if m.view = "home" then m.zone = "hero"
        if m.view = "browse" and m.titles.count() > 0 then m.zone = "grid"
    end if
    drawScreen()
    return true
end function

function searchKey(key as string) as boolean
    if m.zone = "kbd"
        k = m.kbd
        if k <= 1
            row = 0
            col = k*3
        else
            row = (k-2)\6 + 1
            col = (k-2) mod 6
        end if
        if key = "left"
            if row = 0 and k = 1
                m.kbd = 0
            else if row > 0 and col > 0
                m.kbd = k-1
            else
                m.zone = "nav"
            end if
        else if key = "right"
            if row = 0 and k = 0
                m.kbd = 1
            else if (row = 0 and k = 1) or col = 5
                if m.titles.count() > 0
                    m.zone = "search-results"
                    if m.cursor >= m.titles.count() then m.cursor = 0
                else
                    m.zone = "search-kind"
                end if
            else
                m.kbd = k+1
            end if
        else if key = "up"
            if row = 0
                m.zone = "search-kind"
            else if row = 1
                if col < 3 then m.kbd = 0 else m.kbd = 1
            else
                m.kbd = k-6
            end if
        else if key = "down"
            if row = 0
                if k = 0 then m.kbd = 2 else m.kbd = 5
            else if k+6 <= 37
                m.kbd = k+6
            end if
        else if key = "OK"
            keys = rpKbdKeys()
            if k = 0
                if len(m.searchText) > 0 and len(m.searchText) < 60 then m.searchText += " "
            else if k = 1
                if len(m.searchText) > 0 then m.searchText = left(m.searchText,len(m.searchText)-1)
            else if len(m.searchText) < 60
                m.searchText += keys[k]
            end if
            queueSearch()
        else if key = "replay"
            if len(m.searchText) > 0 then m.searchText = left(m.searchText,len(m.searchText)-1): queueSearch()
        end if
        drawScreen()
        return true
    end if
    if m.zone = "search-results"
        n = m.titles.count()
        if n = 0 then m.zone = "kbd": drawScreen(): return true
        col = m.cursor mod 3
        page = m.cursor \ 9
        if key = "left"
            if col > 0 then m.cursor-- else m.zone = "kbd"
        else if key = "right"
            if col < 2 and m.cursor+1 < n then m.cursor++
        else if key = "up"
            if m.cursor >= 3 then m.cursor -= 3 else m.zone = "search-kind"
        else if key = "down"
            if ((m.cursor \ 3)+1)*3 < n
                m.cursor += 3
                if m.cursor >= n then m.cursor = n-1
            end if
        else if key = "OK"
            openDetails(m.titles[m.cursor],"search")
            return true
        end if
        if page <> m.cursor \ 9 then drawScreen(): return true
        if m.zone <> "search-results" then drawScreen(): return true
        paintFocus()
        return true
    end if
    if m.zone = "search-kind"
        if key = "left"
            if m.searchKindCursor = 1 then m.searchKindCursor = 0 else m.zone = "kbd"
        else if key = "right"
            m.searchKindCursor = 1
        else if key = "down"
            if m.titles.count() > 0
                m.zone = "search-results"
                m.cursor = 0
            else
                m.zone = "kbd"
            end if
        else if key = "OK"
            kind = "movie"
            if m.searchKindCursor = 1 then kind = "series"
            if kind <> m.searchKind
                m.searchKind = kind
                m.titles = []
                runSearch()
                return true
            end if
        end if
        drawScreen()
        return true
    end if
    m.zone = "kbd"
    drawScreen()
    return true
end function
