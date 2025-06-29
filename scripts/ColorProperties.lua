-- Avatar color
avatar:color(vectors.hexToRGB("C35444"))

-- Host only instructions
if not host:isHost() then return end

-- Table setup
local c = {}

-- Action variables
c.hover     = vectors.hexToRGB("9A3A3E")
c.active    = vectors.hexToRGB("C35444")
c.primary   = "#C35444"
c.secondary = "#9A3A3E"

-- Return variables
return c