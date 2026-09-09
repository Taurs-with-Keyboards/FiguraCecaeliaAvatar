-- Check if an item exists before calling it in a function
local function itemCheck(...)
	
	local items = {...}
	
	for i = 1, #items do
		local success, itemStack = pcall(world.newItem, items[i])
		if success then return itemStack end
	end
	
end

return itemCheck