-- Required scripts
local parts = require("lib.PartsAPI")
local sync  = require("lib.LetThatSyncFig")
local tail  = require("scripts.Tail")

-- Parts setup
local cecaelia = parts.new(models.Cecaelia)

-- Stop script if ink group could not be found
local inkPart = cecaelia.outliner.Ink
if not inkPart then return end

-- Synced variables setup
local active   = sync.new("InkActive", false)
local inkColor = sync.new("InkColor", "#27D5AF"):config()

-- Variables
local cooldown = false
local maxInk = 0
local remainingInk = 0
local cooldownTimer = 0

-- Shoots ink
local function shootInk(x)
	
	-- Variables
	x = x or 1
	local pos = inkPart:partToWorldMatrix():apply()
	local blockPos = world.getBlockState(pos)
	if #blockPos:getFluidTags() == 0 then return end
	
	-- Find color
	local calcColor = vectors.hexToRGB(inkColor.curr) * inkPart:getSecondaryColor()
	
	for _ = 1, x do
		
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
	
	if active.curr and largeTail and not cooldown then
		
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
		active:update(false)
		
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

-- Host only instructions
if not host:isHost() then return end

-- Setup keybind
require("lib.Keybound")
local inkKeybind = keybinds:newKeybind("Ink", "key.keyboard.i")
	:config("InkKeybind")
	:onPress(function()
		active:update(true)
	end)
	:onRelease(function()
		active:update(false)
	end)

-- Required script
local lerp = require("lib.LerpAPI")

-- Reenabled parts
cecaelia.outliner.Meter:visible(true)

-- Lerp tables
local fadeLerp = lerp.new()
local barLerp  = lerp.new(0, 0.2, 0.2)

-- Variables
local _maxInk = maxInk
local _atMax = true
local fadeTimer = 100

function events.TICK()
	
	-- Variable
	local atMax = remainingInk == maxInk
	
	-- Decrement timer
	fadeTimer = math.max(fadeTimer - 1, 0)
	
	-- Activate timer
	if inkKeybind:isPressed() or _maxInk ~= maxInk or _atMax ~= atMax or cooldownTimer ~= 0 then
		fadeTimer = 100
	end
	
	-- If maxInk is 0, hide the meter
	if maxInk == 0 then
		fadeTimer = 0
	end
	
	-- If timer reaches 100, fade out, otherwise fade in
	fadeLerp.target = fadeTimer == 0 and 0 or 1
	
	-- Lerp bar scale
	barLerp.target = fadeLerp.target * (maxInk / 20)
	
	-- Bounce bar back if below 0
	if barLerp.currTick < 0 then
		barLerp:bounce(0, 0.85)
	end
	
	-- Store previous variables
	_maxInk = maxInk
	_atMax  = atMax
	
end

function events.RENDER(delta, context)
	
	-- Variables
	local screen = client:getScaledWindowSize()
	local inkLeft = remainingInk / maxInk
	local redBar = math.clamp(inkLeft / 0.5, 0, 1) * 0.5 + 0.5
	
	-- Position Gui parts, set scale, opacity, and color
	cecaelia.outliner.Meter
		:pos(-screen.x + 25, -screen.y * 0.5)
		:scale(2.5)
		:opacity(fadeLerp.currPos)
		:color(1, redBar, redBar)
	
	-- Position middle bar to bottom, scale to top
	cecaelia.outliner.Bar
		:pos(0, -barLerp.currPos / 2)
		:scale(1, barLerp.currPos + 1, 1)
	
	cecaelia.outliner.Bar.Glass
		:setUVMatrix(matrices.mat3():scale(1, barLerp.currPos + 1, 1))
	
	cecaelia.outliner.Bar.Ink
		:scale(1, inkLeft, 1)
		:color(vectors.hexToRGB(inkColor.curr))
		:setUVMatrix(matrices.mat3():scale(1, (barLerp.currPos + 1) * inkLeft, 1))
	
	-- Position cap to top
	cecaelia.outliner.Top:pos(0, barLerp.currPos / 2)
	
	-- Position cap to bottom
	cecaelia.outliner.Bottom:pos(0, -barLerp.currPos / 2)
	
end

-- Required scripts
local s, pageNav, acts, colors = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found
pcall(require, "scripts.ColorChange") -- Tries to find script, not required
pcall(require, "scripts.Tail") -- Tries to find script, not required

-- Variable
local selectedRGB = 1

-- Pages
local parentPage = action_wheel:getPage("Color") or action_wheel:getPage("Octopus") or action_wheel:getPage("Main")

-- Set color channel
local function setColorRGB(x)
	selectedRGB = ((selectedRGB + x - 1) % 3) + 1
end

-- Action
acts.inkColor = parentPage:newAction()
	:item("ink_sac")
	:onLeftClick(function() setColorRGB(1) end)
	:onRightClick(function() setColorRGB(-1) end)
	:onScroll(function(x)
		
		-- Modify color
		local color = vectors.hexToRGB(inkColor.curr)
		color[selectedRGB] = math.clamp(color[selectedRGB] + x/255, 0, 1)
		
		-- Update color
		inkColor:update("#"..vectors.rgbToHex(color):upper(), 20)
		fadeTimer = 0
		
		-- Gross check
		if inkColor.curr == "#FFFFFF" or inkColor.curr == "#FFFF00" then
			host:setActionbar("Shame on you.")
		end
		
	end)

-- Update action
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		
		local rgbInkColor = vectors.hexToRGB(inkColor.curr) * 255
		acts.inkColor
			:title(toJson(
				{
					"",
					{text = "Ink Color\n\n", bold = true, color = colors.primary},
					{text = "Scroll to set the color of your ink.\n\n", color = colors.secondary},
					{text = "Selected RGB: ", bold = true, color = colors.secondary},
					{text = (selectedRGB == 1 and "[%d] "  or "%d " ):format(rgbInkColor.r), color = "red"},
					{text = (selectedRGB == 2 and "[%d] "  or "%d " ):format(rgbInkColor.g), color = "green"},
					{text = (selectedRGB == 3 and "[%d]\n" or "%d\n"):format(rgbInkColor.b), color = "blue"},
					{text = "Selected Hex: ", bold = true, color = colors.secondary},
					{text = inkColor.curr.."\n\n", color = inkColor.curr},
					{text = "Click to change selection.\n\n", color = colors.secondary},
					{text = "Notice:\n", bold = true, color = "gold"},
					{text = "Brighter colors glow. Glowing settings control glowing.", color = "yellow"}
				}
			))
			:hoverColor(colors.hover)
		
	end
	
end