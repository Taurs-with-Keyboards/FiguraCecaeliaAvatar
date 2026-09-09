-- Required scripts
local sync = require("lib.LetThatSyncFig")
local lerp = require("lib.LerpAPI")

-- Synced variables setup
local camo    = sync.new("ColorCamo", false):config()
local rainbow = sync.new("ColorRainbow", false):config()

-- Variables
local initAvatarColor = vectors.hexToRGB(avatar:getColor() or "default")
local grayMat = matrices.mat4(
	vec(0.5, 0.5, 0.5, 0),
	vec(0.5, 0.5, 0.5, 0),
	vec(0.5, 0.5, 0.5, 0),
	vec(0, 0, 0, 1)
)

-- Textures
local octopusTextures = {
	
	textures["textures.octopus"]   or textures["Cecaelia.octopus"],
	textures["textures.octopus_e"] or textures["Cecaelia.octopus_e"]
	
}

-- Lerps
local colorLerp = lerp.new(vec(1, 1, 1))
local typeLerp  = lerp.new((camo.curr or rainbow.curr) and 1 or 0)

-- Apply color
local function applyColor(tex, color)
	
	local mat = math.lerp(matrices.mat4(), grayMat, typeLerp.currPos)
	
	local dimensions = tex:getDimensions()
	tex:restore():applyMatrix(0, 0, dimensions.x, dimensions.y, mat:scale(color), true):update()
	
end

function events.TICK()
	
	if camo.curr then
		
		-- Variables
		local pos    = player:getPos()
		local blocks = world.getBlocks(pos - 1, pos + 1)
		local solid = false
		
		-- Check for solid blocks
		for i = 1, #blocks do
			
			if blocks[i]:hasCollision() then
				solid = true
				break
			end
			
		end
		
		-- Gather blocks
		for i = #blocks, 1, -1 do
			
			local block = blocks[i]
			
			if block:isAir() or solid and block.id == "minecraft:water" then
				table.remove(blocks, i)
			end	
			
		end
		
		if #blocks ~= 0 then
			
			-- Init colors
			local calcColor   = vectors.vec3()
			
			for i = 1, #blocks do
				
				-- Get block
				local block = blocks[i]
				
				-- Gather colors
				if block.id == "minecraft:water" then
					calcColor = calcColor + world.getBiome(block:getPos()):getWaterColor()
				else
					calcColor = calcColor + block:getMapColor()
				end
				
			end
			
			-- Find average
			colorLerp.target = calcColor / #blocks
			typeLerp.target  = 1
			
		else
			
			-- Set to default
			colorLerp.target = vec(1, 1, 1)
			typeLerp.target  = 0
			
		end
		
	elseif rainbow.curr then
		
		-- Set to RGB
		local calcColor = world.getTime() % 360 / 360
		colorLerp.target = vectors.hsvToRGB(calcColor, 1, 1)
		typeLerp.target  = 1
		
	else
		
		-- Set to default
		colorLerp.target = vec(1, 1, 1)
		typeLerp.target  = 0
		
	end
	
end

function events.RENDER()
	
	-- Stops useless instructions
	if client:isPaused() then return end
	
	-- Octopus textures
	for i = 1, #octopusTextures do
		applyColor(octopusTextures[i], colorLerp.currPos)
	end
	
	-- Glowing outline
	renderer:outlineColor(colorLerp.currPos)
	
	-- Avatar color
	avatar:color(math.lerp(initAvatarColor, colorLerp.currPos, typeLerp.currPos))
	
end

-- Host only instructions
if not host:isHost() then return end

-- Required scripts
local s, pageNav, acts, colors = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isn't found
pcall(require, "scripts.Tail") -- Tries to find script, not required

-- Don't preform if color properties is empty
if next(colors) ~= nil then
	
	-- Store init colors
	local initColors = {}
	for k, v in pairs(colors) do
		initColors[k] = v
	end
	
	-- Update action wheel colors
	function events.RENDER()
		
		if action_wheel:isEnabled() then
			
			-- Create mermod colors
			local appliedColors = {
				hover     = math.lerp(initColors.hover, colorLerp.currPos, typeLerp.currPos),
				active    = math.lerp(initColors.active, math.map(colorLerp.currPos, 0, 1, 0.1, 0.9), typeLerp.currPos),
				primary   = "#"..vectors.rgbToHex(math.lerp(vectors.hexToRGB(initColors.primary), colorLerp.currPos, typeLerp.currPos)),
				secondary = "#"..vectors.rgbToHex(math.lerp(vectors.hexToRGB(initColors.secondary), math.map(colorLerp.currPos, 0, 1, 0.1, 0.9), typeLerp.currPos))
			}
			
			-- Update action wheel colors
			for k in pairs(colors) do
				colors[k] = appliedColors[k]
			end
			
		end
		
	end
	
end

-- Pages
local parentPage = action_wheel:getPage("Octopus") or action_wheel:getPage("Main")
local colorPage  = action_wheel:newPage("Color")

-- Actions
acts.colorPage = parentPage:newAction()
	:item("brewing_stand")
	:onLeftClick(function() pageNav.descend(colorPage) end)

acts.colorCamoToggle = colorPage:newAction()
	:item("glass_bottle")
	:onToggle(function(bool)
		camo:update(bool)
		rainbow:update(false)
	end)

acts.colorRainbowToggle = colorPage:newAction()
	:item("glass_bottle")
	:onToggle(function(bool)
		rainbow:update(bool)
		camo:update(false)
	end)

-- Update actions
function events.RENDER()
	
	if action_wheel:isEnabled() then
		acts.colorPage
			:title(toJson(
				{text = "Color Settings", bold = true, color = colors.primary}
			))
			:hoverColor(colors.hover)
		
		acts.colorCamoToggle
			:title(toJson(
				{
					"",
					{text = "Toggle Camo Mode\n\n", bold = true, color = colors.primary},
					{text = "Toggles changing your octopus color to match your surroundings.", color = colors.secondary}
				}
			))
			:toggleItem("splash_potion{CustomPotionColor:" .. tostring(vectors.rgbToInt(colorLerp.currPos)) .. "}")
			:toggled(camo.curr)
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
		acts.colorRainbowToggle
			:title(toJson(
				{
					"",
					{text = "Toggle Rainbow Mode\n\n", bold = true, color = colors.primary},
					{text = "Toggles on hue-shifting creating a rainbow effect.", color = colors.secondary}
				}
			))
			:toggleItem("lingering_potion{CustomPotionColor:" .. tostring(vectors.rgbToInt(colorLerp.currPos)) .. "}")
			:toggled(rainbow.curr)
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
	end
	
end