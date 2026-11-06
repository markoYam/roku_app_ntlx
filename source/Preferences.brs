' Original Roku Plus preferences: catalog profile, HD source and appearance.
' Never persist decoder identifiers, accounts, URLs or PC/playback state.

function rpNormalizePreferences(raw as dynamic, recommended = "hd" as dynamic) as object
    mode = "hd"
    if GetInterface(recommended, "ifString") <> invalid
        if recommended = "hevc" then mode = "hevc"
    end if
    result = {configured: false, mode: mode, countryCode: "mx"}
    if type(raw) <> "roAssociativeArray" then return result
    if GetInterface(raw.version, "ifInt") = invalid then return result
    if raw.version <> 1 then return result
    if GetInterface(raw.mode, "ifString") = invalid then return result
    if raw.mode <> "hd" and raw.mode <> "hevc" then return result
    country = orbitCountryCode(raw.countryCode)
    if country = "" then return result
    result.configured = true
    result.mode = raw.mode
    result.countryCode = country
    return result
end function

function rpNormalizeTheme(value as dynamic) as string
    if GetInterface(value,"ifString") <> invalid
        if value = "classic" then return "classic"
    end if
    return "glass"
end function

function rpLoadTheme() as string
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return "glass"
    return rpNormalizeTheme(section.read("themeV1"))
end function

function rpSaveTheme(value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if value <> "glass" and value <> "classic" then return false
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    return rpStoreTheme(section,value)
end function

function rpStoreTheme(section as object, value as dynamic) as boolean
    if GetInterface(value,"ifString") = invalid then return false
    if value <> "glass" and value <> "classic" then return false
    previous = section.read("themeV1")
    if section.write("themeV1",value) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("themeV1") else section.write("themeV1",previous)
    section.flush()
    return false
end function

' Separate backward-compatible preference. Never stores a provider URL or token.
function rpNormalizeHdProvider(value as dynamic) as string
    if GetInterface(value,"ifString") <> invalid
        if value = "all" or value = "lamovie" or value = "allcalidad" or value = "cinehax" or value = "seriesmetro" or value = "cinecalidad" or value = "open" then return value
    end if
    return "all"
end function

function rpLoadHdProvider() as string
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return "all"
    return rpNormalizeHdProvider(section.read("hdSourceV1"))
end function

function rpSaveHdProvider(value as dynamic) as boolean
    provider = rpNormalizeHdProvider(value)
    if provider <> value then return false
    section = CreateObject("roRegistrySection","RokuPlusPreferences")
    if GetInterface(section,"ifRegistrySection") = invalid then return false
    return rpStoreHdProvider(section,provider)
end function

function rpStoreHdProvider(section as object, provider as dynamic) as boolean
    if rpNormalizeHdProvider(provider) <> provider then return false
    previous = section.read("hdSourceV1")
    if section.write("hdSourceV1",provider) <> true then return false
    if section.flush() = true then return true
    if previous = "" then section.delete("hdSourceV1") else section.write("hdSourceV1",previous)
    section.flush()
    return false
end function

function rpPreferencesFromText(text as dynamic, recommended = "hd" as dynamic) as object
    fallback = rpNormalizePreferences(invalid, recommended)
    if GetInterface(text, "ifString") = invalid then return fallback
    if len(text) = 0 or len(text) > 512 then return fallback
    text = text.trim()
    if left(text, 1) <> "{" or right(text, 1) <> "}" then return fallback
    return rpNormalizePreferences(ParseJson(text), recommended)
end function

function rpLoadPreferences(recommended = "hd" as dynamic) as object
    section = CreateObject("roRegistrySection", "RokuPlusPreferences")
    if GetInterface(section, "ifRegistrySection") = invalid then return rpNormalizePreferences(invalid, recommended)
    return rpPreferencesFromText(section.read("profileV1"), recommended)
end function

function rpSavePreferences(mode as dynamic, countryCode as dynamic) as boolean
    settings = rpNormalizePreferences({version: 1, mode: mode, countryCode: countryCode})
    if not settings.configured then return false
    section = CreateObject("roRegistrySection", "RokuPlusPreferences")
    if GetInterface(section, "ifRegistrySection") = invalid then return false
    return rpStorePreferences(section, settings.mode, settings.countryCode)
end function

' This small I/O boundary is separately testable with a registry-method stub.
function rpStorePreferences(section as object, mode as dynamic, countryCode as dynamic) as boolean
    settings = rpNormalizePreferences({version: 1, mode: mode, countryCode: countryCode})
    if not settings.configured then return false
    previous = rpPreferencesFromText(section.read("profileV1"))
    payload = FormatJson({version: 1, mode: settings.mode, countryCode: settings.countryCode})
    if GetInterface(payload, "ifString") = invalid then return false
    if section.write("profileV1", payload) <> true then return false
    if section.flush() = true then return true
    ' A failed commit must never be reported as configured. Restore the prior
    ' buffered choice, or remove an uncommitted first-run choice, then fail.
    if previous.configured
        restored = FormatJson({version: 1, mode: previous.mode, countryCode: previous.countryCode})
        section.write("profileV1", restored)
    else
        section.delete("profileV1")
    end if
    section.flush()
    return false
end function
