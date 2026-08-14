-- Required scripts
local parts = require("lib.PartsAPI")
local sync  = require("lib.LetThatSyncFig")
local lerp  = require("lib.LerpAPI")
local tail  = require("scripts.Tail")

-- Parts setup
local cecaelia = parts.new(models.Cecaelia)

-- Synced variables setup
local toggle  = sync.new("GlowToggle", true):config()
local dynamic = sync.new("GlowDynamic", false):config()
local water   = sync.new("GlowWater", false):config()
local unique  = sync.new("GlowUnique", false):config()

-- Glowing parts
local glowingParts = cecaelia:createTable(function(part) return part:getName():find("_[gG]low") end)

local glowObjs = {}
for i = 1, #glowingParts do
	glowObjs[i] = {
		part   = glowingParts[i],
		splash = false,
		timer  = 0,
		glow   = lerp.new(toggle.curr and 1 or 0)
	}
end

-- Check if a splash potion is broken near a part
function events.ON_PLAY_SOUND(id, pos, vol, pitch, loop, category, path)
	
	if player:isLoaded() then
		for i = 1, #glowObjs do
			local obj      = glowObjs[i]
			local partPos  = obj.part:getParent():partToWorldMatrix():apply()
			local atPos    = pos < partPos + 1.5 and pos > partPos - 1.5
			local splashID = id == "minecraft:entity.splash_potion.break" or id == "minecraft:entity.lingering_potion.break"
			obj.splash     = atPos and splashID and path
		end
	end
	
end

-- Gradual values
function events.TICK()
	
	-- Arm variables
	local handedness  = player:isLeftHanded()
	local activeness  = player:getActiveHand()
	local leftActive  = not handedness and "OFF_HAND" or "MAIN_HAND"
	local rightActive = handedness and "OFF_HAND" or "MAIN_HAND"
	local leftItem    = player:getHeldItem(not handedness)
	local rightItem   = player:getHeldItem(handedness)
	local using       = player:isUsingItem()
	local drinkingL   = activeness == leftActive and using and leftItem:getUseAction() == "DRINK"
	local drinkingR   = activeness == rightActive and using and rightItem:getUseAction() == "DRINK"
	
	-- Control how fast drying occurs
	local dryRate = player:getItem(1).id == "minecraft:sponge" and 10 or 1
	
	-- Zero check
	local modDryTimer = math.max(tail.dry, 1)
	
	-- Set glow target
	-- Toggle check
	for i = 1, #glowObjs do
		
		-- Get object
		local obj = glowObjs[i]
		
		if toggle.curr and obj.part:getVisible() then
			
			-- Init apply
			obj.glow.target = 1
			
			-- Get pos
			local pos = unique.curr and obj.part:getParent():partToWorldMatrix():apply() or player:getPos()
			
			-- Light level check
			if dynamic.curr then
				
				-- Variable
				local light = math.map(world.getLightLevel(pos), 0, 15, 1, 0)
				
				-- Apply
				obj.glow.target = obj.glow.target * light
				
			end
			
			-- Water check
			if water.curr then
				
				-- Variables
				local wet = false
				
				if unique.curr then
					
					-- Check fluid tags
					local block = world.getBlockState(pos)
					for _, tag in ipairs(block:getFluidTags()) do
						if tag then
							wet = true
							break
						end
					end
					
					-- Check drinking water
					if (drinkingL or drinkingR) and player:getActiveItemTime() > 20
						or world.getRainGradient() > 0.2 and world.isOpenSky(pos) and world.getBiome(pos):getPrecipitation() == "RAIN"
						or obj.splash then
						
						wet = true
						obj.splash = false
						
					end
					
				else
					
					wet = player:isWet() or (drinkingL or drinkingR) and player:getActiveItemTime() > 20
					
				end
				
				-- Adjust timer
				if wet then
					obj.timer = modDryTimer
				else
					obj.timer = math.clamp(obj.timer - 1 * dryRate, 0, modDryTimer)
				end
				
				-- Apply
				obj.glow.target = obj.glow.target * (obj.timer / modDryTimer)
				
			end
			
		else
			
			-- Apply
			obj.glow.target = 0
			
		end
		
		obj.glow.enabled = obj.part:getVisible()
		
	end
	
end

function events.RENDER(delta, context)
	
	-- Check render type
	local renderType = context == "RENDER" and "EMISSIVE" or "EYES"
	
	for i = 1, #glowObjs do
		
		-- Get object
		local obj = glowObjs[i]
		
		-- Apply
		obj.part
			:secondaryColor(obj.glow.currPos)
			:secondaryRenderType(renderType)
		
	end
	
end

-- Apply sound function
local toggleSound = toggle:addFuncs(function()
	if player:isLoaded() and toggle.curr then
		sounds:playSound("entity.glow_squid.ambient", player:getPos(), 0.75)
	end
end)

-- Host only instructions
if not host:isHost() then return end

-- Apply sound functions
local dynamicSound = dynamic:addFuncs(function()
	if player:isLoaded() and dynamic.curr then
		sounds:playSound("entity.generic.drink", player:getPos(), 0.35)
	end
end)
local waterSound = water:addFuncs(function()
	if player:isLoaded() and water.curr then
		sounds:playSound("ambient.underwater.enter", player:getPos(), 0.35)
	end
end)

-- Setup keybind
local keyboundSuccess = pcall(require, "lib.Keybound")
if keyboundSuccess then
	local toggleKeybind = keybinds:newKeybind("Glow Toggle", "key.keyboard.keypad.3")
		:config("GlowToggleKeybind")
		:onPress(function()
			toggle:update(not toggle.curr)
		end)
end

-- Required script
local s, pageNav, acts, colors = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found

-- Pages
local parentPage = action_wheel:getPage("Main")
local glowPage   = action_wheel:newPage("Glow")

-- Actions
acts.glowPage = parentPage:newAction()
	:item("glow_ink_sac")
	:onLeftClick(function() pageNav.descend(glowPage) end)

acts.glowToggle = glowPage:newAction()
	:item("ink_sac")
	:toggleItem("glow_ink_sac")
	:onToggle(function(bool)
		toggle:update(bool)
	end)

acts.glowDynamic = glowPage:newAction()
	:item("light")
	:onToggle(function(bool)
		dynamic:update(bool)
	end)
	:toggled(dynamic.curr)

acts.glowWater = glowPage:newAction()
	:item("bucket")
	:toggleItem("water_bucket")
	:onToggle(function(bool)
		water:update(bool)
	end)
	:toggled(water.curr)

acts.glowUnique = glowPage:newAction()
	:item("prismarine_shard")
	:toggleItem("prismarine_crystals")
	:onToggle(function(bool)
		unique:update(bool)
	end)
	:toggled(unique.curr)

-- Update actions
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		acts.glowPage
			:title(toJson(
				{text = "Glowing Settings", bold = true, color = colors.primary}
			))
			:hoverColor(colors.hover)
		
		acts.glowToggle
			:title(toJson(
				{
					"",
					{text = "Toggle Glowing\n\n", bold = true, color = colors.primary},
					{text = "Toggles glowing for the tail, and misc parts.\n\n", color = colors.secondary},
					{text = "WARNING: ", bold = true, color = "dark_red"},
					{text = "This feature has a tendency to not work correctly.\nDue to the rendering properties of emissives, the tail may not glow.\nIf it does not work, please reload the avatar. Rinse and Repeat.\nThis is the only fix, I have tried everything.\n\n- Total", color = "red"}
				}
			))
			:toggled(toggle.curr)
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
		acts.glowDynamic
			:title(toJson(
				{
					"",
					{text = "Toggle Dynamic Glowing\n\n", bold = true, color = colors.primary},
					{text = "Toggles glowing based on lightlevel.\nThe darker the location, the brighter your tail glows.", color = colors.secondary}
				}
			))
			:toggleItem("light{BlockStateTag:{level:"..math.map(world.getLightLevel(player:getPos()), 0, 15, 15, 0).."}}")
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
		acts.glowWater
			:title(toJson(
				{
					"",
					{text = "Toggle Water Glowing\n\n", bold = true, color = colors.primary},
					{text = "Toggles the glowing sensitivity to water.\nAny water will cause your tail to glow.", color = colors.secondary}
				}
			))
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
		acts.glowUnique
			:title(toJson(
				{
					"",
					{text = "Toggle Unique Glowing\n\n", bold = true, color = colors.primary},
					{text = "Toggles the individual glowing of each part.\nThis relies on the other settings to be noticeable.", color = colors.secondary}
				}
			))
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
	end
	
end