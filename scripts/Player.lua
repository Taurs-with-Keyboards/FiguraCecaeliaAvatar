-- Required scripts
local parts = require("lib.PartsAPI")
local sync  = require("lib.LetThatSyncFig")

-- Parts setup
local cecaelia = parts.new(models.Cecaelia)

-- Synced variables setup
local skin = sync.new("AvatarVanillaSkin", true):config()
local slim = sync.new("AvatarSlim", false):config()

-- Reenabled parts
cecaelia.outliner.LeftLeg :visible(true)
cecaelia.outliner.RightLeg:visible(true)

-- Skull setup
cecaelia:deepCopy(cecaelia.outliner.Head)
	:moveTo(cecaelia.outliner.Cecaelia)
	:parentType("SKULL")
	:pos(-cecaelia.outliner.Head:getPivot())

-- Portrait setup
cecaelia:deepCopy(cecaelia.outliner.Head)
	:moveTo(cecaelia.outliner.Cecaelia)
	:parentType("PORTRAIT")
	:pos(-cecaelia.outliner.Head:getPivot())

-- Arm parts
local defaultParts = cecaelia:createTable(function(part) return part:getName():find("ArmDefault") end)
local slimParts    = cecaelia:createTable(function(part) return part:getName():find("ArmSlim")    end)

-- Vanilla skin parts
local skinParts = cecaelia:createTable(function(part) return part:getName():find("_[sS]kin") end)

-- Layer parts
local layerTypes = {"HAT", "JACKET", "LEFT_SLEEVE", "RIGHT_SLEEVE", "LEFT_PANTS_LEG", "RIGHT_PANTS_LEG", "CAPE", "TAIL_LAYER"}
local layerParts = {}
for i = 1, #layerTypes do
	local type = layerTypes[i]
	layerParts[type] = cecaelia:createTable(function(part) return part:getName():find(type) end)
end

-- Determine vanilla player type on init
local vanillaAvatarType
function events.ENTITY_INIT()
	
	vanillaAvatarType = player:getModelType()
	
end

function events.RENDER(delta, context)
	
	-- Model shape
	local slimShape = (skin.curr and vanillaAvatarType == "SLIM") or (slim.curr and not skin.curr)
	for i = 1, #defaultParts do
		defaultParts[i]:visible(not slimShape)
	end
	for i = 1, #slimParts do
		slimParts[i]:visible(slimShape)
	end
	
	-- First person arms toggle
	local firstPerson = context == "FIRST_PERSON"
	cecaelia.outliner.LeftArm:visible(not firstPerson)
	cecaelia.outliner.RightArm:visible(not firstPerson)
	cecaelia.outliner.LeftArmFP:visible(firstPerson)
	cecaelia.outliner.RightArmFP:visible(firstPerson)
	
	-- Skin textures
	local skinType = skin.curr and "SKIN" or "PRIMARY"
	for i = 1, #skinParts do
		skinParts[i]:primaryTexture(skinType)
	end
	
	-- Cape textures
	cecaelia.outliner.Cape:primaryTexture(skin.curr and "CAPE" or "PRIMARY")
	
	-- Layer toggling
	for layerType, parts in pairs(layerParts) do
		local enabled
		if layerType == "TAIL_LAYER" then
			enabled = player:isSkinLayerVisible("RIGHT_PANTS_LEG") or player:isSkinLayerVisible("LEFT_PANTS_LEG")
		else
			enabled = player:isSkinLayerVisible(layerType)
		end
		for i = 1, #parts do
			parts[i]:visible(enabled)
		end
	end
	
end

-- Host only instructions
if not host:isHost() then return end

-- Required script
local s, pageNav, acts, colors = pcall(require, "scripts.ActionWheel")
if not s then return end -- Kills script early if ActionWheel.lua isnt found

-- Pages
local parentPage = action_wheel:getPage("Main")
local playerPage = action_wheel:newPage("Player")

-- Actions
acts.playerPage = parentPage:newAction()
	:item("armor_stand")
	:onLeftClick(function() pageNav.descend(playerPage) end)

acts.playerVanillaToggle = playerPage:newAction()
	:item("player_head{SkullOwner:"..avatar:getEntityName().."}")
	:onToggle(function(bool)
		skin:update(bool)
	end)
	:toggled(skin.curr)

acts.playerModelToggle = playerPage:newAction()
	:item("player_head")
	:toggleItem("player_head{SkullOwner:MHF_Alex}")
	:onToggle(function(bool)
		slim:update(bool)
	end)
	:toggled(slim.curr)

-- Update actions
function events.RENDER(delta, context)
	
	if action_wheel:isEnabled() then
		acts.playerPage
			:title(toJson(
				{text = "Player Settings", bold = true, color = colors.primary}
			))
			:hoverColor(colors.hover)
		
		acts.playerVanillaToggle
			:title(toJson(
				{
					"",
					{text = "Toggle Vanilla Texture\n\n", bold = true, color = colors.primary},
					{text = "Toggles the usage of your vanilla skin.", color = colors.secondary}
				}
			))
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
		acts.playerModelToggle
			:title(toJson(
				{
					"",
					{text = "Toggle Model Shape\n\n", bold = true, color = colors.primary},
					{text = "Adjust the model shape to use Default or Slim Proportions.\nWill be overridden by the vanilla skin toggle.", color = colors.secondary}
				}
			))
			:hoverColor(colors.hover)
			:toggleColor(colors.active)
		
	end
	
end