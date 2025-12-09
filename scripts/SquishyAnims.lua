-- Kills script if squAPI cannot be found
local s, squapi = pcall(require, "lib.SquAPI")
if not s then return {} end

-- Required scripts
local parts     = require("lib.PartsAPI")
local squAssets = require("lib.SquAssets")
local tailScale = require("scripts.Tail")
local effects   = require("scripts.SyncedVariables")

-- Animation setup
local anims = animations.Cecaelia

-- Calculate parent's rotations
local function calculateParentRot(m)
	
	local parent = m:getParent()
	if not parent then
		return m:getOffsetRot()
	end
	return calculateParentRot(parent) + m:getOffsetRot()
	
end

-- Tails table
local tailParts = {
	
	parts.group.Ten1Seg1,
	parts.group.Ten1Seg2,
	parts.group.Ten1Seg3,
	parts.group.Ten1Seg4,
	parts.group.Ten1Seg5,
	parts.group.Ten1Seg6
	
}

-- Squishy tail
local tail = squapi.tail:new(
	tailParts,
	7.5,   -- Intensity X (0)
	0,     -- Intensity Y (0)
	0.8,   -- Speed X (0)
	0,     -- Speed Y (0)
	0.5,   -- Bend (0.5)
	0,     -- Velocity Push (0)
	0,     -- Initial Offset (0)
	0,     -- Seg Offset (0)
	0.025, -- Stiffness (0.025)
	0.975, -- Bounce (0.975)
	0,     -- Fly Offset (0)
	-15,   -- Down Limit (-15)
	25     -- Up Limit (25)
)

-- Tail strength variables
local tailXIntense  = tail.idleXMovement
local tailXSpeed    = tail.idleXSpeed
local tailStrength  = tail.bendStrength

-- Head table
local headParts = {
	
	parts.group.UpperBody
	
}

-- Squishy smooth torso
local head = squapi.smoothHead:new(
	headParts,
	0.3,  -- Strength (0.3)
	0.4,  -- Tilt (0.4)
	1,    -- Speed (1)
	false -- Keep Original Head Pos (false)
)

local headStrength = head.strength[1] * #head.strength

-- Force load before setting up animation variable
require("scripts.Anims")
v.bounce = 0

-- Animation variable
local bounce = squAssets.BERP:new(0.05, 0.9)
bounce.target = 0

function events.TICK()
	
	-- Control the intensity of the tail function based on its scale
	local scale = tailScale.isSmall and 1 or 0
	
	for i in ipairs(head.strength) do
		head.strength[i] = (headStrength / #head.strength) * (1 - tailScale.legs)
	end
	
	tail.idleXMovement = scale * tailXIntense
	tail.idleXSpeed    = scale * tailXSpeed
	tail.bendStrength  = scale * tailStrength
	
	bounce.target = math.clamp(player:getVelocity().y * 80 - (player:getPose() == "CROUCHING" and 20 or 0), -60, 30)
	
end

function events.RENDER(delta, context)
	
	-- Adjust tail rotations
	for _, part in ipairs(tailParts) do
		local rot = part:getOffsetRot()
		part:offsetRot(-rot.x, rot.y, rot.z)
	end
	
	-- Apply all tail rotations to every other segment
	for i = 2, 8 do
		for j, part in ipairs(tailParts) do
			parts.group["Ten"..i.."Seg"..j]:offsetRot(part:getOffsetRot())
		end
	end
	
	-- Variables
	local vanLeftLeg  = vanilla_model.LEFT_LEG:getOriginRot().x  * tailScale.legs
	local vanRightLeg = vanilla_model.RIGHT_LEG:getOriginRot().x * tailScale.legs
	local legLimit    = 25 + tailScale.scale * 25
	
	-- Offset smooth torso in various parts
	-- Note: acts strangely with `parts.group.body`
	for _, group in ipairs(parts.group.UpperBody:getChildren()) do
		if group ~= parts.group.Body then
			group:rot(-calculateParentRot(group:getParent()))
		end
	end
	
	-- Tentacle adjustments
	parts.group.Ten1Seg1:offsetRot(
		parts.group.Ten1Seg1:getOffsetRot() +
		vec(math.max(vanRightLeg, legLimit) - legLimit, 0, 0)
	)
	parts.group.Ten4Seg1:offsetRot(
		parts.group.Ten4Seg1:getOffsetRot() -
		vec(math.min(vanRightLeg, -legLimit) + legLimit, 0, 0)
	)
	parts.group.Ten8Seg1:offsetRot(
		parts.group.Ten8Seg1:getOffsetRot() +
		vec(math.max(vanLeftLeg, legLimit) - legLimit, 0, 0)
	)
	parts.group.Ten5Seg1:offsetRot(
		parts.group.Ten5Seg1:getOffsetRot() -
		vec(math.min(vanLeftLeg, -legLimit) + legLimit, 0, 0)
	)
	
	-- Calculate bounce variable
	v.bounce = bounce:berp(bounce.target, delta)
	
end