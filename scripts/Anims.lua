-- Required scripts
require("lib.GSAnimBlend")
require("lib.Molang")
local parts   = require("lib.PartsAPI")
local sync    = require("lib.LetThatSyncFig")
local lerp    = require("lib.LerpAPI")
local ground  = require("lib.GroundCheck")
local tail    = require("scripts.Tail")
local pose    = require("scripts.Posing")
local effects = require("scripts.SyncedVariables")

-- Parts setup
local cecaelia = parts.new(models.Cecaelia)

-- Animations setup
local anims = animations.Cecaelia

-- Synced variables setup
local armsMove = sync.new("AnimsArms", false):config()
local isSing   = sync.new("AnimsSing", false)

-- Table setup
v = {}

-- Animation variables
v.strength = 1
v.pitch = 0
v.yaw   = 0
v.roll  = 0

v.tail = 1
v.legs = 1

-- Variables
local waterTimer = 0
local fallTimer = 0

-- Arms setup
local leftArmLerp  = lerp.new(armsMove.curr and 1 or 0, 0.5)
local rightArmLerp = lerp.new(armsMove.curr and 1 or 0, 0.5)

-- Gets the origin rotation of a part, clamped
local function getOriginRot(part, delta)
	return (vanilla_model[part]:getOriginRot(delta) + 180) % 360 - 180
end

-- Parrot pivots
local parrots = {
	
	cecaelia.outliner.LeftParrotPivot,
	cecaelia.outliner.RightParrotPivot
	
}

-- Calculate parent's rotations
local function calculateParentRot(m)
	
	local parent = m:getParent()
	if not parent then
		return m:getTrueRot()
	end
	return calculateParentRot(parent) + m:getTrueRot()
	
end

-- Lerps
local strength = lerp.new(1, 1)
local pitch = lerp.new(0, 0.1)
local yaw   = lerp.new(0, 1)
local roll  = lerp.new(0, 0.1)

-- Spawns notes around a model part
local function notes(part, blocks)
	
	local pos   = part:partToWorldMatrix():apply()
	local range = blocks * 16
	particles["note"]
		:pos(pos + vec(math.random(-range, range)/16, math.random(-range, range)/16, math.random(-range, range)/16))
		:setColor(math.random(51,200)/150, math.random(51,200)/150, math.random(51,200)/150)
		:spawn()
	
end

-- Set staticYaw to Yaw on init
local staticYaw = 0
function events.ENTITY_INIT()
	
	staticYaw = player:getBodyYaw()
	
end

function events.TICK()
	
	-- Variables
	local vel = player:getVelocity()
	local bodyYaw = player:getBodyYaw()
	local dir = vec(math.sin(math.rad(-bodyYaw)), 0, math.cos(math.rad(-bodyYaw)))
	local onGround = ground()
	
	-- Timer settings
	if player:isInWater() or player:isInLava() then
		waterTimer = 20
	else
		waterTimer = math.max(waterTimer - 1, 0)
	end
	
	if onGround or vel.y >= 0 or pose.climb then
		fallTimer = 10
	else
		fallTimer = math.max(fallTimer - 1, 0)
	end
	
	-- Animation variables
	local largeTail = tail.isLarge
	local smallTail = tail.isSmall
	local groundAnim = (onGround or waterTimer == 0) and not (pose.swim or pose.crawl or pose.elytra or pose.spin or pose.sleep or player:getVehicle() or effects.cF)
	
	-- Directional velocity
	local fbVel = vel:dot((dir.x_z):normalized())
	local lrVel = vel:crossed(dir.x_z:normalized()).y
	local udVel = vel.y
	local diagCancel = math.abs(lrVel) - math.abs(fbVel)
	
	-- Static yaw
	staticYaw = math.clamp(staticYaw, bodyYaw - 45, bodyYaw + 45)
	staticYaw = math.lerp(staticYaw, bodyYaw, onGround and math.clamp(vel:length(), 0, 1) or pose.elytra and 0.25 or 0.1)
	local yawDif = staticYaw - bodyYaw
	
	-- Speed control
	local speed     = player:getVehicle() and 1 or pose.crawl and math.clamp(fbVel * 12, -3, 3) or math.min(vel:length() * 1.5, 3) + 0.5
	local landSpeed = math.clamp(fbVel * 4, -2, 2)
	
	-- Animation speeds
	anims.swim:speed(speed)
	anims.walk:speed(landSpeed)
	anims.elytra:speed(speed)
	
	-- Axis controls
	-- X axis control
	if pose.elytra then
		
		-- When using elytra
		pitch.target = math.clamp(-udVel * 20 * (-math.abs(player:getLookDir().y) + 1), -30, 30)
		
	elseif pose.climb or not largeTail or pose.spin then
		
		-- Assumed climbing
		pitch.target = 0
		
	elseif (pose.swim or waterTimer == 0) and not effects.cF then
		
		-- While "swimming" or outside of water
		pitch.target = math.clamp(-udVel * 80 * -(math.abs(player:getLookDir().y * 2) - 1), -30, 30)
		
	else
		
		-- Assumed floating in water
		pitch.target = math.clamp((fbVel + math.max(-udVel, 0) + (math.abs(lrVel) * diagCancel) * 4) * 160, -30, 30)
		
	end
	
	-- Y axis control
	yaw.target = yawDif
	
	-- Z Axis control
	if effects.dG then
		
		-- Dolphin's grace applied
		roll.target = 0
		
	elseif pose.elytra then
		
		-- When using an elytra
		roll.target = math.clamp((-lrVel * 40) - (yawDif * math.clamp(fbVel, -1, 1)), -30, 30)
		
	else
		
		-- Assumed floating in water
		roll.target = math.clamp((-lrVel * diagCancel * 160) - (yawDif * math.clamp(fbVel, -1, 1)), -30, 30)
		
	end
	
	-- Animation states
	local swim   = not (groundAnim or pose.elytra or pose.spin or pose.sleep or player:getVehicle())
	local idle   = largeTail and groundAnim and fallTimer ~= 0
	local walk   = largeTail and groundAnim and vel.xz:length() ~= 0
	local elytra = largeTail and not groundAnim and pose.elytra
	local fall   = groundAnim and fallTimer == 0
	local mount  = largeTail and player:getVehicle()
	local spin   = largeTail and pose.spin
	local sleep  = largeTail and pose.sleep
	local small  = smallTail and not swim
	local sing   = isSing.curr and not pose.sleep
	
	-- Animations
	anims.swim:playing(swim)
	anims.idle:playing(idle)
	anims.walk:playing(walk)
	anims.elytra:playing(elytra)
	anims.fall:playing(fall)
	anims.mount:playing(mount)
	anims.spin:playing(spin)
	anims.sleep:playing(sleep)
	anims.small:playing(small)
	anims.sing:playing(sing)
	
	-- Spawns notes around head while singing
	if sing and world.getTime() % 5 == 0 then
		notes(cecaelia.outliner.Head, 1)
	end
	
	-- Arm variables
	local handedness = player:isLeftHanded()
	local mainL = not handedness and "OFF_HAND" or "MAIN_HAND"
	local mainR = handedness and "OFF_HAND" or "MAIN_HAND"
	local swingL = player:getSwingArm() == mainL
	local swingR = player:getSwingArm() == mainR
	local using = player:isUsingItem()
	local active = player:getActiveHand()
	local itemL = player:getHeldItem(not handedness)
	local itemR = player:getHeldItem(handedness)
	local usingL = using and active == mainL and itemL:getUseAction()
	local usingR = using and active == mainR and itemR:getUseAction()
	local bow = (usingL or usingR or ""):find("BOW") or (itemL:getTag().Charged or itemR:getTag().Charged) == 1
	
	-- Arms movement override
	local armShouldMove = not largeTail
	
	-- Arms movement targets
	leftArmLerp.target  = (armsMove.curr or armShouldMove or swingL or usingL or bow) and 0 or -1
	rightArmLerp.target = (armsMove.curr or armShouldMove or swingR or usingR or bow) and 0 or -1
	
end

function events.RENDER(delta)
	
	-- Store animation variables
	v.strength = strength.currPos
	v.pitch    = pitch.currPos
	v.yaw      = yaw.currPos
	v.roll     = roll.currPos
	
	v.tail = tail.scale
	v.legs = tail.legs
	
	-- Animation blending
	anims.swim:blend(tail.scale * 0.5 + 0.5)
	anims.small:blend(tail.scale * -0.2 + 1)
	
	-- Arm idle rotation
	local idleTimer = world.getTime(delta)
	local idleRot   = vec(math.deg(math.sin(idleTimer * 0.067) * 0.05), 0, math.deg(math.cos(idleTimer * 0.09) * 0.05 + 0.05))
	
	-- Apply arm rotations
	cecaelia.outliner.LeftArm:offsetRot((getOriginRot("LEFT_ARM", delta) + idleRot) * leftArmLerp.currPos)
	cecaelia.outliner.RightArm:offsetRot((getOriginRot("RIGHT_ARM", delta) - idleRot) * rightArmLerp.currPos)
	
	-- Parrot rot offset
	for i = 1, #parrots do
		local parrot = parrots[i]
		parrot:rot(-calculateParentRot(parrot:getParent()) - getOriginRot("BODY", delta))
	end
	
	-- Crouch offset
	local bodyRot = getOriginRot("BODY", delta)
	local crouchPos = vec(0, -math.sin(math.rad(bodyRot.x)) * 2, -math.sin(math.rad(bodyRot.x)) * 12)
	cecaelia.outliner.UpperBody:offsetPivot(crouchPos):pos(crouchPos.xy_ * 2 --[[@as Vector3]])
	cecaelia.outliner.Octopus:pos(crouchPos)
	
	-- Spyglass rotations
	local headRot = getOriginRot("HEAD", delta)
	headRot.x = math.clamp(headRot.x, -90, 30)
	cecaelia.outliner.Spyglass:offsetRot(headRot)
		:pos(pose.crouch and vec(0, -4, 0) or nil)
	
end

-- GS Blending Setup
local blendAnims = {
	{ anim = anims.swim,   ticks = {7,7} },
	{ anim = anims.idle,   ticks = {7,7} },
	{ anim = anims.walk,   ticks = {7,7} },
	{ anim = anims.elytra, ticks = {7,7} },
	{ anim = anims.fall,   ticks = {7,7} },
	{ anim = anims.mount,  ticks = {7,7} },
	{ anim = anims.spin,   ticks = {7,7} },
	{ anim = anims.sleep,  ticks = {7,7} },
	{ anim = anims.small,  ticks = {7,7} },
	{ anim = anims.sing,   ticks = {3,3} }
}

-- Apply GS Blending
for i = 1, #blendAnims do
	local blend = blendAnims[i]
	if blend.anim ~= nil then
		blend.anim:blendTime(table.unpack(blend.ticks)):blendCurve("easeOutQuad")
	end
end

-- Host only instructions
if not host:isHost() then return end

-- Setup keybind
local keyboundSuccess = pcall(require, "lib.Keybound")
if keyboundSuccess then
	keybinds:newKeybind("Singing Animation", "key.keyboard.keypad.5")
		:config("AnimsSingKeybind")
		:onPress(function()
			isSing:update(not isSing.curr)
		end)
end

-- Required script
local s, pageNav, acts, colors = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isn't found

-- Check for if page already exists
local pageExists = action_wheel:getPage("Anims")

-- Pages
local parentPage = action_wheel:getPage("Main")
local animsPage  = pageExists or action_wheel:newPage("Anims")

-- Actions
if not pageExists then
	acts.animsPage = parentPage:newAction()
		:item("jukebox")
		:onLeftClick(function() pageNav.descend(animsPage) end)
end

acts.animsSingToggle = animsPage:newAction()
	:item("music_disc_blocks")
	:toggleItem("music_disc_cat")
	:onToggle(function(bool)
		isSing:update(bool)
	end)

acts.animsArmsToggle = animsPage:newAction()
	:item("red_dye")
	:toggleItem("rabbit_foot")
	:onToggle(function(bool)
		armsMove:update(bool)
	end)
	:toggled(armsMove.curr)

-- Update actions
function events.RENDER()
	
	if action_wheel:isEnabled() then
		if acts.animsPage then
			acts.animsPage
				:title(toJson(
					{text = "Animation Settings", bold = true, color = colors.primary}
				))
				:hoverColor(colors.hover)
		end
		
		acts.animsSingToggle
			:title(toJson(
				{text = "Play Singing animation", bold = true, color = colors.primary}
			))
			:toggled(isSing.curr)
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
		acts.animsArmsToggle
			:title(toJson(
				{
					"",
					{text = "Arm Movement Toggle\n\n", bold = true, color = colors.primary},
					{text = "Toggles the movement swing movement of the arms.\nActions are not effected.", color = colors.secondary}
				}
			))
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
	end
	
end