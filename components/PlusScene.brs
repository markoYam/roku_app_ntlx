' Roku Plus: original personal television application.
sub init()
    m.top.backgroundColor = "0x09090BFF"
    m.top.focusable = true
    m.canvas = m.top.findNode("canvas")
    m.player = m.top.findNode("player")
    m.deadline = m.top.findNode("catalogDeadline")
    m.deadline.observeField("fire","catalogTimedOut")
    m.player.observeField("closed","playerClosed")
    m.player.observeField("diagnostics","playerDiagnostic")
    m.player.observeField("retryRequested","retryVideo")
    m.player.observeField("progress","livePreviewProgress")
    m.player.observeField("previewReturned","livePreviewReturned")
    m.player.observeField("closedRequest","livePreviewClosed")
    m.previewTimer = m.top.findNode("livePreviewDelay")
    m.previewTimer.observeField("fire","startLivePreview")
    m.noteTimer = m.top.findNode("liveNoticeTimer")
    m.noteTimer.observeField("fire","liveNoticeElapsed")
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.hero = 0
    m.homeRows = rpHomeRowsBuild([], [])
    m.rowFocus = 0
    m.images = []
    m.focusItems = []
    m.kind = "movie"
    m.query = ""
    m.offset = 0
    m.nextOffset = 0
    m.more = false
    m.titles = []
    m.channels = []
    m.countryChannels = []
    m.liveLoadedCountry = ""
    m.liveFilter = 0
    m.liveFilterCursor = 0
    m.liveFavorites = rpLiveLoadFavorites()
    m.latamChannels = []
    m.latamLoaded = false
    m.livePreviewOpen = false
    m.livePreviewItem = invalid
    m.livePreviewStatus = "Selecciona un canal"
    m.livePreviewKey = ""
    m.livePreviewRequestTag = ""
    m.liveRequestSequence = 0
    m.liveFullscreen = false
    m.liveAction = 0
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.cursor = 0
    m.liveCursor = 0
    m.season = 0
    m.episode = 0
    m.detail = invalid
    m.series = invalid
    m.detailOrigin = "home"
    m.autoplay = false
    m.busy = false
    m.job = invalid
    m.request = ""
    m.pending = invalid
    m.dialogBox = invalid
    m.note = ""
    m.action = 0
    m.playbackMode = "direct"
    m.capabilities = rpDeviceProfile()
    prefs = rpLoadPreferences(m.capabilities.recommendedCatalog)
    m.configured = prefs.configured
    m.catalogMode = prefs.mode
    m.countryCode = prefs.countryCode
    m.hdProvider = rpLoadHdProvider()
    m.theme = rpLoadTheme()
    m.themeCursor = 0
    m.hdSourceCursor = 0
    m.hdLibrary = rpHdLibrary()
    m.features = []
    m.homeSeries = []
    m.homeJobs = []
    m.homeLoading = false
    m.settingsCursor = 0
    m.creditsPage = 0
    m.creditsPages = []
    if not m.configured
        beginSetup(false,false)
    else
        refreshHome()
    end if
    drawScreen()
    m.top.setFocus(true)
end sub

function timeText(seconds as integer) as string
    if seconds <= 0 then return ""
    minutes = seconds \ 60
    if minutes < 60 then return minutes.toStr() + " min"
    return (minutes \ 60).toStr() + " h " + (minutes mod 60).toStr() + " min"
end function

sub cancelRequest()
    m.deadline.control = "stop"
    if m.job <> invalid
        m.job.unobserveField("result")
        m.job.unobserveField("state")
        m.job.cancelRequested = true
    end if
    m.job = invalid
    m.request = ""
    m.pending = invalid
    m.busy = false
end sub

sub fetch(context as object)
    cancelRequest()
    m.pending = context
    m.request = CreateObject("roDeviceInfo").getRandomUUID()
    online = usesOnlineHd() and context.operation <> "country" and context.operation <> "latam"
    taskName = "CatalogTask"
    if online then taskName = "HdCatalogTask"
    task = CreateObject("roSGNode",taskName)
    if online then task.provider = m.hdProvider
    if online and context.operation = "resolve" then task.attempt = orbitInteger(context.item.hdAttempt,99)
    task.operation = context.operation
    task.kind = m.kind
    if context.doesExist("kind") then task.kind = context.kind
    if context.operation = "country" then task.countryCode = m.countryCode
    task.requestId = m.request
    task.query = m.query
    if context.operation = "catalog" then task.skip = context.offset
    if context.doesExist("item")
        if online then task.item = context.item else task.imdbId = context.item.imdbId
        if context.item.kind = "episode"
            task.kind = "series"
            task.season = context.item.season
            if not online then task.episode = context.item.episode
        else
            task.kind = context.item.kind
        end if
    end if
    if online and context.doesExist("season") then task.season = context.season
    task.observeField("result","fetched")
    task.observeField("state","catalogState")
    m.job = task
    m.busy = true
    m.deadline.duration = 25
    m.deadlineMs = 25000
    if online
        m.deadline.duration = 45
        m.deadlineMs = 45000
    end if
    m.deadlineStart = CreateObject("roTimespan")
    m.deadlineStart.mark()
    m.note = ""
    drawScreen()
    m.deadline.control = "start"
    task.control = "RUN"
end sub

sub catalogTimedOut()
    if not m.busy then return
    if m.deadlineStart <> invalid
        if m.deadlineStart.totalMilliseconds() < m.deadlineMs - 100 then return
    end if
    cancelRequest()
    m.autoplay = false
    m.note = "La consulta tardó demasiado. Pulsa OK para intentar de nuevo o Atrás para volver."
    drawScreen()
end sub

sub catalogState(event as object)
    if m.job = invalid then return
    if not m.job.isSameNode(event.getRoSGNode()) then return
    if event.getData() <> "STOP" then return
    if type(m.job.result) = "roAssociativeArray" then return
    cancelRequest()
    m.autoplay = false
    m.note = "No se pudo completar la consulta. Vuelve a intentar."
    drawScreen()
end sub

sub fetched(event as object)
    if m.job = invalid then return
    if not m.job.isSameNode(event.getRoSGNode()) then return
    answer = event.getData()
    if type(answer) <> "roAssociativeArray" then return
    if answer.requestId <> m.request then return
    context = m.pending
    cancelRequest()
    if not answer.ok
        m.autoplay = false
        m.note = answer.message
        drawScreen()
        return
    end if
    if context.operation = "catalog"
        if answer.items.count() = 0 and context.offset > 0 and not answer.hasMore
            m.more = false
            m.note = "Llegaste al final de los resultados."
        else
            m.titles = answer.items
            m.offset = context.offset
            m.nextOffset = answer.nextSkip
            m.more = answer.hasMore
            m.cursor = 0
            if context.doesExist("last") and context.last then m.cursor = m.titles.count()-1
            if m.cursor < 0 then m.cursor = 0
        end if
        m.zone = "grid"
        if answer.partial = true then m.note = "Una fuente no respondió. Se muestran las opciones disponibles."
    else if context.operation = "meta"
        m.detail = answer.item
        if m.autoplay
            m.autoplay = false
            playDetail()
            return
        end if
    else if context.operation = "resolve"
        if type(answer.mediaHeaders) = "roAssociativeArray" then m.detail.mediaHeaders = answer.mediaHeaders
        m.detail.hdAttempt = orbitInteger(answer.attemptUsed,99)
        launchVideo(m.detail,answer.url,answer.streamFormat)
        return
    else if context.operation = "episodes"
        if m.series = invalid or context.item.id <> m.series.id then return
        for each incoming in answer.seasons
            for i = 0 to m.series.seasons.count()-1
                if m.series.seasons[i].number = incoming.number then m.series.seasons[i] = incoming
            end for
        end for
        m.episode = 0
    else if context.operation = "country" or context.operation = "latam"
        if context.operation = "country"
            if answer.countryCode <> m.countryCode then return
            m.countryChannels = answer.items
            m.liveLoadedCountry = answer.countryCode
        else
            m.latamChannels = answer.items
            m.latamLoaded = true
        end if
        if m.view = "live" then refreshLiveList(true)
    end if
    drawScreen()
    if not m.liveFullscreen and m.dialogBox = invalid then m.top.setFocus(true)
end sub

sub openCatalog(kind as string)
    m.kind = kind
    m.nav = 1
    if kind = "series" then m.nav = 2
    m.query = ""
    m.titles = []
    m.cursor = 0
    m.offset = 0
    m.view = "browse"
    m.zone = "grid"
    loadBrowsePage(0)
end sub

sub openDetails(item as object, origin as string, playNow = false as boolean)
    m.detail = item
    m.detail.hdAttempt = 0
    m.detailOrigin = origin
    m.autoplay = playNow
    m.action = 0
    m.view = "detail"
    m.zone = "action"
    m.kind = "movie"
    if item.kind = "series" or item.kind = "episode" then m.kind = "series"
    if item.kind = "episode" or (m.catalogMode = "hd" and not usesOnlineHd())
        if playNow
            m.autoplay = false
            playDetail()
        else
            drawScreen()
        end if
    else
        fetch({operation:"meta",item:item})
    end if
end sub

sub launchVideo(item as object, url as string, format as string)
    stopLivePreview()
    m.player.theme = m.theme
    m.player.allowPreviewReturn = false
    m.player.presentation = "fullscreen"
    eraseScreen()
    m.canvas.visible = false
    m.viewBeforePlayer = m.view
    m.view = "player"
    m.player.visible = true
    descriptor = {title:item.title,url:url,streamFormat:format,kind:item.kind,itemId:item.id,provider:orbitText(item.provider,32),direct:m.playbackMode="direct"}
    if item.doesExist("mediaHeaders") then descriptor.mediaHeaders = item.mediaHeaders
    m.player.request = descriptor
end sub

sub playerClosed(event as object)
    if event.getData() <> true then return
    if m.player.active = true then return
    if m.view = "live" then return
    if m.view <> "player" then return
    m.player.visible = false
    m.view = m.viewBeforePlayer
    if m.recovering = true
        m.recovering = false
        if m.view = "live"
            channel = m.channels[m.liveCursor]
            launchVideo(channel,channel.url,channel.streamFormat)
        else
            playDetail()
        end if
        return
    end if
    m.note = ""
    drawScreen()
    m.top.setFocus(true)
end sub

sub retryVideo(event as object)
    if m.view = "live"
        retry = event.getData()
        if type(retry) <> "roAssociativeArray" then return
        if not m.livePreviewOpen or m.livePreviewItem = invalid then return
        if retry.requestId <> m.livePreviewRequestTag or retry.itemId <> m.livePreviewItem.id then return
        fullscreen = m.liveFullscreen
        stopLivePreview(false)
        startLivePreview()
        if fullscreen and m.livePreviewOpen
            m.liveFullscreen = true
            m.player.presentation = "fullscreen"
        end if
        return
    end if
    if m.view <> "player" then return
    if m.detail <> invalid and usesOnlineHd()
        m.detail.hdAttempt = orbitInteger(m.detail.hdAttempt,99)+1
        if m.detail.hdAttempt > 99 then m.detail.hdAttempt = 0
    end if
    m.recovering = true
    m.player.callFunc("closePlayback")
end sub

sub playerDiagnostic(event as object)
    ' Diagnostics remain on this device's developer console; no upload route.
    sample = event.getData()
    if type(sample) = "roAssociativeArray" then print "[RokuPlus playback] "; FormatJson(sample)
end sub

sub openSearch()
    cancelRequest()
    if m.kind <> "series" then m.kind = "movie"
    m.view = "browse"
    m.zone = "nav"
    m.nav = 4
    drawScreen()
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    title = "Buscar películas"
    if m.kind = "series" then title = "Buscar series"
    dialog.title = title
    dialog.text = m.query
    dialog.buttons = ["Buscar","Cancelar"]
    dialog.observeField("buttonSelected","searchChosen")
    dialog.observeField("wasClosed","searchDismissed")
    m.dialogBox = dialog
    m.top.dialog = dialog
end sub

sub openLiveSearch()
    if m.view <> "live" then return
    if m.previewTimer <> invalid then m.previewTimer.control = "stop"
    dialog = CreateObject("roSGNode","StandardKeyboardDialog")
    dialog.title = "Buscar canales"
    dialog.text = m.liveQuery
    dialog.buttons = ["Buscar","Cancelar"]
    dialog.observeField("buttonSelected","liveSearchChosen")
    dialog.observeField("wasClosed","liveSearchDismissed")
    m.dialogBox = dialog
    m.top.dialog = dialog
end sub

sub liveSearchChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    text = left(m.dialogBox.text.trim(),80)
    choice = event.getData()
    releaseDialog()
    if m.view <> "live" then return
    m.liveSearchCursor = 0
    m.zone = "live-search"
    if choice = 0
        m.liveQuery = text
        m.note = ""
        refreshLiveList(false)
        if m.channels.count() > 0 then m.zone = "live"
    else if not m.livePreviewOpen and m.channels.count() > 0
        scheduleLivePreview()
    end if
    drawScreen()
    m.top.setFocus(true)
end sub

sub liveSearchDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog()
    if m.view <> "live" then return
    m.zone = "live-search"
    m.liveSearchCursor = 0
    if not m.livePreviewOpen and m.channels.count() > 0 then scheduleLivePreview()
    drawScreen()
    m.top.setFocus(true)
end sub

sub clearLiveSearch()
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.zone = "live-search"
    m.note = ""
    refreshLiveList(false)
    drawScreen()
end sub

sub releaseDialog()
    if m.dialogBox = invalid then return
    dialog = m.dialogBox
    m.dialogBox = invalid
    dialog.unobserveField("buttonSelected")
    dialog.unobserveField("wasClosed")
    dialog.close = true
end sub

sub searchChosen(event as object)
    if m.dialogBox = invalid then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    query = left(m.dialogBox.text.trim(),120)
    choice = event.getData()
    releaseDialog()
    if choice = 0
        m.query = query
        m.cursor = 0
        loadBrowsePage(0)
    else if m.titles.count() = 0
        loadBrowsePage(0)
    end if
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub searchDismissed(event as object)
    if m.dialogBox = invalid or event.getData() <> true then return
    if not m.dialogBox.isSameNode(event.getRoSGNode()) then return
    releaseDialog()
    if m.titles.count() = 0 then loadBrowsePage(0)
    m.zone = "grid"
    drawScreen()
    m.top.setFocus(true)
end sub

sub goHome()
    stopLivePreview()
    if m.noteTimer <> invalid then m.noteTimer.control = "stop"
    cancelRequest()
    m.note = ""
    m.view = "home"
    m.nav = 0
    m.zone = "hero"
    m.hero = 0
    drawScreen()
    m.top.setFocus(true)
end sub

sub returnOneStep()
    m.note = ""
    if m.view = "credits" or m.view = "hd-source" or m.view = "appearance"
        openSettings()
        return
    end if
    if m.view = "detail"
        if m.detailOrigin = "episodes"
            m.view = "episodes"
            m.zone = "episodes"
        else if m.detailOrigin = "browse"
            m.view = "browse"
            m.zone = "grid"
        else
            goHome()
            return
        end if
    else if m.view = "episodes"
        m.detail = m.series
        m.detailOrigin = m.seriesOrigin
        m.view = "detail"
        m.zone = "action"
        m.action = 0
    else
        goHome()
        return
    end if
    drawScreen()
end sub

sub activateNav()
    if m.nav <> 3 then stopLivePreview()
    if m.nav = 0 then goHome()
    if m.nav = 1 then openCatalog("movie")
    if m.nav = 2 then openCatalog("series")
    if m.nav = 3
        m.view = "live"
        selectLiveFilter(m.liveFilter)
    end if
    if m.nav = 4 then openSearch()
    if m.nav = 5 then openSettings()
end sub

sub selectLiveFilter(filter as integer)
    cancelRequest()
    stopLivePreview()
    m.liveFilter = orbitInteger(filter,3)
    m.liveFilterCursor = m.liveFilter
    m.liveCursor = 0
    m.zone = "live-filters"
    m.note = ""
    refreshLiveList(false)
    if (m.liveFilter = 2 or m.liveFilter = 3) and not m.latamLoaded
        if m.liveFilter = 2 or m.liveFavorites.count() > 0 then fetch({operation:"latam"})
    else if (m.liveFilter = 0 or m.liveFilter = 1) and m.liveLoadedCountry <> m.countryCode
        fetch({operation:"country"})
    end if
    drawScreen()
end sub

sub refreshLiveList(preserve as boolean)
    selected = ""
    selectedUrl = ""
    if preserve and m.liveCursor >= 0 and m.liveCursor < m.channels.count()
        selected = rpLiveFavoriteKey(m.channels[m.liveCursor])
        selectedUrl = m.channels[m.liveCursor].url
    end if
    source = m.countryChannels
    if m.liveFilter = 2 then source = m.latamChannels
    if m.liveFilter = 3 then source = rpLiveMergeChannels(m.countryChannels,m.latamChannels)
    merged = rpLiveMergeChannels(source,rpRealityItems())
    merged = rpLivePopularityOrder(merged)
    m.channels = rpLiveVisibleChannels(merged,m.liveFavorites,m.liveFilter,m.countryCode)
    m.channels = rpLiveSearchChannels(m.channels,m.liveQuery)
    m.liveCursor = 0
    if preserve and selected <> ""
        for i = 0 to m.channels.count()-1
            if rpLiveFavoriteKey(m.channels[i]) = selected and m.channels[i].url = selectedUrl
                m.liveCursor = i
                exit for
            end if
        end for
    end if
    if m.channels.count() > 0
        nextItem = m.channels[m.liveCursor]
        if m.livePreviewItem = invalid
            scheduleLivePreview()
        else if m.livePreviewItem.id <> nextItem.id or m.livePreviewItem.url <> nextItem.url
            scheduleLivePreview()
        end if
    else
        stopLivePreview()
    end if
end sub

sub stopLivePreview(clearItem = true as boolean)
    if m.previewTimer <> invalid then m.previewTimer.control = "stop"
    m.livePreviewRequestTag = ""
    if m.livePreviewOpen = true
        m.livePreviewOpen = false
        m.player.callFunc("closePlayback")
    end if
    m.liveFullscreen = false
    m.livePreviewKey = ""
    if clearItem
        m.livePreviewItem = invalid
        m.livePreviewStatus = "Selecciona un canal"
    end if
end sub

sub scheduleLivePreview()
    stopLivePreview()
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    m.livePreviewItem = m.channels[m.liveCursor]
    m.livePreviewStatus = "Preparando vista previa…"
    if not rpLivePlayable(m.livePreviewItem)
        m.livePreviewStatus = orbitText(m.livePreviewItem.availabilityLabel,100)
        if m.livePreviewStatus = "" then m.livePreviewStatus = "Sin señal disponible"
        return
    end if
    if m.previewTimer <> invalid then m.previewTimer.control = "start"
end sub

sub startLivePreview()
    if m.view <> "live" or m.liveFullscreen then return
    if m.dialogBox <> invalid then return
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    channel = m.channels[m.liveCursor]
    m.livePreviewItem = channel
    if not rpLivePlayable(channel) then return
    key = rpLiveFavoriteKey(channel)+"|"+channel.url
    if m.livePreviewOpen and m.livePreviewKey = key then return
    stopLivePreview(false)
    m.livePreviewItem = channel
    m.livePreviewKey = key
    m.livePreviewStatus = "Cargando señal…"
    m.livePreviewOpen = true
    m.liveRequestSequence++
    m.livePreviewRequestTag = m.liveRequestSequence.toStr()
    m.player.allowPreviewReturn = true
    m.player.theme = m.theme
    m.player.previewRect = [294,206,1016,572]
    m.player.presentation = "preview"
    descriptor = {title:channel.title,url:channel.url,streamFormat:channel.streamFormat,kind:"live",itemId:channel.id,requestId:m.livePreviewRequestTag,provider:orbitText(channel.provider,32),direct:true}
    if channel.doesExist("mediaHeaders") then descriptor.mediaHeaders = channel.mediaHeaders
    m.player.request = descriptor
    m.canvas.visible = true
    m.top.setFocus(true)
    drawScreen()
end sub

sub playLiveSelection()
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    channel = m.channels[m.liveCursor]
    if not rpLivePlayable(channel)
        m.note = orbitText(channel.availabilityMessage,320)
        if m.note = "" then m.note = "No hay una señal disponible para este programa."
        drawScreen()
        return
    end if
    if m.livePreviewStatus = "La señal no respondió. OK para reintentar." then stopLivePreview(false)
    if not m.livePreviewOpen
        startLivePreview()
    end if
    m.liveFullscreen = true
    m.player.presentation = "fullscreen"
end sub

sub openAppearance()
    m.view = "appearance"
    m.zone = "appearance"
    m.themeCursor = 0
    if m.theme = "classic" then m.themeCursor = 1
    drawScreen()
end sub

sub saveAppearance()
    theme = "glass"
    if m.themeCursor = 1 then theme = "classic"
    if rpSaveTheme(theme)
        m.theme = theme
        openSettings()
    else
        m.note = "No se pudo guardar la apariencia. Intenta otra vez."
        drawScreen()
    end if
end sub

sub livePreviewReturned(event as object)
    if event.getData() <> true or m.view <> "live" then return
    m.liveFullscreen = false
    m.zone = "live"
    drawScreen()
    if m.dialogBox = invalid then m.top.setFocus(true)
end sub

sub livePreviewProgress(event as object)
    if m.view <> "live" or not m.livePreviewOpen or m.livePreviewItem = invalid then return
    sample = event.getData()
    if type(sample) <> "roAssociativeArray" then return
    if sample.itemId <> m.livePreviewItem.id then return
    if sample.requestId <> m.livePreviewRequestTag then return
    status = "Cargando señal…"
    if sample.state = "playing" then status = "En vivo"
    if sample.state = "paused" then status = "En pausa"
    if sample.failed = true or sample.state = "error" then status = "La señal no respondió. OK para reintentar."
    if status <> m.livePreviewStatus
        m.livePreviewStatus = status
        if not m.liveFullscreen then drawScreen()
    end if
end sub

sub livePreviewClosed(event as object)
    if m.view <> "live" or not m.livePreviewOpen then return
    sample = event.getData()
    if type(sample) <> "roAssociativeArray" then return
    if sample.requestId <> m.livePreviewRequestTag then return
    m.livePreviewOpen = false
    m.liveFullscreen = false
    m.livePreviewRequestTag = ""
    m.livePreviewStatus = "La señal terminó. OK para volver a abrirla."
    m.player.visible = false
    drawScreen()
    if m.dialogBox = invalid then m.top.setFocus(true)
end sub

sub toggleLiveFavorite()
    if m.liveCursor < 0 or m.liveCursor >= m.channels.count() then return
    result = rpLiveFavoritesToggle(m.liveFavorites,m.channels[m.liveCursor])
    if not result.ok
        m.note = result.message
    else if not rpLiveSaveFavorites(result.keys)
        m.note = "No se pudo guardar el favorito. Intenta otra vez."
    else
        m.liveFavorites = result.keys
        m.note = "Canal quitado de favoritos."
        if result.added then m.note = "Canal guardado en favoritos. Aparecerá al principio."
        refreshLiveList(true)
    end if
    if m.noteTimer <> invalid then m.noteTimer.control = "start"
    drawScreen()
end sub

sub liveNoticeElapsed()
    if m.view <> "live" then return
    m.note = ""
    if not m.liveFullscreen then drawScreen()
end sub


sub beginSetup(fromSettings as boolean, countryOnly as boolean)
    cancelRequest()
    m.setupFromSettings = fromSettings
    m.setupCountryOnly = countryOnly
    m.setupTv = 0
    if m.catalogMode = "hevc" then m.setupTv = 1
    m.setupCountry = 0
    choices = orbitCountries()
    for i = 0 to choices.count()-1
        if choices[i].code = m.countryCode then m.setupCountry = i
    end for
    m.view = "setup-tv"
    m.zone = "setup"
    if countryOnly
        m.view = "setup-country"
        m.zone = "country"
    end if
    drawScreen()
end sub

sub commitSetup()
    stopLivePreview()
    choices = orbitCountries()
    if m.setupCountry < 0 or m.setupCountry >= choices.count() then return
    mode = "hd"
    if m.setupTv = 1 then mode = "hevc"
    code = choices[m.setupCountry].code
    saved = rpSavePreferences(mode,code)
    cancelRequest()
    cancelHomeRequests()
    m.catalogMode = mode
    m.countryCode = code
    m.configured = saved
    m.channels = []
    m.countryChannels = []
    m.liveLoadedCountry = ""
    m.liveFilter = 0
    m.liveFilterCursor = 0
    m.liveQuery = ""
    m.liveSearchCursor = 0
    m.liveCursor = 0
    m.titles = []
    m.query = ""
    m.kind = "movie"
    m.hero = 0
    m.features = []
    m.homeSeries = []
    m.homeRows = rpHomeRowsBuild(m.features, m.homeSeries)
    m.rowFocus = 0
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.note = ""
    if not saved then m.note = "La selección funciona en esta sesión, pero no se pudo guardar en la Roku."
    refreshHome()
    drawScreen()
    m.top.setFocus(true)
end sub

sub openSettings()
    cancelRequest()
    m.view = "settings"
    m.zone = "settings"
    m.nav = 5
    m.settingsCursor = 0
    m.note = ""
    drawScreen()
    m.top.setFocus(true)
end sub

sub openCredits()
    m.creditsPages = []
    text = ReadAsciiFile("pkg:/CREDITS-HD.txt")
    page = ""
    for each line in text.split(chr(10))
        if len(page)+len(line) > 1250
            m.creditsPages.push(page)
            page = ""
        end if
        page += line+chr(10)
    end for
    if page <> "" then m.creditsPages.push(page)
    if m.creditsPages.count() = 0 then m.creditsPages.push("Biblioteca HD: Blender Studio y NASA. Consulta los créditos del paquete.")
    m.creditsPage = 0
    m.view = "credits"
    m.zone = "credits"
    drawScreen()
end sub

sub cancelHomeRequests()
    for each entry in m.homeJobs
        entry.node.unobserveField("result")
        entry.node.unobserveField("state")
        entry.node.cancelRequested = true
    end for
    m.homeJobs = []
    m.homeLoading = false
end sub

sub refreshHome()
    cancelHomeRequests()
    if m.catalogMode = "hd" and not usesOnlineHd()
        m.features = m.hdLibrary.movies
        m.homeSeries = m.hdLibrary.series
        return
    end if
    m.homeLoading = true
    for each kind in ["movie","series"]
        taskName = "CatalogTask"
        if usesOnlineHd() then taskName = "HdCatalogTask"
        task = CreateObject("roSGNode",taskName)
        if usesOnlineHd() then task.provider = m.hdProvider
        request = CreateObject("roDeviceInfo").getRandomUUID()
        task.operation = "catalog"
        task.kind = kind
        task.requestId = request
        task.observeField("result","homeFetched")
        task.observeField("state","homeStopped")
        m.homeJobs.push({node:task,request:request,kind:kind,mode:m.catalogMode,provider:m.hdProvider})
        task.control = "RUN"
    end for
end sub

sub homeFetched(event as object)
    answer = event.getData()
    if type(answer) <> "roAssociativeArray" then return
    for i = 0 to m.homeJobs.count()-1
        entry = m.homeJobs[i]
        if entry.node.isSameNode(event.getRoSGNode()) and answer.requestId = entry.request
            if entry.mode <> m.catalogMode then return
            if m.catalogMode = "hd" and entry.provider <> m.hdProvider then return
            if answer.ok
                if entry.kind = "movie" then m.features = answer.items else m.homeSeries = answer.items
                m.homeRows = rpHomeRowsBuild(m.features, m.homeSeries)
            else
                m.note = "No se pudo actualizar una de las filas. Puedes explorar desde el menú o volver a intentar."
            end if
            entry.node.unobserveField("result")
            entry.node.unobserveField("state")
            m.homeJobs.delete(i)
            exit for
        end if
    end for
    m.homeLoading = m.homeJobs.count() > 0
    if m.view = "home" then drawScreen()
end sub

sub homeStopped(event as object)
    if event.getData() <> "STOP" then return
    for i = 0 to m.homeJobs.count()-1
        entry = m.homeJobs[i]
        if entry.node.isSameNode(event.getRoSGNode())
            if type(entry.node.result) = "roAssociativeArray" then return
            entry.node.unobserveField("result")
            entry.node.unobserveField("state")
            m.homeJobs.delete(i)
            m.note = "No se pudo actualizar el catálogo. Puedes explorar desde el menú."
            exit for
        end if
    end for
    m.homeLoading = m.homeJobs.count() > 0
    if m.view = "home" then drawScreen()
end sub

sub loadBrowsePage(offset as integer, last = false as boolean)
    if m.catalogMode = "hd" and not usesOnlineHd()
        cancelRequest()
        m.titles = rpHdCatalog(m.kind,m.query)
        m.offset = 0
        m.nextOffset = 0
        m.more = false
        m.cursor = 0
        m.zone = "grid"
        drawScreen()
    else
        fetch({operation:"catalog",offset:offset,last:last})
    end if
end sub

function detailActionCount() as integer
    if m.detail = invalid then return 0
    return 2
end function

sub playDetail()
    if m.detail = invalid then return
    m.playbackMode = "direct"
    if usesOnlineHd()
        fetch({operation:"resolve",item:m.detail})
    else if m.catalogMode = "hd"
        if m.detail.doesExist("directUrl") and m.detail.directUrl <> ""
            launchVideo(m.detail,m.detail.directUrl,m.detail.streamFormat)
        else
            m.note = "Este título no tiene una fuente disponible."
            drawScreen()
        end if
    else if m.capabilities.hevcKnown and not m.capabilities.canDecodeHevc
        m.note = "Esta Roku no anunció compatibilidad con este catálogo. Puedes elegir HD en Configuración."
        drawScreen()
    else
        fetch({operation:"resolve",item:m.detail})
    end if
end sub

sub enterEpisodes()
    if m.detail.seasons.count() = 0
        if usesOnlineHd()
            fetch({operation:"meta",item:m.detail})
            return
        end if
        m.note = "No se encontraron episodios para esta serie."
    else
        m.series = m.detail
        m.seriesOrigin = m.detailOrigin
        m.season = 0
        if m.series.seasons[0].number = 0 and m.series.seasons.count() > 1 then m.season = 1
        m.episode = 0
        m.view = "episodes"
        m.zone = "episodes"
        loadEpisodeSeason()
    end if
    drawScreen()
end sub

function usesOnlineHd() as boolean
    source = orbitText(m.hdProvider,32)
    return m.catalogMode = "hd" and (source = "all" or source = "lamovie" or source = "allcalidad" or source = "cinehax" or source = "seriesmetro" or source = "cinecalidad")
end function

function hdProviderName(value = invalid as dynamic) as string
    source = orbitText(value,32)
    if source = "" then source = orbitText(m.hdProvider,32)
    if source = "all" then return "Todas las fuentes"
    if source = "allcalidad" then return "AllCalidad"
    if source = "cinehax" then return "CineHax"
    if source = "seriesmetro" then return "SeriesMetro"
    if source = "cinecalidad" then return "CineCalidad"
    if source = "open" then return "Cortos y documentales"
    return "LaMovie"
end function

function hdProviderChoices() as object
    return ["all","lamovie","allcalidad","cinehax","seriesmetro","cinecalidad","open"]
end function

sub openHdSource()
    cancelRequest()
    m.hdSourceCursor = 0
    choices = hdProviderChoices()
    for i = 0 to choices.count()-1
        if choices[i] = m.hdProvider then m.hdSourceCursor = i
    end for
    m.view = "hd-source"
    m.zone = "hd-source"
    drawScreen()
end sub

sub commitHdSource()
    choices = hdProviderChoices()
    if m.hdSourceCursor < 0 or m.hdSourceCursor >= choices.count() then return
    source = choices[m.hdSourceCursor]
    saved = rpSaveHdProvider(source)
    cancelRequest()
    if m.catalogMode = "hd" then cancelHomeRequests()
    m.hdProvider = source
    m.titles = []
    m.query = ""
    m.offset = 0
    m.cursor = 0
    m.kind = "movie"
    m.detail = invalid
    m.series = invalid
    if m.catalogMode = "hd"
        m.features = []
        m.homeSeries = []
        m.homeRows = rpHomeRowsBuild(m.features, m.homeSeries)
        m.rowFocus = 0
        m.nav = 0
        m.view = "home"
        m.zone = "hero"
        m.hero = 0
        refreshHome()
        drawScreen()
    else
        openSettings()
    end if
    if not saved
        m.note = "La fuente funciona en esta sesión, pero no se pudo guardar en la Roku."
        drawScreen()
    end if
end sub

sub loadEpisodeSeason()
    if not usesOnlineHd() or m.series = invalid then return
    if m.season < 0 or m.season >= m.series.seasons.count() then return
    season = m.series.seasons[m.season]
    if season.loaded = true then return
    fetch({operation:"episodes",item:m.series,season:season.number})
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if key = "home" then return false
    if not press then return true
    if m.view = "player" or m.dialogBox <> invalid then return false
    if m.view = "setup-tv"
        if key = "left" or key = "up" then m.setupTv = 0
        if key = "right" or key = "down" then m.setupTv = 1
        if key = "OK"
            m.view = "setup-country"
            m.zone = "country"
            drawScreen()
        else if key = "back" and m.setupFromSettings
            openSettings()
        else
            paintFocus()
        end if
        return true
    else if m.view = "setup-country"
        if key = "up" and m.setupCountry > 0 then m.setupCountry--
        if key = "down" and m.setupCountry+1 < orbitCountries().count() then m.setupCountry++
        if key = "OK" then commitSetup(): return true
        if key = "back"
            if m.setupCountryOnly and m.setupFromSettings
                openSettings()
                return true
            end if
            m.view = "setup-tv"
            m.zone = "setup"
        end if
        drawScreen()
        return true
    end if
    if key = "back"
        if m.busy
            cancelRequest()
            m.autoplay = false
            drawScreen()
        else if m.view = "live" and (m.zone = "live" or m.zone = "live-actions" or m.zone = "live-search")
            m.zone = "live-filters"
            drawScreen()
        else
            returnOneStep()
        end if
        return true
    end if
    if m.view = "credits"
        if key = "down" and m.creditsPage+1 < m.creditsPages.count() then m.creditsPage++
        if key = "up" and m.creditsPage > 0 then m.creditsPage--
        drawScreen()
        return true
    end if
    if m.view = "appearance"
        if key = "left" then m.themeCursor = 0
        if key = "right" then m.themeCursor = 1
        if key = "OK" then saveAppearance(): return true
        paintFocus()
        return true
    end if
    if m.view = "hd-source"
        if key = "up" and m.hdSourceCursor > 0 then m.hdSourceCursor--
        if key = "down" and m.hdSourceCursor+1 < hdProviderChoices().count() then m.hdSourceCursor++
        if key = "OK" then commitHdSource(): return true
        paintFocus()
        return true
    end if
    if key = "options" or key = "info"
        if m.view = "live" then toggleLiveFavorite(): return true
        openSearch()
        return true
    end if
    if m.busy and m.view <> "live" then return true
    if m.zone = "nav"
        if key = "up" and m.nav > 0 then m.nav--
        if key = "down" and m.nav < 5 then m.nav++
        if key = "OK" then activateNav(): return true
        if key = "right"
            if m.view = "home" then m.zone = "hero"
            if m.view = "browse" then m.zone = "grid"
            if m.view = "live" then m.zone = "live-filters"
            if m.view = "detail" then m.zone = "action"
            if m.view = "episodes" then m.zone = "episodes"
            if m.view = "settings" then m.zone = "settings"
        end if
        drawScreen()
        return true
    end if
    if m.view = "settings"
        if key = "left" then m.zone = "nav": drawScreen(): return true
        if key = "up" and m.settingsCursor > 0 then m.settingsCursor--
        if key = "down" and m.settingsCursor < 4 then m.settingsCursor++
        if key = "OK"
            if m.settingsCursor = 0 then beginSetup(true,false)
            if m.settingsCursor = 1 then beginSetup(true,true)
            if m.settingsCursor = 2 then openHdSource()
            if m.settingsCursor = 3 then openCredits()
            if m.settingsCursor = 4 then openAppearance()
            return true
        end if
        paintFocus()
        return true
    else if m.view = "home"
        if m.zone = "hero"
            if key = "left"
                if m.hero = 0 then m.zone = "nav": drawScreen(): return true
                m.hero = 0
            end if
            if key = "right" and m.features.count() > 0 then m.hero = 1
            if key = "up" then m.zone = "nav": drawScreen(): return true
            if key = "down" and m.homeRows.count() > 0 then m.zone = "home-row-0"
            if key = "OK"
                if m.features.count() > 0 then openDetails(m.features[0],"home",m.hero=0) else refreshHome(): drawScreen()
                return true
            end if
        else if left(m.zone,9) = "home-row-"
            rowIndex = val(mid(m.zone,10))
            row = m.homeRows[rowIndex]
            if key = "left"
                next = rpRowAdvance(row,row.items,-1,5)
                if next.cursor = row.cursor then m.zone = "nav": drawScreen(): return true
                row.cursor = next.cursor
                row.offset = next.offset
            end if
            if key = "right"
                next = rpRowAdvance(row,row.items,1,5)
                row.cursor = next.cursor
                row.offset = next.offset
            end if
            if key = "up"
                if rowIndex = 0 then m.zone = "hero" else m.zone = "home-row-"+(rowIndex-1).toStr()
            end if
            if key = "down" and rowIndex < m.homeRows.count()-1 then m.zone = "home-row-"+(rowIndex+1).toStr()
            if key = "OK" and row.items.count() > 0 then openDetails(row.items[row.cursor],"home"): return true
        end if
    else if m.view = "browse"
        block = m.cursor \ 6
        if key = "left"
            if m.cursor mod 3 > 0 then m.cursor-- else m.zone = "nav": drawScreen(): return true
        end if
        if key = "right" and m.cursor mod 3 < 2 and m.cursor+1 < m.titles.count() then m.cursor++
        if key = "up" or key = "rewind"
            if m.cursor >= 3
                m.cursor -= 3
            else if m.offset > 0
                previous = m.offset-20
                if previous < 0 then previous = 0
                loadBrowsePage(previous,true)
                return true
            else
                m.zone = "nav"
                m.nav = 1
                if m.kind = "series" then m.nav = 2
                drawScreen()
                return true
            end if
        end if
        if key = "down" or key = "fastforward"
            if ((m.cursor \ 3)+1)*3 < m.titles.count()
                m.cursor += 3
                if m.cursor >= m.titles.count() then m.cursor = m.titles.count()-1
            else if m.more
                loadBrowsePage(m.nextOffset)
                return true
            end if
        end if
        if key = "OK" and m.titles.count() > 0 then openDetails(m.titles[m.cursor],"browse"): return true
        if block <> m.cursor \ 6 then drawScreen(): return true
    else if m.view = "detail"
        if key = "left" then m.zone = "nav": drawScreen(): return true
        if key = "up"
            if m.action > 0 then m.action-- else m.zone = "nav": drawScreen(): return true
        end if
        finalAction = detailActionCount()-1
        if key = "down" and m.action < finalAction then m.action++
        if key = "OK"
            if m.action = finalAction
                returnOneStep()
            else if m.detail.kind = "series"
                enterEpisodes()
            else
                playDetail()
            end if
            return true
        end if
    else if m.view = "episodes"
        if key = "left"
            if m.season > 0
                m.season--
                m.episode = 0
                loadEpisodeSeason()
            else
                m.zone = "nav"
                drawScreen()
                return true
            end if
        end if
        if key = "right" and m.season+1 < m.series.seasons.count()
            m.season++
            m.episode = 0
            loadEpisodeSeason()
        end if
        items = m.series.seasons[m.season].episodes
        if key = "up" and m.episode > 0 then m.episode--
        if key = "down" and m.episode+1 < items.count() then m.episode++
        if key = "OK"
            if items.count() > 0 then openDetails(items[m.episode],"episodes") else loadEpisodeSeason()
            return true
        end if
        drawScreen()
        return true
    else if m.view = "live"
        if m.zone = "live-search"
            if key = "up" then m.zone = "live-filters": paintFocus(): return true
            if key = "down"
                if m.channels.count() > 0 then m.zone = "live"
                paintFocus()
                return true
            end if
            if key = "left"
                if m.liveSearchCursor > 0 then m.liveSearchCursor = 0 else m.zone = "nav"
            end if
            if key = "right" and m.liveQuery <> "" then m.liveSearchCursor = 1
            if key = "OK"
                if m.liveSearchCursor = 1 then clearLiveSearch() else openLiveSearch()
                return true
            end if
            paintFocus()
            return true
        end if
        if m.zone = "live-filters"
            if key = "left"
                if m.liveFilterCursor > 0
                    selectLiveFilter(m.liveFilterCursor-1)
                else
                    cancelRequest()
                    m.zone = "nav"
                    m.nav = 3
                    drawScreen()
                end if
                return true
            end if
            if key = "right" and m.liveFilterCursor < 3 then selectLiveFilter(m.liveFilterCursor+1): return true
            if key = "OK" or key = "down"
                if key = "down" or m.channels.count() = 0
                    m.zone = "live-search"
                    m.liveSearchCursor = 0
                    drawScreen()
                else if m.channels.count() > 0
                    m.zone = "live"
                    drawScreen()
                end if
                return true
            end if
            paintFocus()
            return true
        end if
        if m.zone = "live-actions"
            if key = "left" then m.zone = "nav"
            if key = "right" then m.zone = "live"
            if key = "up" then m.liveAction = 0
            if key = "down" then m.liveAction = 1
            if key = "OK"
                if m.liveAction = 0 then playLiveSelection() else toggleLiveFavorite()
                return true
            end if
            paintFocus()
            return true
        end if
        previous = m.liveCursor
        if key = "left" then m.zone = "live-actions": m.liveAction = 0: drawScreen(): return true
        if key = "up"
            if m.liveCursor > 0 then m.liveCursor-- else m.zone = "live-search": m.liveSearchCursor = 0: drawScreen(): return true
        end if
        if key = "down" and m.liveCursor+1 < m.channels.count() then m.liveCursor++
        if key = "OK" and m.channels.count() > 0
            playLiveSelection()
            return true
        end if
        if previous <> m.liveCursor then scheduleLivePreview(): drawScreen(): return true
    end if
    paintFocus()
    return true
end function
