# StoreMats
FFXI Windower4 addon - Item consolidator/organizer with config settings.

- [Results ss 1](/smats_example1.png)
- [Results ss 2](/smats_example2.png)

*** REQUIRES THE ITEMIZER ADDON ***

	data/settings.xml
  
	  always_bring_to_inventory:  items listed will always get pulled to your inventory
    
	  keep_in_inventory:  items you wish to keep in your inventory after consolidation
    
	  keep_single_stack_only:  items you wish to keep a single stack of after consolidation
    
	  storable_bags:  only stores items to the bags listed
    
	  store_usable_items(true):  when false this will keep usable items(food, silent oils..) in your inv
    
	  small_footprint:  performs a reload on itself to free up resources
    
    
	Commands
  
	  //storemats,smats,store  - runs the addon
    
	  //smats <always,gets> <add,remove> {item}  - add/del item from [always_bring_to_inventory] list
    
	  //smats keep <add,remove> {item}  - add/del item from [keep_in_inventory] list
    
	  //smats <stack,ks> <add,remove> {item}  - add/del item from [keep_single_stack_only] list
    
	  //smats <storage,bags> <add,remove> {item}  - add/del item from [storable_bags] list
    
	  //smats <usable,sui>  - toggles [store_usable_items]
    
	  //smats <footprint,sf>  - toggles [small_footprint]
    
	  //smats settings  - shows your all currently set settings
    
	  //smats settings <always,keep,stack,storage> - shows your selected settings list
    
	  //smats help  - shows this screen
    
