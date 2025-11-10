-- DevTester v2.0 - State Management
-- Global state for the mod

local Constants = require("DevTester2.Constants")

local State = {}

-- Window state
State.window_open = false
State.current_config_name = nil
State.current_config_description = ""
State.is_modified = false

-- Node storage
State.all_nodes = {}
State.all_links = {}

-- Variable storage (shared across all Variable nodes)
State.variables = {}  -- variable_name -> {value = value, persistent = boolean}

-- Reset tracking (prevents variable updates during reset frame)
State.reset_variables = {}  -- variable_name -> true (reset this frame)

-- Hash maps for fast lookups
State.node_map = {}  -- node_id -> node
State.link_map = {}  -- link_id -> link
State.pin_map = {}   -- pin_id -> {node_id = node.id, pin = pin}

-- Caching
State.type_cache = {}  -- type_full_name -> {methods = {...}, fields = {...}, last_accessed = timestamp}
State.combo_cache = {}  -- cache_key -> combo_items

-- ID counters
State.node_id_counter = 1
State.link_id_counter = 1
State.pin_id_counter = 1

-- UI state
State.show_save_menu = false
State.show_load_menu = false
State.save_name_input = ""
State.save_description_input = ""
State.available_configs = {}
State.selected_config_index = 0


-- Storage for hybrid combo text
State.hybrid_combo_text = {}

-- Track which nodes have been positioned in the node editor (UI)
State.nodes_positioned = {}

-- ========================================
-- State Management
-- ========================================

function State.mark_as_modified()
    State.is_modified = true
end

function State.mark_as_saved()
    State.is_modified = false
end

function State.has_unsaved_changes()
    return State.is_modified
end


-- ========================================
-- ID Generation
-- ========================================

function State.next_node_id()
    local id = State.node_id_counter
    State.node_id_counter = State.node_id_counter + 1
    return id
end

function State.next_link_id()
    local id = State.link_id_counter
    State.link_id_counter = State.link_id_counter + 1
    return id
end

function State.next_pin_id()
    local id = State.pin_id_counter
    State.pin_id_counter = State.pin_id_counter + 1
    return id
end

-- ========================================
-- Reset Functions
-- ========================================
function State.reset_nodes()
    State.all_nodes = {}
end

function State.reset_links()
    State.all_links = {}
end

function State.reset_id_counters()
    State.node_id_counter = 1
    State.link_id_counter = 1
    State.pin_id_counter = 1
end

function State.reset_maps()
    State.node_map = {}
    State.link_map = {}
    State.pin_map = {}
end

function State.reset_positioning()
    State.nodes_positioned = {}
end

return State
