-- LerpAPI
-- By:
--   _________  ________  _________  ________  ___
--  |\___   ___\\   __  \|\___   ___\\   __  \|\  \
--  \|___ \  \_\ \  \|\  \|___ \  \_\ \  \|\  \ \  \
--       \ \  \ \ \  \\\  \   \ \  \ \ \   __  \ \  \
--        \ \  \ \ \  \\\  \   \ \  \ \ \  \ \  \ \  \____
--         \ \__\ \ \_______\   \ \__\ \ \__\ \__\ \_______\
--          \|__|  \|_______|    \|__|  \|__|\|__|\|_______|
--
-- Version: 1.2.12

-- An API for handling the creation of Lerp Objects.
---@class LerpAPI
local lerpAPI = {}

-- A lerp object.
---@class LerpObject
-- The previous tick of the lerp object, before the next tick calculation is made.
---@field prevTick unknown
-- The current tick calculation of the lerp object.
---@field currTick unknown
-- The current position of the lerp object.
---@field currPos unknown
-- The target of the lerp object.
---@field target unknown
-- How fast the lerps `currTick` is heading towards its target. Its velocity.
---@field vel unknown
-- How fast the lerp moves towards its target (in percentage each tick).
---@field stiff number
-- How much a lerp is allowed to bounce around its target.
---@field damp number
-- How long it takes for the object to change velocity.
---@field mass number
-- Toggles the updating of the lerp object.
---@field enabled boolean
local lerpObject = {}

-- A table that holds the lerp objects.
---@type table<LerpObject, boolean>
local lerps = {}

-- The metatable for lerp objects.
local lerpMeta = {
	__index = lerpObject,
	__type = "LerpObject"
}

-- Mass checker that errors if mass is 0.
---@param mass number #
-- Number that is checked for validity in the context of spring physics.
local function massCheck(mass)
	return mass == 0 and error("\n\n§6Mass cannot be 0.\n§c", 3) or mass
end

-- Creates a lerp object.
---@param initPos? number | Vector.any | Matrix.any #
-- The initial position of the lerp.  
-- Can be a number, vector, or matrix.  
-- Defaults to `0`.
---@param stiff? number #
-- How fast the lerp moves towards its target (in percentage each tick).  
-- `0` will never approach the target.  
-- `1` will reach the target within the tick.  
-- Defaults to `0.2`.
---@param damp? number #
-- How much a lerp is allowed to bounce around its target.  
-- `0` will never reach its target due to bouncing.  
-- `1` wont bounce around the target.  
-- Defaults to `1`.
---@param mass? number #
-- How long it takes for the object to change velocity.  
-- Cannot have a mass of `0`, otherwise divide by `0` errors will occur.  
-- You can *still* do `0` by changing it in field, but ur asking for issues at that point.  
-- Defaults to `1`.
---@nodiscard
function lerpAPI.new(initPos, stiff, damp, mass)
	
	-- Create object
	initPos = initPos or 0.0
	local obj = setmetatable(
		{
			prevTick = initPos,
			currTick = initPos,
			currPos  = initPos,
			target   = initPos,
			vel      = type(initPos) ~= "number" and initPos:copy():reset() --[[@as number | Vector.any | Matrix.any]] or 0,
			stiff    = stiff or 0.2,
			damp     = damp or 1,
			mass     = massCheck(mass) or 1,
			enabled  = true
		},
		lerpMeta
	)
	
	-- Add object to table
	lerps[obj] = true
	
	-- Return object
	return obj
	
end

-- This tick event iterates through the lerps table, and preforms spring calculations.  
-- Only preforms calculations on enabled lerps if the game is unpaused.
events.TICK:register(function()
	if not client:isPaused() then
		for obj in pairs(lerps) do
			if obj.enabled then
				
				-- Store previous ticks
				obj.prevTick = obj.currTick
				
				-- Calculate spring physics
				local fSpring = -obj.stiff * (obj.currTick - obj.target)
				local fDamp   = -obj.damp * obj.vel
				local acc     = (fSpring + fDamp) / obj.mass
				
				-- Apply to lerps
				obj.vel = obj.vel + acc
				obj.currTick = obj.currTick + obj.vel
				
			end
		end
	end
end, "lerpTick")

-- This render event iterates through the lerps table, and smooths the lerp between the previous tick and the current tick, using delta.  
-- Only preforms calculations on enabled lerps if the game is unpaused.
events.RENDER:register(function(delta)
	if not client:isPaused() then
		for obj in pairs(lerps) do
			if obj.enabled then
				
				-- Lerp previous ticks to current ticks
				obj.currPos = math.lerp(obj.prevTick, obj.currTick, delta)
				
			end
		end
	end
end, "lerpRender")

-- Sets if a lerp object should be enabled.
---@param enable boolean #
-- Determines if the lerp should function.  
-- Saves on instructions if the lerp is not in use.
function lerpObject:setEnabled(enable)
	
	-- Sets state to object
	self.enabled = enable
	
	-- Return object
	return self
	
end

-- Sets the target of a lerp object.
---@param target number | Vector.any | Matrix.any #
-- The direction a lerp will move gradually, and eventually stop at.  
-- Can be a number, vector, or matrix.
function lerpObject:setTarget(target)
	
	-- Sets target to object
	self.target = target
	
	-- Return object
	return self
	
end

-- Gets the current position of a lerp on its way to its target.
function lerpObject:getPos()
	
	-- Return position
	return self.currPos
	
end

-- Sets the stiffness of a lerp object.
---@param stiff number #
-- How fast the lerp moves towards its target (in percentage each tick).  
-- `0` will never approach the target.  
-- `1` will reach the target within the tick.
function lerpObject:setStiff(stiff)
	
	-- Sets stiffness to object
	self.stiff = stiff
	
	-- Return object
	return self
	
end

-- Sets the dampness of a lerp object.
---@param damp number #
-- How much a lerp is allowed to bounce around its target.  
-- `0` will never reach its target due to bouncing.  
-- `1` wont bounce around the target.
function lerpObject:setDamp(damp)
	
	-- Sets dampness to object
	self.damp = damp
	
	-- Return object
	return self
	
end

-- Sets the mass of a lerp object.
---@param mass number #
-- How long it takes for the object to change velocity.  
-- Cannot have a mass of `0`, otherwise divide by `0` errors will occur.  
-- You can *still* do `0` by changing it in field, but ur asking for issues at that point.
function lerpObject:setMass(mass)
	
	-- Sets mass to object
	self.mass = massCheck(mass)
	
	-- Return object
	return self
	
end

-- Resets a lerp to a given position.
---@param pos? number | Vector.any | Matrix.any #
-- The position a lerp will reset to.
-- When this function is called, a lerp is completely halted, and set to a given position.
function lerpObject:reset(pos)
	
	-- Sets position to internal positional values
	pos = pos or 0.0
	self.prevTick = pos
	self.currTick = pos
	self.target   = pos
	self.currPos  = pos
	self.vel      = type(pos) ~= "number" and pos:copy():reset() --[[@as number | Vector.any | Matrix.any]] or 0
	
	-- Return object
	return self
	
end

-- Reverses a lerp object's velocity and "Bounces" it off of the provided value.  
-- Great for creating limits to a lerp when using spring lerping.
---@param pos number | Vector.any | Matrix.any #
-- Sets the current tick position of a lerp object.  
-- This effectively tells the lerp to smoothly come to a stop at its limit, and flips the velocity, sending it the opposite direction.
---@param damp? number #
-- Determines how strongly the velocity is flipped during the bounce.  
-- Helps create the illusion that energy is lost when a bounce is preformed... or that energy is added, if you prefer.
function lerpObject:bounce(pos, damp)
	
	-- Apply bounce to object
	self.currTick = pos
	self.vel = -self.vel * (damp or 1)
	
	-- Return object
	return self
	
end

-- Removes a lerp object from the table of lerp calculations.
-- Remember to remove references to this object to help Garbage Cleanup remove the lerp.
function lerpObject:remove()
	
	-- Removes object
	lerps[self] = nil
	
end

-- Return API
return lerpAPI