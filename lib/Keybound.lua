-- Keybound
-- By:
--   _________  ________  _________  ________  ___
--  |\___   ___\\   __  \|\___   ___\\   __  \|\  \
--  \|___ \  \_\ \  \|\  \|___ \  \_\ \  \|\  \ \  \
--       \ \  \ \ \  \\\  \   \ \  \ \ \   __  \ \  \
--        \ \  \ \ \  \\\  \   \ \  \ \ \  \ \  \ \  \____
--         \ \__\ \ \_______\   \ \__\ \ \__\ \__\ \_______\
--          \|__|  \|_______|    \|__|  \|__|\|__|\|_______|
--
-- Version: 1.1.1

-- Host only instructions
if not host:isHost() then return end

-- A keybind config.  
-- `key` refers to the Minecraft keyboard key the keybind is set to.  
-- `cfg` refers to the config key associated with the keybind.
---@alias KeybindConfig table<Keybind, {
--- key: Minecraft.keyCode,
--- cfg: string,
--- }>

-- Keybind API's metatable index.
local keybindIndex = figuraMetatables.Keybind.__index

-- Functions that are created/overwritten for the keybind API to do custom things.
---@class Keybind
local newMethods = {}

-- A table that holds keybinds for later updating.
---@type KeybindConfig
local keys = {}

-- Attaches a config key to a keybind, and attempts to set its key to the config's value.
---@param cfgName string #
-- The config's key that will be added to the keybind.
function newMethods:setConfig(cfgName)
	
	-- Attach bind
	self:key(config:load(cfgName) or self:getKey())
	
	-- Store keybind
	keys[self] = {
		key = self:getKey(),
		cfg = cfgName
	}
	
	-- Return keybind
	return self
	
end

-- Copy to alias
newMethods.config = newMethods.setConfig

-- Apply new functions to API
function figuraMetatables.Keybind.__index(self, key)
	return newMethods[key] or keybindIndex(self, key)
end

-- This tick function checks if the user is on the Figura Keybind screen.  
-- If they are, it will compare the keybinds last state, and if they do not match, stores the new key to the config.
events.TICK:register(function()
	if host:getScreen() == "org.figuramc.figura.gui.screens.KeybindScreen" then
		for keybind, keyTbl in pairs(keys) do
			
			-- Get current key
			local currKey = keybind:getKey()
			
			-- Compare keys
			if keyTbl.key ~= currKey then
				
				-- Save new key to config
				config:save(keyTbl.cfg, currKey)
				
				-- Store new key
				keyTbl.key = currKey
				
			end
			
		end
	end
end, "tickKeys")