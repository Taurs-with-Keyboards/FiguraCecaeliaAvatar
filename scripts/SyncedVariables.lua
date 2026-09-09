-- Table setup
local t = {
	dG = false,
	nV = false,
	cF = false
}

-- Night vision check
local wasNV = t.nV
function pings.nVPing(boolean)
	
	t.nV = boolean
	
end

if host:isHost() then
	function events.TICK()
		
		local statuses = host:getStatusEffects()
		
		t.nV = false
		for i = 1, #statuses do
			if statuses[i].name == "effect.minecraft.night_vision" then
				t.nV = true
				break
			end
		end
		if t.nV ~= wasNV then
			pings.nVPing(t.nV)
		end
		wasNV = t.nV
		
	end
end

-- Dolphin's grace check
local wasDG = t.dG
function pings.dGPing(boolean)
	
	t.dG = boolean
	
end

if host:isHost() then
	function events.TICK()
		
		local statuses = host:getStatusEffects()
		
		t.dG = false
		for i = 1, #statuses do
			if statuses[i].name == "effect.minecraft.dolphins_grace" then
				t.dG = true
				break
			end
		end
		if t.dG ~= wasDG then
			pings.dGPing(t.dG)
		end
		wasDG = t.dG
		
	end
end

-- Creative flight check
local wasCF = t.cF
function pings.cFPing(boolean)
	
	t.cF = boolean
	
end

if host:isHost() then
	function events.TICK()
		
		t.cF = host:isFlying()
		if t.cF ~= wasCF then
			pings.cFPing(t.cF)
		end
		wasCF = t.cF
		
	end
end

-- Returns variables
return t