_addon.author = 'Icy'
_addon.commands = {'StoreMats', 'smats', 'store'}
_addon.name = 'StoreMats'
_addon.version = '1.0.2'

require('tables')
require('strings')
require('logger')

local res_items = nil
local config = require('config')
local default = {
	always_bring_to_inventory = S{'Echo Drops', 'Sole Sushi'}, -- Force getting items you always want in your inventory. Will pull them from all available bags.
	keep_in_inventory = S{'linkpearl','linkshell','Copper Voucher','Silver Voucher'}, -- Items you wish to always remain in your inventory if they are already there...
	keep_single_stack_only = S{'Prism Powder','Silent Oil','Remedy'}, -- items you wish to keep a single stack of in your inventory, if they are already there.
	storable_bags = S{ 'satchel', 'sack', 'case' }, -- The bags you wish to store items
	store_usable_items = true, -- setting this to false will keep things like food, silent oils, ect. in your inventory
	small_footprint = true,
}
settings = config.load(default)

local player = windower.ffxi.get_player()
local bags = S{'safe','safe2','storage','locker','inventory','satchel','sack','case','wardrobe','wardrobe2','wardrobe3','wardrobe4'}

function run()
	res_items = require('resources').items
	
	-- this is so the user doesn't have to reload the addon everytime they make a change to the settings.
	config.reload(settings) -- Get latest settings | user could have changed a setting so lets reload it just in case.
	
	player = windower.ffxi.get_player()
	
	local storages = get_player_items()
	
	local haystack = {}
	local results = 0
	
	for character,storage in pairs(storages) do
		for bag,items in pairs(storage) do
			if bags:contains(bag) then
				for id, count in pairs(items) do
					id = tonumber(id)
					if res_items[id] and IsStackable(id) then
						if not haystack[id] then 
							haystack[id] = {} 
						end
						haystack[id][bag] = count
					end
				end
			end
		end
	end
	
	local puts = {}
	for id,bags in pairs(haystack) do
		if table.length(bags) > 1 then
			results = results +1
			local item_name = res_items[id].name
			log(item_name,'found in:')
			for bag,count in pairs(bags) do
				log('\t', bag, count)
				if bag ~= 'inventory' then
					-- consolidate the item
					windower.send_command('get "'..item_name..'" all')
					
					-- setup the puts table
					if not puts[id] then 
						puts[id] = {}
						puts[id][bag] = count
					end
					
					coroutine.sleep(1)
				end
			end
		end
	end
	log(' [', results, 'item(s) consolidated. ]')
	
	if results > 0 then
		storages = get_player_items()
		local storable_bags_space = get_storable_bags_space(storages)
		
		log('')
		log('Attempting to store items that were consolidated.')
		
		for id, bags in pairs(puts) do
			local item = res_items[id]
			
			local keep_item = settings.keep_in_inventory:contains(item.name)
			local keep_stack = settings.keep_single_stack_only:contains(item.name) and item.stack or nil
			if item.category == 'Usable' and not settings.store_usable_items then
				keep_item = true
			end
				
			local store_amount = 'all'
			if not keep_item and keep_stack and storages[player.name]['inventory'][id] <= keep_stack then 
				keep_item = true
			elseif not keep_item and keep_stack then
				store_amount = tostring(storages[player.name]['inventory'][id] - keep_stack)
			end
			
			if not keep_item then
				-- the way puts is setup we need to loop through it even though we know it'll only contain 1 bag
				for bag, count in pairs(bags) do 
					local cmd = 'put "'..item.name..'" '..bag..' '..store_amount
					
					-- Check if the bag is a valid location to store
					if not settings.storable_bags:contains(bag) then
						--log('Origin bag is not listed as a storage bag.')
						local bag_to_use, bag_to_use_space = get_bag_with_most_space(storable_bags_space[player.name])
						if bag_to_use then
							cmd = 'put "'..item.name..'" '..bag_to_use..' '..store_amount
						else
							cmd = nil --  setting it to nil so it stays in the inventory
						end
					end
					
					if cmd then
						log('\t',cmd)
						windower.send_command(cmd)
						coroutine.sleep(1)
						-- items have moved around so space probably have changed.
						storable_bags_space = get_storable_bags_space()
					end
				end
			end
		end
	end
	
	
	storages = get_player_items()
	storable_bags_space = get_storable_bags_space(storages)
	if storages[player.name]['inventory'] then
		log('')
		log('Attempting to store all other items.')	
		results = 0
		for id, count in pairs(storages[player.name]['inventory']) do
			id = tonumber(id)
			if res_items[id] and IsStackable(id) then
				local item = res_items[id]
				
				local keep_item = settings.keep_in_inventory:contains(item.name) or settings.always_bring_to_inventory:contains(item.name)
				local keep_stack = settings.keep_single_stack_only:contains(item.name) and item.stack or nil
				if item.category == 'Usable' and not settings.store_usable_items then
					keep_item = true
				end
				
				local store_amount = 'all'
				if not keep_item and keep_stack and storages[player.name]['inventory'][id] <= keep_stack then 
					keep_item = true
				elseif not keep_item and keep_stack then
					store_amount = tostring(storages[player.name]['inventory'][id] - keep_stack)
				end
				
				local cmd = nil
				if not keep_item then
					local bag_to_use, bag_to_use_space = get_bag_with_most_space(storable_bags_space[player.name])
					if bag_to_use then
						cmd = 'put "'..item.name..'" '..bag_to_use..' '..store_amount
					else
						cmd = nil --  setting it to nil so it stays in the inventory
					end
				end
				
				if cmd then
					results = results + 1
					log('\t',cmd)
					windower.send_command(cmd)
					coroutine.sleep(1)
					-- items have moved around so space probably have changed.
					storable_bags_space = get_storable_bags_space()
				end
			end
		end
		
		log(' [', results, 'item(s) stored. ]')
	end 
	
	-- get items listed in settings.always_bring_to_inventory
	if settings.always_bring_to_inventory:length() > 0 then
		log('')
		log('Retrieving items in \'always_bring_to_inventory\'')
		results = 0
		storages = get_player_items()
		local inv_space = get_free_space_available(storages[player.name]['inventory'])
		
		for itemname, v in pairs(settings.always_bring_to_inventory) do
			--log(itemname)
			local itemslots, total = item_slots_total(storages, itemname)
			if itemslots and total 
			  and total > 0 
			  and inv_space > 0 
			  and inv_space >= itemslots then
				results = results + 1
				
				local cmd = 'get "'..itemname..'" all'
				log('\t', cmd)
				windower.send_command(cmd)
				inv_space = inv_space - itemslots
				coroutine.sleep(1)
				
				log('  Inventory:', inv_space, 'slot(s) remaining.')
			end
		end
		
		log(' [', results, 'item(s) retrieved. ]')
	end
	
	if settings.small_footprint then
		-- free up the memory
		--coroutine.sleep(1)
		log('Forcing reload to free up resources')
		windower.send_command('lua r '.._addon.name)
	end
end -- end of run

function get_free_space_available(bag)
	local free = 80
	if bag then
		local slotsused = 0
		for id, c in pairs(bag) do
			local itemslots = 1
			local item_stack = res_items[tonumber(id)].stack
			if c > 1 and item_stack > 1 then
				itemslots = math.ceil(c / item_stack)
			end
			slotsused = slotsused + itemslots 
		end
		free = free - slotsused
	end
	return free
end

function item_slots_total(storages, itemname)
	local total = 0
	local itemslots = 1
	local stacksize = nil
	for bag, items in pairs(storages[player.name]) do
		if bag ~= 'inventory' then
			for id, count in pairs(items) do
				local item = res_items[id]
				if item and item.name == itemname then 
					if not stacksize then 
						stacksize = item.stack 
					end
					total = total + count 
				end
			end
		end
	end
	
	if stacksize and total > 1 and stacksize > 1 then
		itemslots = math.ceil(total / stacksize)
	end
	return itemslots, total
end

function get_bag_with_most_space(bags)
	local bag_to_use = nil
	local bag_to_use_space = nil
	for sbag, space in pairs(bags) do
		-- check the space of each bag and identify which has the most space.
		if not bag_to_use and space ~= 0 then
			bag_to_use = sbag
			bag_to_use_space = space
		elseif space ~= 0 then
			if space > bag_to_use_space then
				bag_to_use = sbag
				bag_to_use_space = space
			end
		end
	end
	
	return bag_to_use, bag_to_use_space
end

function get_storable_bags_space(storages)
	local bags = {}
	if not storages then
		storages = get_player_items()
	end
	
	local storable_bags = settings.storable_bags
	local p = player.name
	for b, v in pairs(storable_bags) do
		if storages[p][b] then
			if not bags[p] then bags[p] = {} end
			local scnt = 0
			for t, r in pairs(storages[p][b]) do scnt = scnt + 1 end
			bags[p][b] = 80 - scnt
			
			-- adjust slots because items > stack size takes up additional slots.
			local adjslots = 0
			for iid, num in pairs(storages[p][b]) do
				local item_stack = res_items[tonumber(iid)].stack
				if num > 1 and item_stack > 1 then
					local numOfSlotsNeeded = math.ceil(num / item_stack)
					if numOfSlotsNeeded > 1 then
						adjslots = adjslots + numOfSlotsNeeded - 1
					end
				end
			end
			bags[p][b] = bags[p][b] - adjslots
		end
	end
	
	return bags
end

function IsStackable(id) return res_items[id].stack > 1 end

function get_player_items()
	local inventory = windower.ffxi.get_items()
	local storages = {}
	storages[player.name] = {}
	
	-- flatten inventory > Shamelessly stolen from findAll. Many thanks to Lili. > Shamelessly stolen from findAll. Many thanks to Zohno.	
	for bag,_ in pairs(bags:keyset()) do 
        storages[player.name][bag] = T{}
		for i = 1, inventory[bag].max do
			data = inventory[bag][i]
			if data.id ~= 0 then
				local id = data.id
				storages[player.name][bag][id] = (storages[player.name][bag][id] or 0) + data.count
			end
        end
    end
	
	return storages
end

function validate_item(itemname)
	if not itemname then return end
	
	res_items = require('resources').items
	for i, item in pairs(res_items) do
		if item.en:lower():contains(itemname) or item.enl:lower():contains(itemname) then 
			--log(item.en)
			return item.en 
		end
	end
end
function validate_bag(bagname) if bags:contains(bagname) then return true else return false end end

function print_help()
	log('data/settings.xml')
	log('  always_bring_to_inventory:', 'items listed will always get pulled to your inventory')
	log('  keep_in_inventory:', 'items you wish to keep in your inventory after consolidation')
	log('  keep_single_stack_only:', 'items you wish to keep a single stack of after consolidation')
	log('  storable_bags:', 'only stores items to the bags listed')
	log('  store_usable_items(true):', 'when false this will keep usable items(food, silent oils..) in your inv')
	log('  small_footprint:', 'performs a reload on itself to free up resources')
	log('Commands')
	log('  //storemats,smats,store  -', 'runs the addon')
	log('  //smats <always,gets> <add,remove> {item}  -', 'add/del item from [always_bring_to_inventory] list')
	log('  //smats keep <add,remove> {item}  -', 'add/del item from [keep_in_inventory] list')
	log('  //smats <stack,ks> <add,remove> {item}  -', 'add/del item from [keep_single_stack_only] list')
	log('  //smats <storage,bags> <add,remove> {item}  -', 'add/del item from [storable_bags] list')
	log('  //smats <usable,sui>  -', 'toggles [store_usable_items]')
	log('  //smats <footprint,sf>  -', 'toggles [small_footprint]')
	log('  //smats settings  -', 'shows your all currently set settings')
	log('  //smats settings <always,keep,stack,storage> -', 'shows your selected settings list')
	log('  //smats help  -', 'shows this screen')
end

windower.register_event('addon command', function (...)
	local commands = {...}
	
	if commands[1] then
		config.reload(settings)
		if commands[1] == 'help' then
			print_help()
			return
			
		elseif commands[1] == 'settings' then
			if commands[2] then
				if commands[2]:lower() == 'always' or commands[2]:lower() == 'gets' then log('always_bring_to_inventory','=', settings.always_bring_to_inventory)
				 elseif commands[2]:lower() == 'keep' then log('keep_in_inventory','=', settings.keep_in_inventory)
				 elseif commands[2]:lower() == 'stack' or commands[2]:lower() == 'ks' then log('keep_single_stack_only','=', settings.keep_single_stack_only)
				 elseif commands[2]:lower() == 'storage' or commands[2]:lower() == 'bags' then log('storable_bags','=', settings.storable_bags)
				 elseif commands[2]:lower() == 'usable' or commands[2]:lower() == 'sui' then log('store_usable_items','=', settings.store_usable_items)
				 elseif commands[2]:lower() == 'footprint' or commands[2]:lower() == 'sf' then log('small_footprint','=', settings.small_footprint) 
				end
			else
				log('\t ===', player.name..'\'s', 'Settings ===')
				log('always_bring_to_inventory','=', settings.always_bring_to_inventory)
				log('keep_in_inventory','=', settings.keep_in_inventory)
				log('keep_single_stack_only','=', settings.keep_single_stack_only)
				log('storable_bags','=', settings.storable_bags)
				log('store_usable_items','=', settings.store_usable_items)
				log('small_footprint','=', settings.small_footprint)
			end
			return
			
		elseif commands[1] == 'usable' or commands[1] == 'sui' then
			if settings.store_usable_items then settings.store_usable_items = false else settings.store_usable_items = true end
			log('store_usable_items','=', settings.store_usable_items)
			config.save(settings)
			return
		elseif commands[1] == 'footprint' or commands[1] == 'sf' then
			if settings.small_footprint then settings.small_footprint = false else settings.small_footprint = true end
			log('small_footprint','=', settings.small_footprint)
			config.save(settings)
			return
			
		elseif commands[1] == 'always' or commands[1] == 'gets' then
			if commands[2] and commands[2]:lower() == 'add' or commands[2]:lower() == 'a' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				local itemname = validate_item(commands[3])
				if commands[3] and itemname then
					if not settings.always_bring_to_inventory:contains(commands[3]) then
						settings.always_bring_to_inventory:add(commands[3])
						config.save(settings)
						log(commands[3], 'added to always_bring_to_inventory')
					else
						log(commands[3], 'already exists in always_bring_to_inventory')
					end
				else log('Invalid item. Please try again.') end
			elseif commands[2] and commands[2]:lower() == 'remove' or commands[2]:lower() == 'r' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				local itemname = validate_item(commands[3])
				if commands[3] and itemname then
					if settings.always_bring_to_inventory:contains(commands[3]) then
						settings.always_bring_to_inventory:remove(commands[3])
						config.save(settings)
						log(commands[3], 'removed from always_bring_to_inventory')
					else
						log(commands[3], 'not found in always_bring_to_inventory')
					end
				else log('Invalid item. Please try again.') end
			else log('Invalid Command. Did you forget the add or remove command?') end
			if settings.small_footprint then windower.send_command('lua r '.._addon.name) end
			return
			
		elseif commands[1] == 'stack' or commands[1] == 'ks' then
			if commands[2] and commands[2]:lower() == 'add' or commands[2]:lower() == 'a' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				local itemname = validate_item(commands[3])
				if commands[3] and itemname then
					if not settings.keep_single_stack_only:contains(commands[3]) then
						settings.keep_single_stack_only:add(commands[3])
						config.save(settings)
						log(commands[3], 'added to keep_single_stack_only')
					else
						log(commands[3], 'already exists in keep_single_stack_only')
					end
				else log('Invalid item. Please try again.') end
			elseif commands[2] and commands[2]:lower() == 'remove' or commands[2]:lower() == 'r' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				local itemname = validate_item(commands[3])
				if commands[3] and itemname then
					if settings.keep_single_stack_only:contains(commands[3]) then
						settings.keep_single_stack_only:remove(commands[3])
						config.save(settings)
						log(commands[3], 'removed from keep_single_stack_only')
					else
						log(commands[3], 'not found in keep_single_stack_only')
					end
				else log('Invalid item. Please try again.') end
			else log('Invalid Command. Did you forget the add or remove command?') end
			if settings.small_footprint then windower.send_command('lua r '.._addon.name) end
			return
			
		elseif commands[1] == 'keep' then
			if commands[2] and commands[2]:lower() == 'add' or commands[2]:lower() == 'a' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				local itemname = validate_item(commands[3])
				if commands[3] and itemname then
					if not settings.keep_in_inventory:contains(commands[3]) then
						settings.keep_in_inventory:add(commands[3])
						config.save(settings)
						log(commands[3], 'added to keep_in_inventory')
					else
						log(commands[3], 'already exists in keep_in_inventory')
					end
				else log('Invalid item. Please try again.') end
			elseif commands[2] and commands[2]:lower() == 'remove' or commands[2]:lower() == 'r' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				local itemname = validate_item(commands[3])
				if commands[3] and itemname then
					if settings.keep_in_inventory:contains(commands[3]) then
						settings.keep_in_inventory:remove(commands[3])
						config.save(settings)
						log(commands[3], 'removed from keep_in_inventory')
					else
						log(commands[3], 'not found in keep_in_inventory')
					end
				else log('Invalid item. Please try again.') end
			else log('Invalid Command. Did you forget the add or remove command?') end
			if settings.small_footprint then windower.send_command('lua r '.._addon.name) end
			return
		
		elseif commands[1] == 'storage' or commands[1] == 'bags' then
			if commands[2] and commands[2]:lower() == 'add' or commands[2]:lower() == 'a' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				if commands[3] and validate_bag(commands[3]) then
					if not settings.storable_bags:contains(commands[3]) then
						settings.storable_bags:add(commands[3])
						config.save(settings)
						log(commands[3], 'added to storable_bags')
					else
						log(commands[3], 'already exists in storable_bags')
					end
					log('storable_bags =', settings.storable_bags)
				else log('Invalid | Bags:', bags) end
			elseif commands[2] and commands[2]:lower() == 'remove' or commands[2]:lower() == 'r' then
				commands[3] = windower.convert_auto_trans(commands[3])
				if commands[4] then commands[3] = commands[3]..' '..commands[4] end
				if commands[5] then commands[3] = commands[3]..' '..commands[5] end
				if commands[3] and validate_bag(commands[3]) then
					if settings.storable_bags:contains(commands[3]) then
						settings.storable_bags:remove(commands[3])
						config.save(settings)
						log(commands[3], 'removed from storable_bags')
					else
						log(commands[3], 'not found in storable_bags')
					end
					log('storable_bags =', settings.storable_bags)
				else log('Invalid | Bags:', bags) end
			else log('Invalid Command. Did you forget the add or remove command?') end
			return
			
		end
	end
	
	run()
end)