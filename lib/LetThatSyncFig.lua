-- LetThatSyncFig
-- By:
--   _________  ________  _________  ________  ___
--  |\___   ___\\   __  \|\___   ___\\   __  \|\  \
--  \|___ \  \_\ \  \|\  \|___ \  \_\ \  \|\  \ \  \
--       \ \  \ \ \  \\\  \   \ \  \ \ \   __  \ \  \
--        \ \  \ \ \  \\\  \   \ \  \ \ \  \ \  \ \  \____
--         \ \__\ \ \_______\   \ \__\ \ \__\ \__\ \_______\
--          \|__|  \|_______|    \|__|  \|__|\|__|\|_______|
--
-- Special thanks: Grandpa Scout, Pool & Mangodev
-- Version: 1.1.10

-- An API for handling the creation of Sync Objects.
---@class SyncAPI
local syncAPI = {}

-- A sync object.
---@class SyncObject
-- The unique id of a sync object.
---@field id string
-- The numerical id of a sync object.
---@field nid integer
-- The previous state of a sync object's value.
---@field prev any
-- The current state of a sync object's value.
---@field curr any
-- A table holding functions for a sync object to preform.
---@field funcs table<function, boolean>
-- A countdown for how many ticks before an object's ping is sent.
---@field countdown integer
local syncObject = {}

-- A table that holds the sync objects.
---@type SyncObject[]
local syncs = {}

-- The metatable for sync objects.
local syncMeta = {
	__index = syncObject,
	__type = "SyncObject"
}

-- Unique ID error message likes to fight the `typeCheck` error message for some reason; this prevents that.
local errorOverride = false

-- Type checker that errors if type isn't what's needed.
---@param value any #
-- Value that is checked to ensure it is matching the provided type.
---@param typeStr string #
-- Type the `value` is checked against.
local function typeCheck(value, typeStr)
	if type(value) ~= typeStr then
		errorOverride = true
		error("\n\n§6Argument must be a "..typeStr.."!\n§c", 3)
	end
end

-- Creates a sync object.
---@param id string #
-- The unique id of a sync object.  
-- \>>> **MUST BE UNIQUE** <<<  
-- Sync objects use numerical ids to send lightweight pings to other clients.  
-- The numerical ids are generated using the id provided, ensuring the number ids are the same across clients.  
-- It's also helpful for debugging :)
---@param ... any #
-- The default value of a sync object.  
-- You may send as many values as you would like; the sync object will only use the first value thats NOT `nil`.  
-- This is useful if you would like an optional default that doesn't always occur, and a backup thats guaranteed.  
-- If all values are `nil`, the sync object's value will be `nil`.
---@nodiscard
function syncAPI.new(id, ...)
	
	-- Check if the id is a string
	typeCheck(id, "string")
	
	-- Check if the id already exists
	for i = 1, #syncs do
		if syncs[i].id == id then
			if not errorOverride then
				error("\n\n§6ID must be unique!\n§c", 2)
			end
		end
	end
	
	-- Determine which value should be applied, checking for nil before returning
	local result = nil
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if value ~= nil then
			result = value
		end
	end
	
	-- Create object
	local obj = setmetatable(
		{
			id = id,
			prev = result,
			curr = result,
			funcs = {}
		},
		syncMeta
	)
	
	-- Add object to table
	syncs[#syncs + 1] = obj
	
	-- Return object
	return obj
	
end

-- This entity init event sorts the sync table deterministically across clients, making sure the ids match.
function events.ENTITY_INIT()
	
	-- Sorts table alphabetically
	table.sort(syncs, function(a, b)
		return a.id < b.id
	end)
	
	-- Grants each object a numerical id to be used when pinging
	for id = 1, #syncs do
		syncs[id].nid = id
	end
	
end

-- Preforms the actual update to a sync object.
---@param obj SyncObject #
-- The sync object the update is being preformed on.
---@param value any #
-- The value a sync object is being updated to.
local function updateValues(obj, value)
	
	-- Update current value
	obj.curr = value
	
	-- If value changed, preform the update
	if obj.curr ~= obj.prev then
		
		-- Preform optional function (if it exists)
		for func in pairs(obj.funcs) do func(obj) end
		
		-- Update config if it exists
		if obj.cfg ~= nil then config:save(obj.cfg, value) end
		
		-- Update previous value
		obj.prev = value
		
	end
	
end

-- Sends a ping to other clients to update a sync object using its number id.
---@param nid integer #
-- The id of a sync object.
---@param value any #
-- The value a sync object is being updated to.
function pings.sendSyncUpdate(nid, value)
	updateValues(syncs[nid], value)
end

-- Sends a ping to other clients to update ALL sync objects to their current values.
---@param ... any #
-- The values of the sync objects, in order of number id.
function pings.sendSyncUpdateAll(...)
	local tbl = {...}
	for i = 1, #tbl do
		updateValues(syncs[i], tbl[i])
	end
end

-- Update a sync object with a value.  
-- If the value is different from its previous, a ping is sent to other clients.
---@param value any #
-- The value a sync object is being updated to.
---@param buffer? number #
-- How many ticks the update will wait before sending the ping to other clients.  
-- This is useful for preventing ping spam, usually caused by rapid clicking and scroll wheels.
function syncObject:update(value, buffer)
	
	-- Check if change occurred, and send ping
	-- Prevents spam caused by user
	if value ~= self.prev then
		
		-- If a buffer is provided
		if buffer ~= nil then
			
			-- Check if buffer is a number
			typeCheck(buffer, "number")
			
			-- Update on host only
			-- Ping will instead be sent when countdown reaches 0
			self.countdown = buffer
			updateValues(self, value)
			
			-- Return object early
			return self
			
		end
		
		-- Send ping
		pings.sendSyncUpdate(self.nid, value)
		
	end
	
	-- Return object
	return self
	
end

-- Add functions to a sync object that will be preformed when its value is updated.
---@param ... fun(self?: SyncObject) #
-- The functions that will be added to a sync object.  
-- If you pass an optional arg, you can access the SyncObject within the function.
function syncObject:addFuncs(...)
	
	-- Gather varargs
	local funcs = {...}
	
	-- Iterate through varargs
	for i = 1, #funcs do
		
		-- Get function
		local func = funcs[i]
		
		-- Checks if function is actually a function
		typeCheck(func, "function")
		
		-- Apply function to sync
		self.funcs[func] = true
		
	end
	
	-- Return functions (in case you need them)
	return ...
	
end

-- Remove functions from a sync object (added by `addFuncs()`).
---@param ... function #
-- The functions that will be removed from a sync object.
function syncObject:removeFuncs(...)
	
	-- Gather varargs
	local funcs = {...}
	
	-- Iterate through varargs
	for i = 1, #funcs do
		
		-- Get function
		local func = funcs[i]
		
		-- Checks if function is actually a function
		typeCheck(func, "function")
		
		-- Remove function from sync
		self.funcs[func] = nil
		
	end
	
	-- Return object
	return self
	
end

-- Apply a config key to a sync object, so its value is saved across sessions.
---@param cfgName? string #
-- An optional custom config key. If none is provided, the object's ID is used.
function syncObject:config(cfgName)
	
	-- Kill function if not host
	if not host:isHost() then return self end
	
	-- Check if the name is a string
	if cfgName ~= nil then
		typeCheck(cfgName, "string")
	end
	
	-- Apply config to sync
	self.cfg = cfgName or self.id
	
	-- Get config value
	local cfgValue = config:load(self.cfg)
	
	-- Update object if config has value
	if cfgValue ~= nil then
		updateValues(self, cfgValue)
	end
	
	-- Return object
	return self
	
end

-- Host only instructions
if not host:isHost() then return syncAPI end

-- The previous tick.
local _tick = 0

-- This tick function updates all sync objects across all clients every 10 seconds.
events.TICK:register(function()
	
	-- Get world time
	local tick = world.getTime()
	
	-- Sync variables
	if tick % 200 == 0 and tick ~= _tick then
		
		-- Sync objects values.
		local syncTables = {}
		
		-- Gather values
		for i = 1, #syncs do
			syncTables[i] = syncs[i].curr
		end
		
		-- Send values
		pings.sendSyncUpdateAll(table.unpack(syncTables))
		
		-- Store prev tick
		-- Helps prevent ping spam if world is paused on tick
		_tick = tick
		
	end
	
	-- Countdown buffers
	for i = 1, #syncs do
		
		-- Sync object
		local obj = syncs[i]
		
		-- Check for countdown
		if obj.countdown then
			
			-- How many ticks left before ping.
			obj.countdown = math.max(obj.countdown - 1, 0)
			
			-- If countdown reaches 0, send ping
			if obj.countdown == 0 then
				obj.countdown = nil
				pings.sendSyncUpdate(obj.nid, obj.curr)
			end
			
		end
		
	end
	
end, "tickSync")

-- Return API
return syncAPI