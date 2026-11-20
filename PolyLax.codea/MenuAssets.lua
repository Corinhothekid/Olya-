-- Optional project art and audio for the front menu.
PolyLax = PolyLax or {}
local MenuAssets = {}
PolyLax.MenuAssets = MenuAssets

local muteKey = "PolyLax.MenuMusicMuted.1"
local imageExtensions = {png=true, jpg=true, jpeg=true, pdf=true}
local audioExtensions = {m4a=true, mp3=true, aac=true}

local function optional(call, ...)
    local ok, value = pcall(call, ...)
    if ok then return value end
end

local function field(value, name)
    if value == nil then return nil end
    return optional(function() return value[name] end)
end

local function acceptedKey(key, basename, extensions)
    local name = field(key, "name")
    if type(name) ~= "string" then return false end
    local file = name:match("[^/]+$") or ""
    local stem, extension = file:match("^(.+)%.([^%.]+)$")
    stem = stem or file
    extension = extension or field(key, "ext")
    return (stem == basename or stem == basename .. "@2x")
        and type(extension) == "string" and extensions[extension:lower():gsub("^%.", "")]
end

local function inLibrary(library, basename, extensions)
    -- Use Codea's keys, including the full original filename when the project
    -- contains more than one asset with the same basename.
    local key = field(library, basename)
    if acceptedKey(key, basename, extensions) then return key end
    local keys = field(library, "all")
    if type(keys) ~= "table" then return nil end
    local selected, selectedName
    for _, candidate in pairs(keys) do
        if acceptedKey(candidate, basename, extensions) then
            local name = candidate.name
            if not selectedName or name < selectedName then
                selected, selectedName = candidate, name
            end
        end
    end
    return selected
end

local function imported(basename, extensions)
    return inLibrary(asset, basename, extensions)
        or inLibrary(field(asset, "documents"), basename, extensions)
end

function MenuAssets.load()
    local saved = optional(readLocalData, muteKey)
    local logoKey = imported("PolyLaxLogo", imageExtensions)
    local logo
    if logoKey then logo = optional(readImage, logoKey) end
    local width, height = field(logo, "width"), field(logo, "height")
    if type(width) ~= "number" or width <= 0 or type(height) ~= "number" or height <= 0 then
        logo, width, height = nil, nil, nil
    end
    local theme = imported("PolyLaxTheme", audioExtensions)
    return {
        logo=logo, logoWidth=width, logoHeight=height,
        theme=theme, hasTheme=theme ~= nil, muted=saved == true or saved == 1
    }
end

function MenuAssets.drawLogo(menu, x, y, maxWidth, maxHeight)
    if not menu or not menu.logo or maxWidth <= 0 or maxHeight <= 0 then return false end
    local scale = math.min(maxWidth / menu.logoWidth, maxHeight / menu.logoHeight)
    pushStyle()
    local drawn = pcall(function()
        spriteMode(CENTER)
        noTint()
        sprite(menu.logo, x, y, menu.logoWidth * scale, menu.logoHeight * scale)
    end)
    popStyle()
    if not drawn then menu.logo = nil end
    return drawn
end

local function trackName()
    local name = field(music, "name")
    if type(name) == "string" and name ~= "" then return name end
end

function MenuAssets.enter(menu)
    if not menu or menu.muted or not menu.hasTheme or music == nil or trackName() then return false end
    local started = pcall(function() music(menu.theme, true, .48) end)
    menu.playingName = started and trackName() or nil
    return menu.playingName ~= nil
end

function MenuAssets.leave(menu)
    if not menu then return end
    if menu.playingName and menu.playingName == trackName() then
        optional(function() music.stop() end)
    end
    menu.playingName = nil
end

function MenuAssets.toggleMute(menu)
    menu.muted = not menu.muted
    optional(saveLocalData, muteKey, menu.muted and 1 or 0)
    if menu.muted then MenuAssets.leave(menu) end
    return menu.muted
end
