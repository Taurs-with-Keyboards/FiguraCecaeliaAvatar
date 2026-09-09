-- Required scripts
local parts    = require("lib.PartsAPI")
local sync     = require("lib.LetThatSyncFig")
local membrane = require("lib.MembraneAPI")

-- Parts setup
local cecaelia = parts.new(models.Cecaelia)

-- Membrane parts
local membraneParts = cecaelia:createTable(function(part) return part:getName():find("Membrane") end)

-- Only run script if permission level is met
if avatar:getPermissionLevel() ~= "MAX" then
	for i = 1, #membraneParts do
		membraneParts[i]:visible(false)
	end
	return
end

-- Synced variables setup
local toggle = sync.new("MembraneToggle", false):config()

-- Variables
local nTen = 8

-- Create string
local function makeName(ten, seg)
	return "Ten" .. ((ten - 1) % nTen) + 1 .. "Seg" .. seg
end

-- Setup web
local function makeWeb(name)
	
	local ten = tonumber(name:match("[tT]en(%d+)"))
	local seg = tonumber(name:match("[sS]eg(%d+)"))
	
	return {
		cecaelia.outliner[makeName(ten + 1, seg + 1)],
		cecaelia.outliner[makeName(ten, seg + 1)],
		cecaelia.outliner[name],
		cecaelia.outliner[makeName(ten + 1, seg)],
	}
	
end

-- Create membrane webs
for i = 1, #membraneParts do
	
	local part = membraneParts[i]
	
	membrane:define(
		part,
		makeWeb(part:getParent():getName())
	)
	
end

function events.RENDER()
	
	-- Visibility
	for i = 1, #membraneParts do
		membraneParts[i]:visible(toggle.curr)
	end
	
end

-- Apply sound function
toggle:addFuncs(function()
	if player:isLoaded() then
		sounds:playSound("entity.phantom.flap", player:getPos())
	end
end)

-- Host only instructions
if not host:isHost() then return end

-- Required scripts
local s, _, acts, colors = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isn't found
pcall(require, "scripts.Tail") -- Tries to find script, not required

-- Pages
local parentPage = action_wheel:getPage("Octopus") or action_wheel:getPage("Main")

-- Action
acts.membraneToggle = parentPage:newAction()
	:item("red_carpet")
	:toggleItem("green_carpet")
	:onToggle(function(bool)
		toggle:update(bool)
	end)
	:toggled(toggle.curr)

-- Update action
function events.RENDER()
	
	if action_wheel:isEnabled() then
		acts.membraneToggle
			:title(toJson(
				{
					"",
					{text = "Toggle Membrane\n\n", bold = true, color = colors.primary},
					{text = "Toggles the visibility of the membrane.\n\n", color = colors.secondary},
					{text = "Notice:\n", bold = true, color = "gold"},
					{text = "This feature requires MAX permission level to be viewed.", color = "yellow"}
				}
			))
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
	end
	
end