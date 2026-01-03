-- DevTester v2.0 - Constants
-- Centralized constants for the mod
-- All Colours are represented in AABBGGRR format

local Constants = {}

-- ========================================
-- Node Categories
-- ========================================
Constants.NODE_CATEGORY_STARTER = 1
Constants.NODE_CATEGORY_DATA = 2
Constants.NODE_CATEGORY_FOLLOWER = 3
Constants.NODE_CATEGORY_OPERATIONS = 4
Constants.NODE_CATEGORY_CONTROL = 5
Constants.NODE_CATEGORY_UTILITY = 6

-- ========================================
-- Node Types (within categories)
-- ========================================

-- Starter Node Types
Constants.STARTER_TYPE_MANAGED = 1
Constants.STARTER_TYPE_HOOK = 2
Constants.STARTER_TYPE_NATIVE = 3
Constants.STARTER_TYPE_TYPE = 4
Constants.STARTER_TYPE_PLAYER = 5

-- Data Node Types
Constants.DATA_TYPE_ENUM = 1
Constants.DATA_TYPE_PRIMITIVE = 2
Constants.DATA_TYPE_VARIABLE = 3

-- Follower Node Types
Constants.FOLLOWER_TYPE_METHOD = 1
Constants.FOLLOWER_TYPE_FIELD = 2
Constants.FOLLOWER_TYPE_ARRAY = 3

-- Operations Node Types
Constants.OPERATIONS_TYPE_INVERT = 1
Constants.OPERATIONS_TYPE_MATH = 2
Constants.OPERATIONS_TYPE_LOGIC = 3
Constants.OPERATIONS_TYPE_COMPARE = 4

-- Control Node Types
Constants.CONTROL_TYPE_SWITCH = 1
Constants.CONTROL_TYPE_TOGGLE = 2
Constants.CONTROL_TYPE_COUNTER = 3
Constants.CONTROL_TYPE_CONDITION = 4

-- Utility Node Types
Constants.UTILITY_TYPE_LABEL = 1

-- Math Operation Types
Constants.MATH_OPERATION_ADD = 1
Constants.MATH_OPERATION_SUBTRACT = 2
Constants.MATH_OPERATION_MULTIPLY = 3
Constants.MATH_OPERATION_DIVIDE = 4
Constants.MATH_OPERATION_MODULO = 5
Constants.MATH_OPERATION_POWER = 6
Constants.MATH_OPERATION_MAX = 7
Constants.MATH_OPERATION_MIN = 8

-- Logic Operation Types
Constants.LOGIC_OPERATION_AND = 1
Constants.LOGIC_OPERATION_OR = 2
Constants.LOGIC_OPERATION_NAND = 3
Constants.LOGIC_OPERATION_NOR = 4

-- Compare Operation Types
Constants.COMPARE_OPERATION_EQUALS = 1
Constants.COMPARE_OPERATION_NOT_EQUALS = 2
Constants.COMPARE_OPERATION_GREATER = 3
Constants.COMPARE_OPERATION_LESS = 4

-- ========================================
-- Action Types
-- ========================================
Constants.ACTION_GET = 0
Constants.ACTION_SET = 1

-- ========================================
-- Node Colors (AABBGGRR format)
-- ========================================
Constants.NODE_COLOR_STARTER = 0xFF4CAF50               -- Green
Constants.NODE_COLOR_STARTER_HOOK = 0xFF2196F3          -- Blue
Constants.NODE_COLOR_STARTER_NATIVE = 0xFFFF9800        -- Orange
Constants.NODE_COLOR_STARTER_TYPE = 0xFF9C27B0          -- Purple
Constants.NODE_COLOR_STARTER_PLAYER = 0xFF795548 -- Off Blue

Constants.NODE_COLOR_DATA = 0xFF0097A7                  -- Dark Cyan
Constants.NODE_COLOR_DATA_ENUM = 0xFFE91E63             -- Magenta
Constants.NODE_COLOR_DATA_VARIABLE = 0xFF3F51B5         -- Indigo

Constants.NODE_COLOR_FOLLOWER = 0xFFFFC107              -- Yellow
Constants.NODE_COLOR_FOLLOWER_FIELD = 0xFF8BC34A        -- Lime
Constants.NODE_COLOR_FOLLOWER_ARRAY = 0xFFFF5722        -- Deep Orange

Constants.NODE_COLOR_OPERATIONS = 0xFF9C27B0            -- Purple

Constants.NODE_COLOR_CONTROL = 0xFF9C27B0               -- Purple

Constants.NODE_COLOR_UTILITY = 0xFF607D8B               -- Blue Gray

Constants.NODE_COLOR_DEFAULT = 0xFF222222              -- Black
Constants.NODE_COLOR_DEFAULT_HOVER = 0xFF3C3C3C         -- Dark Gray
Constants.NODE_COLOR_DEFAULT_SELECTED = 0xFF3C3C3C      -- Dark Gray

-- ========================================
-- Node-Specific Widths (Nodes need to have a field to have a width set)
-- ========================================
Constants.NODE_WIDTH_CONTROL = 200

Constants.NODE_WIDTH_STARTER_HUNTER_CHARACTER = 300

Constants.NODE_WIDTH_OPERATIONS = 200
Constants.NODE_WIDTH_OPERATIONS_INVERT = 150

Constants.NODE_WIDTH_DATA = 200
Constants.NODE_WIDTH_DATA_ENUM = 300
Constants.NODE_WIDTH_DATA_PRIMITIVE = 150

Constants.NODE_WIDTH_UTILITY = 250

-- ========================================
-- UI Dimensions
-- ========================================
Constants.NODE_WIDTH_DEFAULT = 300
Constants.POPUP_WIDTH_CONFIRMATION = Vector2f.new(350, 300)
Constants.MINIMAP_SIZE = 0.2
Constants.MINIMAP_POSITION = 0  -- bottom-left

-- Style values
Constants.WINDOW_ROUNDING = 7.5
Constants.FRAME_ROUNDING = 5.0
Constants.FRAME_PADDING = Vector2f.new(5, 5)
Constants.POP_PADDING = Vector2f.new(10, 10)
Constants.MENU_PADDING = Vector2f.new(5, 5)

-- ========================================
-- Element Colours
-- ========================================
Constants.COLOR_BUTTON_NORMAL = 0xFF714A29  -- Button color
Constants.COLOR_BUTTON_HOVER = 0xFFFA9642  -- Button hover color

-- ========================================
-- Text Colours
-- ========================================
Constants.COLOR_TEXT_WARNING = 0xFF27C2F5   -- Yellow
Constants.COLOR_TEXT_ERROR = 0xFF0000FF     -- Red
Constants.COLOR_TEXT_DEBUG = 0xFFDADADA     -- Light Gray
Constants.COLOR_TEXT_SUCCESS = 0xFF00FF00   -- Green
Constants.COLOR_TEXT_DARK_GRAY = 0xFF888888 -- Dark Gray

-- ========================================
-- Color Brightening Factors
-- ========================================
Constants.COLOR_BRIGHTEN_HOVER = 1.1  -- 10% brighter
Constants.COLOR_BRIGHTEN_SELECTED = 1.2  -- 20% brighter

-- ========================================
-- Node Positioning
-- ========================================
Constants.CHILD_NODE_OFFSET_X = 100
Constants.CHILD_NODE_RANDOM_Y_MIN = -150
Constants.CHILD_NODE_RANDOM_Y_MAX = 150

-- ========================================
-- Cache Settings
-- ========================================
Constants.TYPE_CACHE_SIZE_LIMIT = 50
Constants.COMBO_CACHE_SIZE_LIMIT = 100

-- ========================================
-- Timing
-- ========================================
Constants.MEMORY_CLEANUP_THRESHOLD = 100
Constants.MEMORY_CLEANUP_AGE_SECONDS = 300  -- 5 minutes


return Constants