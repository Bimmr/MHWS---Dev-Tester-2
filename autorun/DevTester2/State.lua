-- DevTester v2.0 - State Management
-- Global state for the mod

local Constants = require("DevTester2.Constants")

local State = {}

-- Constants
State.NODE_WIDTH = Constants.NODE_WIDTH

-- Window state
State.window_open = false
State.current_config_name = nil
State.current_config_description = ""
State.is_modified = false

-- Node storage
State.all_nodes = {}
State.all_links = {}
State.starter_nodes = {}

-- Hash maps for fast lookups
State.node_map = {}  -- node_id -> node
State.link_map = {}  -- link_id -> link

-- Caching
State.type_cache = {}  -- type_full_name -> {methods = {...}, fields = {...}, last_accessed = timestamp}
State.combo_cache = {}  -- cache_key -> combo_items

-- ID counters
State.next_node_id = 1
State.next_link_id = 1
State.next_pin_id = 1

-- UI state
State.show_save_menu = false
State.show_load_menu = false
State.save_name_input = ""
State.save_description_input = ""
State.available_configs = {}
State.selected_config_index = 0

-- Track which nodes have been positioned in the node editor (UI)
State.nodes_positioned = {}

return State
