-- PartsAPI
-- By:
--   _________  ________  _________  ________  ___
--  |\___   ___\\   __  \|\___   ___\\   __  \|\  \
--  \|___ \  \_\ \  \|\  \|___ \  \_\ \  \|\  \ \  \
--       \ \  \ \ \  \\\  \   \ \  \ \ \   __  \ \  \
--        \ \  \ \ \  \\\  \   \ \  \ \ \  \ \  \ \  \____
--         \ \__\ \ \_______\   \ \__\ \ \__\ \__\ \_______\
--          \|__|  \|_______|    \|__|  \|__|\|__|\|_______|
--
-- Version: 1.1.2

-- An API for handling the creation of Parts Objects.
---@class PartsAPI
local partsAPI = {}

-- A parts object.
---@class PartsObject
-- The modelpart the object starts from.
---@field root ModelPart
-- A list of all modelparts that are within the root modelpart.
---@field parts ModelPart[]
-- A list of all modelparts that are groups within the root modelpart.
---@field outliner table<string, ModelPart>
local partsObject = {}

-- A table that holds the parts objects.
---@type table<ModelPart, PartsObject>
local partObjs = {}

-- The metatable for parts objects.
local partsMeta = {
	__index = partsObject,
	__type = "PartsObject"
}

-- Creates a table used for a parts object.
---@param part ModelPart #
-- The root model part.  
-- Parts listed in `obj.parts` are children of this part.
---@param tbl? PartsObject #
-- The table used to create a parts object.
local function objSetup(part, tbl)
	
	-- Init table setup
	tbl = tbl or {
		parts = {},
		outliner = {},
		root = part
	}
	
	-- Insert part into parts table
	table.insert(tbl.parts, part)
	
	-- Check if part is a group
	if part:getType() == "GROUP" then
		
		-- Add group to outliner
		tbl.outliner[part:getName()] = part
		
		-- Find parts children
		local children = part:getChildren()
		
		-- Loop through children if applicable
		for i = 1, #children do
			objSetup(children[i], tbl)
		end
		
	end
	
	-- Return table
	return tbl
	
end

-- Creates a parts object.
---@param model ModelPart #
-- The root modelpart the object is based on.
---@nodiscard
function partsAPI.new(model)
	
	-- If a parts object already exists for this modelpart, use that instead
	if partObjs[model] then return partObjs[model] end
	
	-- Create object
	local obj = setmetatable(
		objSetup(model),
		partsMeta
	)
	
	-- Add object to table
	partObjs[model] = obj
	
	-- Return object
	return partObjs[model]
	
end

-- Creates a table of model parts that match a condition.
---@param condition fun(part: ModelPart): any #
-- The function modelparts will be compared against.
---@nodiscard
function partsObject:createTable(condition)
	
	-- The parts that match the condition
	---@type ModelPart[]
	local tbl = {}
	
	-- Alias for `self.parts`
	local parts = self.parts
	
	-- Loop through each part checking if the condition matches
	for i = 1, #parts do
		if condition(parts[i]) then table.insert(tbl, parts[i]) end
	end
	
	-- Return table
	return tbl
	
end

-- Creates a deep copy of a provided modelpart, and adds it's contents to its Parts Object.
---@param part ModelPart #
-- The modelpart the deep copy is based on.
function partsObject:deepCopy(part)
	
	-- Start by creating a copy of part
	local copy = part:copy(part:getName().."_Copy")
	
	-- Add new part to parts table
	table.insert(self.parts, copy)
	
	-- Check if part is a group
	if copy:getType() == "GROUP" then
		
		-- Add group to outliner
		self.outliner[copy:getName()] = copy
		
		-- Find parts children
		local children = copy:getChildren()
		
		-- Loop through children if applicable
		for i = 1, #children do
			
			-- Child part
			local child = children[i]
			
			-- Remove from parent, send to copy
			copy:removeChild(child):addChild(self:deepCopy(child))
		
		end
		
	end
	
	-- Returns copy of modelpart
	return copy
	
end

-- Creates a chain of modelparts based on a modelparts name.  
-- This function will search a part object's outliner for similar names with numbers, counting upwards.
---@param part ModelPart #
-- The root modelpart of the chain. It's assumed index is 1, optionally.  
-- Starting with any number other than 1 will assume the number after it.
---@param length? integer #
-- How many entries will be made into the table.  
-- If left blank, the function will add model parts until the chain is broken.
---@nodiscard
function partsObject:createChain(part, length)
	
	-- The parts that match the modelpart root
	---@type ModelPart[]
	local tbl = {}
	
	-- If no length, use parts table instead
	length = length or #self.parts
	
	-- Insert root modelpart into table
	table.insert(tbl, part)
	
	-- Part name, string, and initial index
	local name = part:getName()
	local nameStr = name:gsub("%d+$", "")
	local initIndex = name:match("%d+$") or 1
	
	-- Search for modelparts using name
	for i = 2, length do
		
		-- Create names
		local currIndex = initIndex + i - 1
		local currName = nameStr..currIndex
		local currPart = self.outliner[currName]
		
		-- Store part in table, otherwise kill loop
		if currPart then
			table.insert(tbl, currPart)
		else
			break
		end
		
	end
	
	-- Return table
	return tbl
	
end

-- Updates/Resets a parts object.
function partsObject:update()
	
	-- Recreate object table
	local newTbl = objSetup(self.root)
	
	-- Swap out object values for new values
	for key, value in pairs(newTbl) do
		self[key] = value
	end
	
end

-- Return API
return partsAPI