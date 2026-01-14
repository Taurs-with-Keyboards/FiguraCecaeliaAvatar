-- Required scripts
local sync = require("lib.LetThatSyncFig")
local lerp = require("lib.LerpAPI")

-- Synced variables setup
local camo    = sync.add(config:load("ColorCamo"), false)
local rainbow = sync.add(config:load("ColorRainbow"), false)

-- Variables
local groundTimer = 0
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
local colorLerp = lerp:new(vec(1, 1, 1))
local typeLerp  = lerp:new((sync[camo] or sync[rainbow]) and 1 or 0)

-- Apply color
local function applyColor(tex, color)
	
	local mat = math.lerp(matrices.mat4(), grayMat, typeLerp.currPos)
	
	local dimensions = tex:getDimensions()
	tex:restore():applyMatrix(0, 0, dimensions.x, dimensions.y, mat:scale(color), true):update()
	
end

function events.TICK()
	
	if sync[camo] then
		
		-- Variables
		local pos    = player:getPos()
		local blocks = world.getBlocks(pos - 1, pos + 1)
		local solid = false
		
		-- Check for solid blocks
		for _, block in ipairs(blocks) do
			
			if block:hasCollision() then
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
			local calcOpacity = #blocks
			
			for _, block in ipairs(blocks) do
				
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
		
	elseif sync[rainbow] then
		
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

function events.RENDER(delta, context)
	
	-- Octopus textures
	for _, tex in ipairs(octopusTextures) do
		applyColor(tex, colorLerp.currPos)
	end
	
	-- Glowing outline
	renderer:outlineColor(colorLerp.currPos)
	
	-- Avatar color
	avatar:color(math.lerp(initAvatarColor, colorLerp.currPos, typeLerp.currPos))
	
end

-- Color type toggle
function pings.setColorType(type)
	
	sync[camo]    = type == 1
	sync[rainbow] = type == 2
	
	config:save("ColorCamo", sync[camo])
	config:save("ColorRainbow", sync[rainbow])
	
end

-- Host only instructions
if not host:isHost() then return end

-- Required scripts
local s, wheel, c = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found
pcall(require, "scripts.Tail") -- Tries to find script, not required

-- Dont preform if color properties is empty
if next(c) ~= nil then
	
	-- Store init colors
	local initColors = {}
	for k, v in pairs(c) do
		initColors[k] = v
	end
	
	-- Update action wheel colors
	function events.RENDER(delta, context)
		
		-- Create mermod colors
		local appliedColors = {
			hover     = math.lerp(initColors.hover, colorLerp.currPos, typeLerp.currPos),
			active    = math.lerp(initColors.active, (colorLerp.currPos):applyFunc(function(a) return math.map(a, 0, 1, 0.1, 0.9) end), typeLerp.currPos),
			primary   = "#"..vectors.rgbToHex(math.lerp(vectors.hexToRGB(initColors.primary), colorLerp.currPos, typeLerp.currPos)),
			secondary = "#"..vectors.rgbToHex(math.lerp(vectors.hexToRGB(initColors.secondary), (colorLerp.currPos):applyFunc(function(a) return math.map(a, 0, 1, 0.1, 0.9) end), typeLerp.currPos))
		}
		
		-- Update action wheel colors
		for k in pairs(c) do
			c[k] = appliedColors[k]
		end
		
	end
	
end

-- Pages
local parentPage = action_wheel:getPage("Octopus") or action_wheel:getPage("Main")
local colorPage  = action_wheel:newPage("Color")

-- Actions table setup
local a = {}

-- Actions
a.pageAct = parentPage:newAction()
	:item("brewing_stand")
	:onLeftClick(function() wheel:descend(colorPage) end)

a.camoAct = colorPage:newAction()
	:item("glass_bottle")
	:onToggle(function(apply) pings.setColorType(apply and 1) end)

a.rainbowAct = colorPage:newAction()
	:item("glass_bottle")
	:onToggle(function(apply) pings.setColorType(apply and 2) end)

-- Update actions
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		a.pageAct
			:title(toJson(
				{text = "Color Settings", bold = true, color = c.primary}
			))
		
		a.camoAct
			:title(toJson(
				{
					"",
					{text = "Toggle Camo Mode\n\n", bold = true, color = c.primary},
					{text = "Toggles changing your octopus color to match your surroundings.", color = c.secondary}
				}
			))
			:toggleItem("splash_potion{CustomPotionColor:" .. tostring(vectors.rgbToInt(colorLerp.currPos)) .. "}")
			:toggled(sync[camo])
		
		a.rainbowAct
			:title(toJson(
				{
					"",
					{text = "Toggle Rainbow Mode\n\n", bold = true, color = c.primary},
					{text = "Toggles on hue-shifting creating a rainbow effect.", color = c.secondary}
				}
			))
			:toggleItem("lingering_potion{CustomPotionColor:" .. tostring(vectors.rgbToInt(colorLerp.currPos)) .. "}")
			:toggled(sync[rainbow])
		
		for _, act in pairs(a) do
			act:hoverColor(c.hover):toggleColor(c.active)
		end
		
	end
	
end