' Roku Plus — Netflix-inspired chrome. All coordinates use FHD units.
' Flat dark surfaces, white focus, red accent. Navigation zones and indices are
' unchanged from the previous design so PlusScene.brs key handling still applies.
function nfRed() as string
    return "0xE50914FF"
end function

function panel(x as float, y as float, w as float, h as float, color as string) as object
    node = m.canvas.createChild("Rectangle")
    node.translation = [x,y]
    node.width = w
    node.height = h
    node.color = color
    return node
end function

function words(text as string, x as float, y as float, w as float, h as float, size as integer, color = "0xFFFFFFFF" as string) as object
    node = m.canvas.createChild("Label")
    node.translation = [x,y]
    node.width = w
    node.height = h
    node.color = color
    node.text = text
    font = node.font
    font.size = size
    node.font = font
    return node
end function

function bold(text as string, x as float, y as float, w as float, h as float, size as integer, color = "0xFFFFFFFF" as string) as object
    node = words(text,x,y,w,h,size,color)
    font = CreateObject("roSGNode","Font")
    font.uri = "font:BoldSystemFontFile"
    font.size = size
    node.font = font
    return node
end function

' Old glass PNGs are replaced by flat Netflix-style surfaces.
function flatColor(uri as string) as string
    if type(m.nfFlat) <> "roAssociativeArray"
        p = "pkg:/images/ui/"
        m.nfFlat = {}
        m.nfFlat[p+"pill.png"] = "0x232323FF"
        m.nfFlat[p+"setup-card.png"] = "0x232323FF"
        m.nfFlat[p+"button-dark.png"] = "0x6D6D6E99"
        m.nfFlat[p+"button-white.png"] = "0xFFFFFFFF"
        m.nfFlat[p+"live-preview-base.png"] = "0x0A0A0AFF"
        m.nfFlat[p+"app-background.png"] = "0x141414FF"
        m.nfFlat[p+"hero-shade.png"] = "0x00000000"
        m.nfFlat[p+"hero-mask.png"] = "0x00000000"
        m.nfFlat[p+"card-landscape-mask.png"] = "0x00000000"
        m.nfFlat[p+"card-poster-mask.png"] = "0x00000000"
    end if
    if m.nfFlat.doesExist(uri) then return m.nfFlat[uri]
    return ""
end function

function art(uri as string, x as float, y as float, w as float, h as float, mode = "scaleToFill" as string) as object
    flat = flatColor(uri)
    if flat <> "" then return panel(x,y,w,h,flat)
    poster = m.canvas.createChild("Poster")
    poster.translation = [x,y]
    poster.width = w
    poster.height = h
    poster.loadWidth = int(w)
    poster.loadHeight = int(h)
    poster.loadDisplayMode = mode
    poster.uri = uri
    m.images.push(poster)
    return poster
end function

' Kept for compatibility: the Netflix design has a single look.
function themeAsset(uri as string) as string
    return uri
end function

function glassSurface(name as string, x as float, y as float, w as float, h as float) as object
    color = "0x232323FF"
    if name = "glass-notice" then color = "0x000000E6"
    if name = "glass-row" then color = "0x2A2A2AFF"
    if name = "live-channel-row" then color = "0x1F1F1FFF"
    if name = "live-channel-selected" then color = "0x333333FF"
    if name = "live-logo-badge" then color = "0xE5E5E5FF"
    if name = "live-empty" then color = "0x1F1F1FFF"
    if name = "live-scroll-track" then color = "0x333333FF"
    if name = "live-scroll-thumb" then color = nfRed()
    if name = "glass-tile" or name = "glass-section" or name = "live-preview-frame" or name = "rail-glass" then color = "0x00000000"
    if name = "hero-mask" or name = "card-landscape-mask" or name = "card-poster-mask" then color = "0x00000000"
    node = panel(x,y,w,h,color)
    if name = "live-channel-selected" then panel(x,y,6,h,nfRed())
    if name = "glass-notice" then panel(x,y,6,h,nfRed())
    return node
end function

function outline(parent as object, x as float, y as float, w as float, h as float, t as integer, color as string) as object
    g = parent.createChild("Group")
    g.translation = [x,y]
    sides = [[0,0,w,t],[0,h-t,w,t],[0,0,t,h],[w-t,0,t,h]]
    for each s in sides
        r = g.createChild("Rectangle")
        r.translation = [s[0],s[1]]
        r.width = s[2]
        r.height = s[3]
        r.color = color
    end for
    return g
end function

sub thumbnail(uri as string, x as float, y as float, w as float, h as float, shape = "landscape" as string)
    panel(x,y,w,h,"0x2F2F2FFF")
    if uri <> ""
        if shape = "poster" then art(uri,x,y,w,h,"scaleToFit") else art(uri,x,y,w,h)
    end if
end sub

sub eraseScreen()
    ' Disconnect before clearing URIs: a cached or failed request from the old
    ' render must never change a badge belonging to the new channel page.
    if type(m.liveLogoFallbacks) = "roArray"
        for each entry in m.liveLogoFallbacks
            entry.poster.unobserveField("loadStatus")
        end for
    end if
    m.liveLogoFallbacks = []
    for each image in m.images
        image.uri = ""
    end for
    m.images = []
    m.focusItems = []
    m.canvas.removeChildrenIndex(m.canvas.getChildCount(),0)
    m.canvas.visible = true
    panel(0,0,1920,1080,"0x141414FF")
end sub

' Focus is a white frame (Netflix TV style). shape is accepted for
' compatibility with existing callers but no longer changes the look.
sub focusTarget(zone as string, index as integer, x as integer, y as integer, w as integer, h as integer, shape = "wide" as string, scaleNode = invalid as dynamic)
    edge = outline(m.canvas,x,y,w,h,4,"0xFFFFFFFF")
    edge.visible = false
    m.focusItems.push({zone:zone,index:index,edge:edge,scaleNode:scaleNode})
end sub

' Buttons: gray (or red when primary) at rest, solid white with black text
' when focused.
sub selectable(zone as string, index as integer, text as string, x as integer, y as integer, w as integer, h as integer, primary = false as boolean)
    fill = "0x6D6D6E99"
    if primary then fill = nfRed()
    panel(x,y,w,h,fill)
    label = bold(text,x+12,y,w-24,h,27,"0xFFFFFFFF")
    label.horizAlign = "center"
    label.vertAlign = "center"
    focus = m.canvas.createChild("Group")
    focus.translation = [x,y]
    focus.visible = false
    bg = focus.createChild("Rectangle")
    bg.width = w
    bg.height = h
    bg.color = "0xFFFFFFFF"
    ink = focus.createChild("Label")
    ink.translation = [12,0]
    ink.width = w-24
    ink.height = h
    ink.color = "0x000000FF"
    ink.text = text
    ink.horizAlign = "center"
    ink.vertAlign = "center"
    font = CreateObject("roSGNode","Font")
    font.uri = "font:BoldSystemFontFile"
    font.size = 27
    ink.font = font
    m.focusItems.push({zone:zone,index:index,edge:focus,scaleNode:invalid})
end sub

sub brand(x as integer, y as integer)
    bold("ROKU",x,y,200,46,40,nfRed())
    bold("PLUS",x+2,y+44,200,32,24,"0xFFFFFFFF")
end sub

function countryName() as string
    country = orbitCountryLookup(m.countryCode)
    if country = invalid then return "México"
    return country.name
end function

function modeName() as string
    if m.catalogMode = "hevc" then return "Televisor 4K"
    return "HD / Full HD"
end function

sub topBar()
    panel(0,0,274,1080,"0x000000FF")
    brand(48,58)
    labels = ["Inicio","Películas","Series","TV en vivo","Buscar","Configuración"]
    icons = ["home","movies","series","live","search","settings"]
    active = 0
    if m.view = "browse" or m.view = "detail" or m.view = "episodes"
        active = 1
        if m.kind = "series" then active = 2
    else if m.view = "live"
        active = 3
    else if m.view = "search"
        active = 4
    else if m.view = "settings" or m.view = "credits" or m.view = "hd-source" or m.view = "appearance"
        active = 5
    end if
    for i = 0 to 5
        y = 190 + i * 82
        focused = m.zone = "nav" and m.nav = i
        if focused then panel(30,y,232,65,"0xFFFFFF26")
        if active = i then panel(30,y+12,5,41,nfRed())
        icon = art("pkg:/images/ui/"+icons[i]+".png",52,y+15,34,34)
        if active = i or focused
            bold(labels[i],100,y+16,160,39,24)
        else
            icon.opacity = 0.55
            words(labels[i],100,y+16,160,39,24,"0x8C8C8CFF")
        end if
    end for
    panel(53,918,190,1,"0xFFFFFF22")
    words(modeName(),53,945,202,36,20,"0x8C8C8CFF")
    words(countryName(),53,983,202,55,21,"0x6E6E6EFF").wrap = true
end sub

sub drawScreen()
    if m.view = "player" then return
    eraseScreen()
    if m.view = "setup-tv"
        setupTvScreen()
    else if m.view = "setup-country"
        setupCountryScreen()
    else
        if m.view = "home" then homeScreen()
        if m.view = "browse" then browseScreen()
        if m.view = "detail" then detailScreen()
        if m.view = "episodes" then episodeScreen()
        if m.view = "live" then liveScreen()
        if m.view = "settings" then settingsScreen()
        if m.view = "appearance" then appearanceScreen()
        if m.view = "credits" then creditsScreen()
        if m.view = "hd-source" then hdSourceScreen()
        if m.view = "search" then searchScreen()
        if (m.busy or m.note <> "") and m.view <> "search"
            glassSurface("glass-notice",295,970,1596,100)
            text = m.note
            if m.busy then text = "Consultando el catálogo…"
            if m.busy and type(m.pending) = "roAssociativeArray"
                if m.pending.operation = "country" then text = "Cargando canales de " + countryName() + "…"
            end if
            words(text,325,991,1540,71,24,"0xE5E5E5FF").wrap = true
        end if
    end if
    paintFocus()
end sub

sub setupTvScreen()
    brand(85,60)
    setupHeading = "CONFIGURACIÓN INICIAL · 1 DE 2"
    if m.setupFromSettings then setupHeading = "CONFIGURACIÓN · 1 DE 2"
    bold(setupHeading,87,177,1700,46,23,"0x8C8C8CFF")
    bold("Selecciona tu televisor",82,240,1750,92,62)
    words("Elige la biblioteca que utilizarás. Podrás cambiarla después en Configuración.",87,350,1710,80,29,"0xB3B3B3FF").wrap = true
    names = ["HD / Full HD","4K"]
    tags = ["HD","4K"]
    descriptions = ["Películas y series con selección de fuentes H.264 compatibles.","El catálogo ampliado de películas y series que ya conoces."]
    for i = 0 to 1
        x = 84 + i * 912
        panel(x,466,838,300,"0x232323FF")
        art("pkg:/images/ui/tv.png",x+34,496,72,72)
        bold(tags[i],x+132,492,620,77,60)
        words(names[i],x+38,588,760,54,34)
        words(descriptions[i],x+38,654,760,91,25,"0xB3B3B3FF").wrap = true
        recommended = (i = 0 and m.capabilities.recommendedCatalog = "hd") or (i = 1 and m.capabilities.recommendedCatalog = "hevc")
        if recommended then bold("Recomendado para esta Roku",x+38,785,790,44,24,nfRed())
        focusTarget("setup",i,x-6,460,850,312,"setup")
    end for
    words("La opción 4K describe el equipo. La calidad disponible depende de cada video.",87,881,1730,59,24,"0x808080FF").wrap = true
    words("← / →: elegir     OK: continuar",87,1004,1730,42,24,"0xB3B3B3FF")
end sub

sub setupCountryScreen()
    brand(85,60)
    setupHeading = "CONFIGURACIÓN INICIAL · 2 DE 2"
    if m.setupFromSettings then setupHeading = "CONFIGURACIÓN · 2 DE 2"
    if m.setupCountryOnly then setupHeading = "TU PAÍS O REGIÓN"
    bold(setupHeading,87,177,1700,46,23,"0x8C8C8CFF")
    bold("¿En qué país estás?",82,250,660,173,60).wrap = true
    words("Mostraremos los canales de tu país o región. Puedes cambiarlo cuando quieras.",87,470,620,193,31,"0xB3B3B3FF").wrap = true
    art("pkg:/images/ui/world.png",87,708,98,98)
    countries = orbitCountries()
    first = (m.setupCountry \ 7) * 7
    for i = 0 to 6
        n = first + i
        if n < countries.count()
            y = 268+i*91
            panel(793,y,1035,79,"0x232323FF")
            bold(ucase(countries[n].code),824,y+21,106,42,25,"0x8C8C8CFF")
            words(countries[n].name,950,y+19,839,47,31)
            focusTarget("country",n,786,y-5,1048,89)
        end if
    end for
    words((m.setupCountry+1).toStr()+" de "+countries.count().toStr(),800,936,1000,39,22,"0x8C8C8CFF")
    words("↑ / ↓: elegir     OK: guardar y entrar     Atrás: volver",87,1004,1730,42,24,"0xB3B3B3FF")
end sub

sub homeScreen()
    if m.features.count() > 0
        item = m.features[0]
        heroUri = item.background
        if heroUri = "" then heroUri = item.poster
        if heroUri <> "" then art(heroUri,274,0,1646,650)
        art("pkg:/images/ui/nf-hero-left.png",274,0,1150,650)
        art("pkg:/images/ui/nf-hero-bottom.png",274,330,1646,330)
        bold("DESTACADO",338,66,1470,38,22,nfRed())
        bold(item.title,333,104,1000,160,62).wrap = true
        facts = item.year
        if m.catalogMode = "hd"
            if usesOnlineHd() then facts += " · "+hdProviderName(item.provider) else facts += " · Corto"
        end if
        words(facts,340,272,1440,43,25,"0xD2D2D2FF")
        selectable("hero",0,"Reproducir",337,335,300,70,true)
        selectable("hero",1,"Más información",657,335,320,70)
    else
        bold("Tu próxima historia",335,142,1470,90,57)
        text = "Actualizando las películas y series populares…"
        if not m.homeLoading then text = "Abre Películas o Series para explorar el catálogo."
        words(text,340,252,1470,80,29,"0xB3B3B3FF").wrap = true
        selectable("hero",0,"Actualizar",337,335,317,70,true)
    end if
    rowY = 454
    cardH = 163
    for r = 0 to m.homeRows.count()-1
        row = m.homeRows[r]
        heading = row.heading
        if r = 0 and m.catalogMode = "hd" then heading = "Cortos en HD"
        if r = 0 and m.catalogMode = "hd" and usesOnlineHd() then heading = "Películas para explorar"
        if r = 1 and m.catalogMode = "hd"
            if usesOnlineHd() then heading = "Series por descubrir" else heading = "Documentales en español"
        end if
        bold(heading,318,rowY,1500,47,32)
        drawRow(row,r,rowY+56,cardH)
        rowY += 56 + cardH + 54 + 24
    end for
    searchPill(1660,40)
    topBar()
end sub

' 5 visible 290x163 cards per row (see rpRowAdvance windowSize). The focused
' card zooms 1.08x around its center with a white frame drawn inside the same
' Group so frame and image scale together.
sub drawRow(row as object, rowIndex as integer, y as float, cardH as integer)
    if row.items.count() = 0
        words("Cargando…",318,y,1500,40,25,"0xB3B3B3FF")
        return
    end if
    cardW = 290
    gap = 30
    windowSize = 5
    last = row.offset + windowSize - 1
    if last > row.items.count()-1 then last = row.items.count()-1
    for n = row.offset to last
        item = row.items[n]
        slot = n - row.offset
        x = 318 + slot*(cardW+gap)
        card = m.canvas.createChild("Group")
        card.translation = [x,y]
        card.scaleRotateCenter = [cardW/2,cardH/2]
        bg = card.createChild("Rectangle")
        bg.width = cardW
        bg.height = cardH
        bg.color = "0x2F2F2FFF"
        uri = item.background
        if uri = "" then uri = item.poster
        if uri <> ""
            poster = card.createChild("Poster")
            poster.width = cardW
            poster.height = cardH
            poster.loadWidth = cardW
            poster.loadHeight = cardH
            poster.loadDisplayMode = "scaleToFill"
            poster.uri = uri
            m.images.push(poster)
        end if
        edge = outline(card,-5,-5,cardW+10,cardH+10,4,"0xFFFFFFFF")
        edge.visible = false
        m.focusItems.push({zone:"home-row-"+rowIndex.toStr(),index:n,edge:edge,scaleNode:card})
        words(item.title,x+2,y+cardH+12,cardW-4,40,22,"0xE5E5E5FF")
    end for
end sub

sub browseScreen()
    title = "Películas populares"
    if m.kind = "series" then title = "Series populares"
    if m.catalogMode = "hd"
        if usesOnlineHd()
            title = "Películas · "+hdProviderName()
            if m.kind = "series" then title = "Series · "+hdProviderName()
        else
            title = "Cortos y cine abierto"
            if m.kind = "series" then title = "Documentales en español"
        end if
    end if
    if m.query <> "" then title = "Resultados: " + m.query
    bold(title,317,86,1250,113,48).wrap = true
    hint = "Sigue bajando para explorar más títulos."
    if usesOnlineHd() and m.hdProvider = "all" then hint = "Opciones de varias fuentes. Si una falla, prueba la misma película en otra."
    words(hint,322,206,1185,50,24,"0x8C8C8CFF").wrap = true
    searchPill(1620,96)
    first = (m.cursor \ 6)*6
    for i = 0 to 5
        n = first+i
        if n < m.titles.count()
            item = m.titles[n]
            x = 318+(i mod 3)*516
            y = 277+(i \ 3)*365
            uri = item.background
            if uri = "" then uri = item.poster
            thumbnail(uri,x,y,488,275)
            bold(item.title,x+2,y+287,484,38,25)
            facts = item.year
            if usesOnlineHd() then facts = hdProviderName(item.provider)+" · "+facts
            words(facts,x+2,y+325,484,30,21,"0x8C8C8CFF")
            focusTarget("grid",n,x-6,y-6,500,287,"catalog")
        end if
    end for
    last = first+6
    if last > m.titles.count() then last = m.titles.count()
    if last > 0
        caption = "Títulos "+(m.offset+first+1).toStr()+"–"+(m.offset+last).toStr()
        if usesOnlineHd() and (m.hdProvider = "all" or m.hdProvider = "seriesmetro" or m.hdProvider = "cinecalidad") then caption = "Opciones "+(first+1).toStr()+"–"+last.toStr()+" · Página "+((m.offset\20)+1).toStr()
        words(caption,321,1014,1000,38,22,"0x8C8C8CFF")
    end if
    if m.titles.count() = 0 and not m.busy
        empty = "No se encontraron títulos."
        if m.more then empty = "Sin opciones en esta página. Pulsa ↓ para consultar la siguiente."
        words(empty,341,410,1410,104,32,"0xB3B3B3FF").wrap = true
    end if
    hint = "↓ Más títulos"
    if first+6 >= m.titles.count() and not m.more then hint = "Fin del catálogo"
    words(hint,1330,1014,500,38,22,"0xB3B3B3FF").horizAlign = "right"
    topBar()
end sub

function nfText(item as object, field as string) as string
    if item.doesExist(field)
        if GetInterface(item[field],"ifString") <> invalid then return item[field]
    end if
    return ""
end function

sub detailScreen()
    if m.detail = invalid
        topBar()
        return
    end if
    item = m.detail
    backdrop = nfText(item,"background")
    if backdrop <> ""
        art(backdrop,274,0,1646,1080)
    else if nfText(item,"poster") <> ""
        thumbnail(item.poster,1420,150,400,612,"poster")
    end if
    art("pkg:/images/ui/nf-detail-left.png",274,0,1400,1080)
    art("pkg:/images/ui/nf-detail-bottom.png",274,840,1646,240)
    heading = "PELÍCULA"
    if item.kind = "series" then heading = "SERIE"
    if m.catalogMode = "hd" then heading = "BIBLIOTECA HD"
    if usesOnlineHd() then heading = "BIBLIOTECA HD · "+hdProviderName(item.provider)
    if item.kind = "episode" then heading = m.series.title+" · Episodio "+item.episode.toStr()
    bold(ucase(heading),336,120,1000,40,22,nfRed())
    bold(item.title,330,166,1000,200,62).wrap = true
    facts = item.year
    if item.runtime > 0 then facts = timeText(item.runtime)+" · "+facts
    words(facts,336,380,900,44,26,"0xBCBCBCFF")
    summary = item.description
    if summary = "" then summary = "Consulta la disponibilidad de este título."
    words(left(summary,600),336,440,900,230,27,"0xE5E5E5FF").wrap = true
    title = "Reproducir"
    if item.kind = "series" then title = "Ver episodios"
    selectable("action",0,title,333,699,440,70,true)
    selectable("action",1,"Volver",333,792,440,67)
    if item.doesExist("source") then words("Fuente: "+item.source,336,885,900,60,21,"0x808080FF").wrap = true
    topBar()
end sub

sub episodeScreen()
    topBar()
    if m.series = invalid or m.series.seasons.count() = 0 then return
    season = m.series.seasons[m.season]
    bold(m.series.title,317,90,1520,93,52).wrap = true
    panel(322,205,440,56,"0x2F2F2FFF")
    seasonLabel = bold("←   Temporada "+season.number.toStr()+"   →",322,205,440,56,26)
    seasonLabel.horizAlign = "center"
    seasonLabel.vertAlign = "center"
    first = (m.episode \ 6)*6
    for i = 0 to 5
        n = first+i
        if n < season.episodes.count()
            item = season.episodes[n]
            y = 303+i*96
            ink = "0x1F1F1FFF"
            if n = m.episode then ink = "0x333333FF"
            panel(319,y,1526,80,ink)
            bold(item.episode.toStr(),345,y+16,77,50,36,"0x8C8C8CFF")
            words(item.title,444,y+14,1360,62,28).wrap = true
            focusTarget("episodes",n,313,y-5,1538,90,"live")
        end if
    end for
    if season.episodes.count() > 0
        words("Episodio "+(m.episode+1).toStr()+" de "+season.episodes.count().toStr(),324,922,1480,45,23,"0x8C8C8CFF")
    else if not m.busy
        words("No hay episodios cargados. OK para volver a consultar.",324,386,1480,85,29,"0x8C8C8CFF").wrap = true
    end if
end sub

' Channel badges use source logos as-is, with a real fallback for absent or
' failed images. Live video is never simulated by an image.
sub liveChannelBadge(item as object, x as integer, y as integer)
    glassSurface("live-logo-badge",x,y,106,77)
    initials = "TV"
    if GetInterface(item.title,"ifString") <> invalid
        parts = item.title.trim().split(" ")
        if parts.count() > 1
            initials = ucase(left(parts[0],1)+left(parts[1],1))
        else if parts.count() = 1
            initials = ucase(left(parts[0],2))
        end if
    end if
    badge = words(initials,x+4,y+18,98,45,28,"0x303633FF")
    badge.horizAlign = "center"
    uri = ""
    if GetInterface(item.poster,"ifString") <> invalid then uri = item.poster
    if uri <> ""
        poster = art("",x+7,y+7,92,63,"scaleToFit")
        poster.visible = false
        m.liveLogoFallbacks.push({poster:poster,fallback:badge})
        ' Cached images may become ready as soon as URI is set.
        poster.observeField("loadStatus","liveLogoLoadStatusChanged")
        poster.uri = uri
    end if
end sub

sub liveLogoLoadStatusChanged(event as object)
    if type(m.liveLogoFallbacks) <> "roArray" then return
    poster = event.getRoSGNode()
    for each entry in m.liveLogoFallbacks
        if entry.poster.isSameNode(poster)
            ready = event.getData() = "ready"
            entry.poster.visible = ready
            entry.fallback.visible = not ready
            return
        end if
    end for
end sub

function liveChannelStatus(item as object) as string
    if item.available = false
        if GetInterface(item.availabilityLabel,"ifString") <> invalid then return item.availabilityLabel
        return "Sin señal disponible"
    end if
    return "En vivo"
end function

sub liveScreen()
    topBar()
    query = ""
    if GetInterface(m.liveQuery,"ifString") <> invalid then query = m.liveQuery
    searching = query <> ""
    searchEmpty = searching and m.channels.count() = 0 and not m.busy
    words("TV en vivo",303,62,470,86,50)
    selectable("live-filters",0,"Todos",801,83,194,66,m.liveFilter=0)
    selectable("live-filters",1,countryName(),1011,83,309,66,m.liveFilter=1)
    selectable("live-filters",2,"LATAM",1336,83,209,66,m.liveFilter=2)
    selectable("live-filters",3,"Favoritos",1561,83,321,66,m.liveFilter=3)
    searchWidth = 1008
    searchText = "Buscar canales…"
    if searching
        searchWidth = 792
        displayQuery = query
        if len(displayQuery) > 42 then displayQuery = left(displayQuery,41)+"…"
        searchText = "Buscar: "+displayQuery
    end if
    glassSurface("glass-row",303,150,searchWidth,46)
    art("pkg:/images/ui/search.png",322,160,26,26)
    words(searchText,365,160,searchWidth-80,29,22,"0xE8EEE3FF")
    focusTarget("live-search",0,299,146,searchWidth+8,54,"live-search")
    if searching
        art("pkg:/images/ui/button-dark.png",1111,150,200,46)
        words("Borrar",1121,160,180,29,22,"0xE8EEE3FF").horizAlign = "center"
        focusTarget("live-search",1,1107,146,208,54)
    end if
    listHeading = "CANALES"
    if searching then listHeading = "RESULTADOS"
    words(listHeading,1352,169,220,31,20,"0xC7CFC9FF")

    ' The real decoder occupies exactly [294,206,1016,572] above the canvas.
    ' The rim remains outside that rectangle, including on square-video devices.
    glassSurface("live-preview-frame",285,197,1034,590)
    panel(294,206,1016,572,"0x141A19FF")
    art("pkg:/images/ui/live-preview-base.png",294,206,1016,572)
    art("pkg:/images/ui/live.png",754,414,96,96)
    placeholder = "Elige un canal para comenzar"
    if type(m.livePreviewItem) = "roAssociativeArray"
        placeholder = "Preparando la señal…"
        if GetInterface(m.livePreviewStatus,"ifString") <> invalid
            if m.livePreviewStatus <> "" then placeholder = m.livePreviewStatus
        end if
    end if
    if searchEmpty then placeholder = "No se encontraron canales"
    words(placeholder,390,534,824,78,28,"0xC6CEC7FF").horizAlign = "center"
    art("pkg:/images/ui/live-preview-mask.png",294,206,1016,572)

    current = invalid
    if m.channels.count() > 0 and type(m.livePreviewItem) = "roAssociativeArray" then current = m.livePreviewItem
    if current = invalid and m.liveCursor >= 0 and m.liveCursor < m.channels.count() then current = m.channels[m.liveCursor]
    if type(current) = "roAssociativeArray"
        words(current.title,303,806,626,102,39).wrap = true
        subtitle = "Canal en vivo"
        if GetInterface(current.subtitle,"ifString") <> invalid
            if current.subtitle <> "" then subtitle = current.subtitle
        end if
        words(subtitle,307,915,622,38,24,"0xD6DCD5FF")
        status = liveChannelStatus(current)
        if type(m.livePreviewItem) = "roAssociativeArray" and current.available <> false
            if GetInterface(m.livePreviewStatus,"ifString") <> invalid
                if m.livePreviewStatus <> "" then status = m.livePreviewStatus
            end if
        end if
        words(status,307,960,622,38,22,"0xB4C3B9FF")
        selectable("live-actions",0,"Pantalla completa",952,811,358,66)
        favoriteText = "Añadir a favoritos"
        if rpLiveIsFavorite(current,m.liveFavorites) then favoriteText = "Quitar de favoritos"
        selectable("live-actions",1,favoriteText,952,892,358,66)
    else
        emptyTitle = "Tu televisión, a tu manera"
        empty = "Selecciona un filtro para explorar sus canales."
        if m.liveFilter = 3 then empty = "Guarda tus canales con * para encontrarlos aquí."
        if searchEmpty
            emptyTitle = "Sin resultados"
            empty = "No hay canales que coincidan. Cambia o borra tu búsqueda."
        end if
        words(emptyTitle,303,813,1005,75,37)
        words(empty,307,906,1000,85,25,"0xC6CEC7FF").wrap = true
    end if

    first = (m.liveCursor \ 6)*6
    last = first+6
    if last > m.channels.count() then last = m.channels.count()
    if last > 0 then words((first+1).toStr()+"–"+last.toStr()+" de "+m.channels.count().toStr(),1585,169,287,31,20,"0xC7CFC9FF").horizAlign = "right"
    if last = 0 and searching then words("0 resultados",1585,169,287,31,20,"0xC7CFC9FF").horizAlign = "right"
    for i = 0 to 5
        n = first+i
        if n < m.channels.count()
            item = m.channels[n]
            y = 206+i*119
            surface = "live-channel-row"
            if n = m.liveCursor then surface = "live-channel-selected"
            glassSurface(surface,1342,y,540,111)
            liveChannelBadge(item,1359,y+17)
            ink = "0xF6F7F2FF"
            if item.available = false then ink = "0xBCC5BDFF"
            words(item.title,1483,y+12,343,64,25,ink).wrap = true
            status = liveChannelStatus(item)
            dot = "live-status-on"
            if item.available = false then dot = "live-status-off"
            art("pkg:/images/ui/"+dot+".png",1483,y+79,12,12)
            words(status,1504,y+79,328,27,19,"0xCCD5CCFF")
            star = "live-star-outline"
            if rpLiveIsFavorite(item,m.liveFavorites) then star = "live-star-filled"
            art("pkg:/images/ui/"+star+".png",1842,y+16,25,25)
            focusTarget("live",n,1336,y-6,552,123,"live-channel")
        end if
    end for
    if m.channels.count() > 6
        glassSurface("live-scroll-track",1892,213,8,694)
        pages = int((m.channels.count()+5)/6)
        thumb = int(694/pages)
        if thumb < 38 then thumb = 38
        page = first/6
        sy = 213+int((694-thumb)*page/(pages-1))
        glassSurface("live-scroll-thumb",1892,sy,8,thumb)
    end if
    if m.channels.count() = 0
        empty = "No hay canales disponibles."
        if m.busy then empty = "Cargando canales…"
        if m.liveFilter = 3 then empty = "Tus favoritos aparecerán aquí."
        if searchEmpty then empty = "No hay canales que coincidan. Cambia o borra tu búsqueda."
        glassSurface("live-empty",1342,206,540,235)
        words(empty,1380,278,464,109,29,"0xDCE1D9FF").wrap = true
    end if
    words(rpLivePopularityNote(),1351,944,525,66,18,"0xACB9AAFF").wrap = true
    words("↑ ↓  Cambiar canal     OK  Pantalla completa     *  Favorito",305,1025,1035,36,21,"0xDCE1D9FF")
    words("Atrás  Volver",1560,1025,316,36,21,"0xDCE1D9FF").horizAlign = "right"
end sub

sub settingsScreen()
    topBar()
    bold("Configuración",317,102,1500,87,53)
    words("Puedes corregir tus elecciones cuando quieras.",322,210,1480,65,28,"0x8C8C8CFF")
    labels = ["Tu televisor","País o región","Catálogo HD","Créditos de cortos y documentales"]
    values = [modeName(),countryName(),hdProviderName(),"Ver fuentes y licencias"]
    for i = 0 to 3
        y = 299+i*122
        panel(321,y,1518,106,"0x232323FF")
        bold(labels[i],352,y+15,1150,43,30)
        words(values[i],354,y+65,1250,33,23,"0x8C8C8CFF")
        focusTarget("settings",i,315,y-5,1530,116)
    end for
    words("Las preferencias se guardan en esta Roku.",323,959,1480,60,23,"0x808080FF")
end sub

sub appearanceScreen()
    topBar()
    words("Apariencia",317,102,1500,87,53)
    words("Elige cómo quieres ver Roku Plus.",322,218,1480,65,28,"0xCED8CEFF")
    names = ["Vidrio","Clásico"]
    descriptions = ["Superficies translúcidas, reflejos suaves y tonos naturales.","Paneles oscuros y un contraste más marcado."]
    for i = 0 to 1
        x = 321+i*780
        glassSurface("setup-card",x,326,744,456)
        preview = "appearance-glass-preview"
        if i = 1 then preview = "appearance-classic-preview"
        art("pkg:/images/ui/"+preview+".png",x+26,354,692,235)
        words(names[i],x+30,615,640,60,39)
        words(descriptions[i],x+32,695,672,67,25,"0xD1DACFFF").wrap = true
        current = (i = 0 and m.theme <> "classic") or (i = 1 and m.theme = "classic")
        if current then words("Actual",x+555,627,145,36,22,"0xF4EDC8FF").horizAlign = "right"
        focusTarget("appearance",i,x-6,320,756,468,"appearance")
    end for
    words("← / →  Elegir     OK  Aplicar     Atrás  Volver",323,945,1480,54,25,"0xDCE3D7FF")
end sub

sub hdSourceScreen()
    topBar()
    words("Catálogo HD",317,102,1500,87,53)
    words("Elige la biblioteca que se utilizará en el modo HD / Full HD.",322,217,1480,80,29,"0xADADB9FF").wrap = true
    choices = hdProviderChoices()
    first = 0
    if m.hdSourceCursor >= 6 then first = m.hdSourceCursor-5
    for i = 0 to 5
        n = first+i
        if n < choices.count()
        name = hdProviderName(choices[n])
        description = "Películas y series · alternativas en español"
        if choices[n] = "all" then description = "Una búsqueda, varias opciones de la misma película o serie"
        if choices[n] = "lamovie" then description = "Películas y series · prioridad español latino"
        if choices[n] = "allcalidad" then description = "Películas y series · latino y dual"
        if choices[n] = "seriesmetro" then description = "Películas y series · servidores alternativos Fastream"
        if choices[n] = "cinecalidad" then description = "Películas en español latino · sin sección de series"
        if choices[n] = "open" then description = "Biblioteca pequeña de Blender y NASA"
        y = 300+i*106
        art("pkg:/images/ui/pill.png",321,y,1518,98)
        words(name,352,y+10,1350,41,29)
        words(description,354,y+56,1350,32,22,"0xAAAAB6FF")
        focusTarget("hd-source",n,315,y-5,1530,108)
        end if
    end for
    words("Las fuentes y los títulos disponibles pueden cambiar. Se comprueba el formato antes de reproducir.",323,957,1480,85,22,"0x92929EFF").wrap = true
end sub

sub creditsScreen()
    topBar()
    words("Créditos de la biblioteca HD",317,102,1500,87,48)
    words(m.creditsPages[m.creditsPage],323,245,1490,710,25,"0xBDBDC8FF").wrap = true
    words("Página "+(m.creditsPage+1).toStr()+" / "+m.creditsPages.count().toStr()+" · ↑/↓: cambiar · Atrás: volver",323,1002,1500,46,22,"0x8F8F9DFF")
end sub

sub paintFocus()
    for each entry in m.focusItems
        chosen = false
        if entry.zone = m.zone
            if m.zone = "hero" then chosen = entry.index = m.hero
            if left(m.zone,9) = "home-row-" then chosen = entry.index = m.homeRows[val(mid(m.zone,10),10)].cursor
            if m.zone = "grid" then chosen = entry.index = m.cursor
            if m.zone = "action" then chosen = entry.index = m.action
            if m.zone = "episodes" then chosen = entry.index = m.episode
            if m.zone = "live" then chosen = entry.index = m.liveCursor
            if m.zone = "live-filters" then chosen = entry.index = m.liveFilterCursor
            if m.zone = "live-search" then chosen = entry.index = m.liveSearchCursor
            if m.zone = "live-actions" then chosen = entry.index = m.liveAction
            if m.zone = "settings" then chosen = entry.index = m.settingsCursor
            if m.zone = "appearance" then chosen = entry.index = m.themeCursor
            if m.zone = "hd-source" then chosen = entry.index = m.hdSourceCursor
            if m.zone = "setup" then chosen = entry.index = m.setupTv
            if m.zone = "country" then chosen = entry.index = m.setupCountry
            if m.zone = "search-btn" then chosen = true
            if m.zone = "kbd" then chosen = entry.index = m.kbd
            if m.zone = "search-results" then chosen = entry.index = m.cursor
            if m.zone = "search-kind" then chosen = entry.index = m.searchKindCursor
        end if
        entry.edge.visible = chosen
        if entry.scaleNode <> invalid
            if chosen then entry.scaleNode.scale = [1.08,1.08] else entry.scaleNode.scale = [1.0,1.0]
        end if
    end for
end sub

' "Buscar" pill used on Home, Películas and Series (zone "search-btn").
sub searchPill(x as integer, y as integer)
    selectable("search-btn",0,"      Buscar",x,y,220,60)
    art("pkg:/images/ui/search.png",x+34,y+15,30,30)
    entry = m.focusItems[m.focusItems.count()-1]
    icon = entry.edge.createChild("Poster")
    icon.translation = [34,15]
    icon.width = 30
    icon.height = 30
    icon.blendColor = "0x000000FF"
    icon.uri = "pkg:/images/ui/search.png"
    m.images.push(icon)
end sub

sub searchScreen()
    x0 = 318
    query = m.searchText
    art("pkg:/images/ui/search.png",x0+8,104,36,36)
    if query = ""
        words("Buscar títulos…",x0+60,100,456,44,30,"0x808080FF")
    else
        bold(query,x0+60,100,456,44,30)
    end if
    panel(x0,160,515,3,"0xFFFFFFFF")
    keys = rpKbdKeys()
    selectable("kbd",0,"Espacio",x0,196,254,64)
    selectable("kbd",1,"Borrar",x0+261,196,254,64)
    for k = 2 to 37
        row = (k-2)\6 + 1
        col = (k-2) mod 6
        selectable("kbd",k,ucase(keys[k]),x0+col*87,196+row*71,80,64)
    end for
    words("OK  Escribir     Atrás  Salir",x0,722,515,34,20,"0x8C8C8CFF")

    rx = 880
    selectable("search-kind",0,"Películas",rx,96,220,60,m.searchKind = "movie")
    selectable("search-kind",1,"Series",rx+236,96,200,60,m.searchKind = "series")
    heading = "Populares"
    if m.kind = "series" then heading = "Series populares" else heading = "Películas populares"
    if query.trim() <> "" then heading = "Resultados para «"+query.trim()+"»"
    bold(heading,rx,180,820,44,30)
    status = ""
    if m.busy then status = "Buscando…"
    if not m.busy and m.note <> "" then status = m.note
    if status <> "" then words(status,1500,186,380,38,22,"0x8C8C8CFF").horizAlign = "right"

    n = m.titles.count()
    first = (m.cursor \ 9)*9
    for i = 0 to 8
        idx = first+i
        if idx < n
            item = m.titles[idx]
            x = rx+(i mod 3)*344
            y = 244+(i \ 3)*232
            uri = item.background
            if uri = "" then uri = item.poster
            thumbnail(uri,x,y,320,180)
            words(item.title,x+2,y+190,316,34,22,"0xE5E5E5FF")
            focusTarget("search-results",idx,x-6,y-6,332,192)
        end if
    end for
    if n = 0 and not m.busy
        empty = "Escribe con el teclado para buscar."
        if query.trim() <> "" then empty = "No encontramos resultados para «"+query.trim()+"». Prueba con otro título o cambia a "+iif(m.searchKind = "series","Películas","Series")+"."
        words(empty,rx,260,1000,110,28,"0xB3B3B3FF").wrap = true
    end if
    lastShown = first+9
    if lastShown > n then lastShown = n
    if n > 9 then words("Resultados "+(first+1).toStr()+"–"+lastShown.toStr()+" de "+n.toStr(),rx,960,1000,34,21,"0x8C8C8CFF")
    topBar()
end sub

function iif(condition as boolean, a as dynamic, b as dynamic) as dynamic
    if condition then return a
    return b
end function
