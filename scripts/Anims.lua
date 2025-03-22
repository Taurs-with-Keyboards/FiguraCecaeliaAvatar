-- Required scripts
require("lib.GSAnimBlend")
require("lib.Molang")
local parts   = require("lib.PartsAPI")
local lerp    = require("lib.LerpAPI")
local ground  = require("lib.GroundCheck")
local tail    = require("scripts.Tail")
local pose    = require("scripts.Posing")
local effects = require("scripts.SyncedVariables")

-- Animations setup
local anims = animations.Cecaelia

-- Table setup
v = {}

-- Animation variables
v.strength = 1
v.pitch = 0
v.yaw   = 0
v.roll  = 0

v.tail   = 1 - tail.legs
v.height = 1 - tail.height

-- Variables
local waterTimer = 0
local fallTimer = 0
local isSing = false

-- Parrot pivots
local parrots = {
	
	parts.group.LeftParrotPivot,
	parts.group.RightParrotPivot
	
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
local strength = lerp:new(1)
local pitch = lerp:new(0.1)
local yaw   = lerp:new(1)
local roll  = lerp:new(0.1)

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
	
	-- Player variables
	local vel      = player:getVelocity()
	local dir      = player:getLookDir()
	local bodyYaw  = player:getBodyYaw()
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
	local fbVel = player:getVelocity():dot((dir.x_z):normalize())
	local lrVel = player:getVelocity():cross(dir.x_z:normalize()).y
	local udVel = player:getVelocity().y
	local diagCancel = math.abs(lrVel) - math.abs(fbVel)
	
	-- Static yaw
	staticYaw = math.clamp(staticYaw, bodyYaw - 45, bodyYaw + 45)
	staticYaw = math.lerp(staticYaw, bodyYaw, onGround and math.clamp(vel:length(), 0, 1) or pose.elytra and 0.25 or 0.1)
	local yawDif = staticYaw - bodyYaw
	
	-- Speed control
	local speed     = player:getVehicle() and 1 or pose.crawl and math.clamp(fbVel < -0.05 and math.min(fbVel, math.abs(lrVel)) * 12 or math.max(fbVel, math.abs(lrVel)) * 12, -3, 3) or math.min(vel:length() * 1.5, 3) + 0.5
	local landSpeed = math.clamp(fbVel < -0.05 and math.min(fbVel, math.abs(lrVel)) * 4 or math.max(fbVel, math.abs(lrVel)) * 4, -2, 2)
	
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
	local sing   = isSing and not pose.sleep
	
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
	if isSing and world.getTime() % 5 == 0 then
		notes(parts.group.Head, 1)
	end
	
end

function events.RENDER(delta, context)
	
	-- Store animation variables
	v.strength = strength.currPos
	v.pitch    = pitch.currPos
	v.yaw      = yaw.currPos
	v.roll     = roll.currPos
	
	v.tail   = 1 - tail.legs
	v.height = 1 - tail.height
	
	-- Animation blending
	anims.swim:blend(tail.scale * 0.5 + 0.5)
	anims.small:blend(tail.smallSize * -0.2 + 1)
	
	-- Parrot rot offset
	for _, parrot in pairs(parrots) do
		parrot:rot(-calculateParentRot(parrot:getParent()) - vanilla_model.BODY:getOriginRot())
	end
	
	-- Crouch offset
	local bodyRot = vanilla_model.BODY:getOriginRot(delta)
	local crouchPos = vec(0, -math.sin(math.rad(bodyRot.x)) * 2, -math.sin(math.rad(bodyRot.x)) * 12)
	parts.group.UpperBody:offsetPivot(crouchPos):pos(crouchPos.xy_ * 2)
	parts.group.Octopus:pos(crouchPos)
	
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
for _, blend in ipairs(blendAnims) do
	blend.anim:blendTime(table.unpack(blend.ticks)):blendCurve("easeOutQuad")
end

-- Fixing spyglass jank
function events.RENDER(delta, context)
	
	local rot = vanilla_model.HEAD:getOriginRot()
	rot.x = math.clamp(rot.x, -90, 30)
	parts.group.Spyglass:offsetRot(rot)
		:pos(pose.crouch and vec(0, -4, 0) or nil)
	
end

-- Singing anim toggle
function pings.setAnimSing(boolean)
	
	isSing = boolean
	
end

-- Sync variables
function pings.syncAnims(a)
	
	isSing = a
	
end

-- Host only instructions
if not host:isHost() then return end

-- Required scripts
local itemCheck = require("lib.ItemCheck")
local s, c = pcall(require, "scripts.ColorProperties")
if not s then c = {} end

-- Sing keybind
local singBind   = config:load("AnimSingKeybind") or "key.keyboard.keypad.7"
local setSingKey = keybinds:newKeybind("Singing Animation"):onPress(function() pings.setAnimSing(not isSing) end):key(singBind)

-- Keybind updaters
function events.TICK()
	
	local singKey  = setSingKey:getKey()
	if singKey ~= singBind then
		singBind = singKey
		config:save("AnimSingKeybind", singKey)
	end
	
end

-- Sync on tick
function events.TICK()
	
	if world.getTime() % 200 == 0 then
		pings.syncAnims(isSing)
	end
	
end

-- Table setup
local t = {}

-- Action
t.singAct = action_wheel:newAction()
	:item(itemCheck("music_disc_blocks"))
	:toggleItem(itemCheck("music_disc_cat"))
	:onToggle(pings.setAnimSing)

-- Update action
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		t.singAct
			:title(toJson
				{text = "Play Singing animation", bold = true, color = c.primary}
			)
			:toggled(isSing)
		
		for _, act in pairs(t) do
			act:hoverColor(c.hover):toggleColor(c.active)
		end
		
	end
	
end

-- Returns action
return t