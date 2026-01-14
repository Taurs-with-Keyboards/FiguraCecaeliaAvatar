-- Required scripts
local parts = require("lib.PartsAPI")
local sync  = require("lib.LetThatSyncFig")
local tail  = require("scripts.Tail")

-- Disables code if script cannot find `parts.group.Ink` or related groups
local inkPart = table.unpack(parts:createTable(function(part) return part:getName():find("Ink") end, 1))
if not inkPart then return {} end

-- Synced variables setup
local inkColor = sync.add(config:load("InkColor"), vectors.hexToRGB("27D5AF"))

-- Variables
local active = false
local cooldown = false
local maxInk = 0
local remainingInk = 0
local cooldownTimer = 0
local selectedRGB = 0

-- Shoots ink
local function shootInk(x)
	
	-- Variables
	x = x or 1
	local pos = inkPart:partToWorldMatrix():apply()
	local blockPos = world.getBlockState(pos)
	if #blockPos:getFluidTags() == 0 then return end
	
	-- Find color
	local calcColor = sync[inkColor] * inkPart:getSecondaryColor()
	
	for i = 1, x do
		
		-- Find angle with variation
		local ang = inkPart:partToWorldMatrix()
			:applyDir(
				math.random() * 6 - 3,
				math.random() * 6 - 6.25,
				math.random() * 6 - 3
			)
		
		-- Create particle
		particles["squid_ink"]
			:pos(pos)
			:velocity(ang)
			:scale(math.random() * 1.5 + 1)
			:color(calcColor)
			:lifetime(math.random(100, 300))
			:physics(true)
			:gravity(0.025)
			:spawn()
		
	end
	
	-- Subtract used from amount left
	remainingInk = math.clamp(remainingInk - x, 0, maxInk)
	
end

function events.ENTITY_INIT()
	
	-- On init, set variables
	maxInk = math.min(player:getExperienceLevel(), 50) * 15
	remainingInk = maxInk
	
end

function events.TICK()
	
	-- Maximum ink the player can hold
	maxInk = math.min(player:getExperienceLevel(), 50) * 15
	
	-- Tail scale
	local largeTail = tail.isLarge
	
	if active and largeTail and not cooldown then
		
		-- Check if there is ink
		if maxInk ~= 0 then
			
			-- How much ink is used each tick, decreasing based on how much is left
			local calc = math.ceil(remainingInk / 50)
			shootInk(calc)
			
		else
			
			-- Inform user that they are too low level to shoot ink
			host:setActionbar("You have too low experience to shoot ink!")
			
		end
		
	elseif cooldownTimer == 0 then
		
		-- Gradually increase ink when not using it
		remainingInk = math.clamp(remainingInk + 1, 0, maxInk)
		cooldown = false
		
	end
	
	-- If no ink, activate cooldown
	if remainingInk == 0 and maxInk ~= 0 and not cooldown then
		
		cooldown = true
		active   = false
		
		cooldownTimer = 100
		
	end
	
	-- Reduce cooldown timer
	cooldownTimer = math.max(cooldownTimer - 1, 0)
	
end

function events.ON_PLAY_SOUND(id, pos, vol, pitch, loop, cat, path)
	
	-- Don't trigger if the sound was played by Figura (prevent potential infinite loop)
	if not path then return end
	
	-- Don't do anything if the user isn't loaded
	if not player:isLoaded() then return end
	
	-- Make sure the sound is (most likely) played by the user
	if (player:getPos() - pos):length() > 0.05 then return end
	
	-- If sound contains ".hurt", play an additional hurt sound along side it
	if id:find(".hurt") then
		
		-- How much ink is used, decreasing based on how much is left
		local calc = math.ceil(remainingInk / 50)
		shootInk(calc)
		
		-- Subtract used from amount left
		remainingInk = math.clamp(remainingInk - calc, 0, maxInk)
		
	end
	
end

-- Toggle ink
function pings.inkKey(x)
	
	active = x
	
end

-- Choose color function
local function pickColor(x)
	
	x = x/255
	sync[inkColor][selectedRGB+1] = math.clamp(sync[inkColor][selectedRGB+1] + x, 0, 1)
	
	config:save("InkColor", sync[inkColor])
	
	if sync[inkColor] == vec(1, 1, 1) or sync[inkColor] == vec(1, 1, 0) then
		host:setActionbar("Shame on you.")
	end
	
end

-- Swaps selected rgb value
local function selectRGB()
	
	selectedRGB = (selectedRGB + 1) % 3
	
end

-- Host only instructions
if not host:isHost() then return end

-- Keybinds
local inkKeybind = keybinds:newKeybind("Ink", "key.keyboard.i")
	:onPress(function() pings.inkKey(true) end)
	:onRelease(function() pings.inkKey(false) end)

-- Sync config keybinds
sync.keybind(inkKeybind, "InkKeybind")

-- Required script
local lerp = require("lib.LerpAPI")

-- Reenabled parts
parts.group.Meter:visible(true)

-- Lerp tables
local fadeLerp = lerp:new()
local barLerp  = lerp:new(0, 0.2, 0.2)

-- Variables
local pMaxInk = maxInk
local wasMax, isMax = true, true
local pInkColor = sync[inkColor]:length()
local fadeTimer = 100

function events.TICK()
	
	-- Variables
	isMax = remainingInk == maxInk
	
	-- Adjust timer based on active
	fadeTimer = (
		active
		or pMaxInk ~= maxInk
		or wasMax ~= isMax
		or pInkColor ~= sync[inkColor]:length()
		or cooldownTimer ~= 0
	) and 0 or math.min(fadeTimer + 1, 100)
	
	-- If maxInk is 0, hide the meter
	if maxInk == 0 then
		fadeTimer = 100
	end
	
	-- If timer reaches 100, fade out, otherwise fade in
	fadeLerp.target = fadeTimer == 100 and 0 or 1
	
	-- Lerp bar scale
	barLerp.target = fadeLerp.target * (maxInk / 20)
	
	-- Bounce bar back if below 0
	if barLerp.currTick < 0 then
		barLerp:bounce(0)
	end
	
	-- Store previous variables
	pMaxInk   = maxInk
	wasMax    = isMax
	pInkColor = sync[inkColor]:length()
	
end

function events.RENDER(delta, context)
	
	-- Variables
	local screen = client:getScaledWindowSize()
	local inkLeft = remainingInk / maxInk
	local redBar = math.clamp(inkLeft / 0.5, 0, 1) * 0.5 + 0.5
	
	-- Position Gui parts, set scale, opacity, and color
	parts.group.Meter
		:pos(-screen.x + 25, -screen.y * 0.5)
		:scale(2.5)
		:opacity(fadeLerp.currPos)
		:color(1, redBar, redBar)
	
	-- Position middle bar to bottom, scale to top
	parts.group.Bar
		:pos(0, -barLerp.currPos / 2)
		:scale(1, barLerp.currPos + 1, 1)
	
	parts.group.Bar.Glass
		:setUVMatrix(matrices.mat3():scale(1, barLerp.currPos + 1, 1))
	
	parts.group.Bar.Ink
		:scale(1, inkLeft, 1)
		:color(sync[inkColor])
		:setUVMatrix(matrices.mat3():scale(1, (barLerp.currPos + 1) * inkLeft, 1))
	
	-- Position cap to top
	parts.group.Top:pos(0, barLerp.currPos / 2)
	
	-- Position cap to bottom
	parts.group.Bottom:pos(0, -barLerp.currPos / 2)
	
end

-- Required scripts
local s, wheel, c = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found
pcall(require, "scripts.ColorChange") -- Tries to find script, not required
pcall(require, "scripts.Tail") -- Tries to find script, not required

-- Pages
local parentPage = action_wheel:getPage("Color") or action_wheel:getPage("Octopus") or action_wheel:getPage("Main")

-- Actions table setup
local a = {}

-- Action
a.colorAct = parentPage:newAction()
	:item("ink_sac")
	:onLeftClick(selectRGB)
	:onScroll(pickColor)

-- Update action
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		a.colorAct
			:title(toJson(
				{
					"",
					{text = "Ink Color\n\n", bold = true, color = c.primary},
					{text = "Scroll to set the color of your ink.\n\n", color = c.secondary},
					{text = "Selected RGB: ", bold = true, color = c.secondary},
					{text = (selectedRGB == 0 and "[%d] "  or "%d " ):format(sync[inkColor][1] * 255), color = "red"},
					{text = (selectedRGB == 1 and "[%d] "  or "%d " ):format(sync[inkColor][2] * 255), color = "green"},
					{text = (selectedRGB == 2 and "[%d]\n" or "%d\n"):format(sync[inkColor][3] * 255), color = "blue"},
					{text = "Selected Hex: ", bold = true, color = c.secondary},
					{text = vectors.rgbToHex(sync[inkColor]).."\n\n", color = "#"..vectors.rgbToHex(sync[inkColor])},
					{text = "Click to change selection.\n\n", color = c.secondary},
					{text = "Notice:\n", bold = true, color = "gold"},
					{text = "Brighter colors glow. Glowing settings control glowing.", color = "yellow"}
				}
			))
		
		for _, act in pairs(a) do
			act:hoverColor(c.hover):toggleColor(c.active)
		end
		
	end
	
end