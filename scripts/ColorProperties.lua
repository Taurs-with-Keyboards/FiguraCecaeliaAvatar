-- Avatar color
avatar:color(vectors.hexToRGB("#C35444"))

-- Host only instructions
if not host:isHost() then return end

-- Table setup
local colors = {}

-- Action variables
colors.hover     = vectors.hexToRGB("#9A3A3E")
colors.active    = vectors.hexToRGB("#C35444")
colors.primary   = "#C35444"
colors.secondary = "#9A3A3E"

-- Return variables
return colors