-- Optional project art and audio for the front menu.
PolyLax = PolyLax or {}
local MenuAssets = {}
PolyLax.MenuAssets = MenuAssets

local muteKey = "PolyLax.MenuMusicMuted.1"

local function optional(call, ...)
    local ok, value = pcall(call, ...)
    if ok then return value end
end

local function field(value, name)
    if value == nil then return nil end
    return optional(function() return value[name] end)
end

function MenuAssets.load()
    local saved = optional(readLocalData, muteKey)
    local logoKey = optional(function() return asset.logo end)
    local logo
    if logoKey then logo = optional(readImage, logoKey) end
    local width, height = field(logo, "width"), field(logo, "height")
    if type(width) ~= "number" or width <= 0 or type(height) ~= "number" or height <= 0 then
        logo, width, height = nil, nil, nil
    end
    local theme = optional(function() return asset.Main_Menu_Melody end)
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
    if not menu or menu.muted or not menu.hasTheme or music == nil then return false end
    local current = trackName()
    if current then return current == menu.playingName end
    local started = pcall(function() music(menu.theme, true, .48) end)
    menu.playingName = started and trackName() or nil
    local duration = menu.playingName and field(music, "duration")
    if menu.resumeTime and type(duration) == "number" and duration > 0 then
        optional(function() music.currentTime = menu.resumeTime % duration end)
    end
    if not menu.playingName then menu.hasTheme = false end
    return menu.playingName ~= nil
end

function MenuAssets.leave(menu)
    if not menu then return end
    if menu.playingName and menu.playingName == trackName() then
        local cursor = field(music, "currentTime")
        if type(cursor) == "number" and cursor >= 0 and cursor < math.huge then
            menu.resumeTime = cursor
        end
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
