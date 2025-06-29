-- Required scripts
local parts    = require("lib.PartsAPI")
local membrane = require("lib.MembraneAPI")

-- Membrane parts
local membraneParts = parts:createTable(function(part) return part:getName():find("Membrane") end)

-- Only run script if permission level is met
if avatar:getPermissionLevel() ~= "MAX" then
	for _, part in ipairs(membraneParts) do
		part:visible(false)
	end
	return {}
end

-- Config setup
config:name("Cecaelia")
local toggle = config:load("MembraneToggle") or false

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
		parts.group[makeName(ten + 1, seg + 1)],
		parts.group[makeName(ten, seg + 1)],
		parts.group[name],
		parts.group[makeName(ten + 1, seg)],
	}
	
end

-- Create membrane webs
for _, part in ipairs(membraneParts) do
	
	membrane:define(
		part,
		makeWeb(part:getParent():getName())
	)
	
end

function events.RENDER(delta, context)
	
	-- Visibility
	for _, part in ipairs(membraneParts) do
		part:visible(toggle)
	end
	
end

-- Membrane toggle
function pings.setMembraneToggle(boolean)
	
	toggle = boolean
	config:save("MembraneToggle", toggle)
	if player:isLoaded() then
		sounds:playSound("entity.phantom.flap", player:getPos())
	end
	
end

-- Sync variables
function pings.syncMembrane(a)
	
	toggle = a
	
end

-- Host only instructions
if not host:isHost() then return end

-- Sync on tick
function events.TICK()
	
	if world.getTime() % 200 == 0 then
		pings.syncMembrane(toggle)
	end
	
end

-- Required scripts
local s, wheel, itemCheck, c = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found
pcall(require, "scripts.Tail") -- Tries to find script, not required

-- Pages
local parentPage = action_wheel:getPage("Octopus") or action_wheel:getPage("Main")

-- Actions table setup
local a = {}

-- Action
a.toggleAct = parentPage:newAction()
	:item(itemCheck("red_carpet"))
	:toggleItem(itemCheck("green_carpet"))
	:onToggle(pings.setMembraneToggle)
	:toggled(toggle)

-- Update action
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		a.toggleAct
			:title(toJson(
				{
					"",
					{text = "Toggle Membrane\n\n", bold = true, color = c.primary},
					{text = "Toggles the visibility of the membrane.\n\n", color = c.secondary},
					{text = "Notice:\n", bold = true, color = "gold"},
					{text = "This feature requires MAX permission level to be viewed.", color = "yellow"}
				}
			))
		
		for _, act in pairs(a) do
			act:hoverColor(c.hover):toggleColor(c.active)
		end
		
	end
	
end