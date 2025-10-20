-- DevTester v2.0 - Constants
-- Centralized constants for the mod

local Constants = {}

-- ========================================
-- Node Types
-- ========================================
Constants.NODE_TYPE_TYPE = 0
Constants.NODE_TYPE_MANAGED = 1
Constants.NODE_TYPE_HOOK = 2
Constants.NODE_TYPE_ENUM = 3
Constants.NODE_TYPE_NATIVE = 4
Constants.NODE_TYPE_PRIMITIVE = 5

-- ========================================
-- Operations
-- ========================================
Constants.OPERATION_METHOD = 0
Constants.OPERATION_FIELD = 1
Constants.OPERATION_ARRAY = 2

-- ========================================
-- Action Types
-- ========================================
Constants.ACTION_GET = 0
Constants.ACTION_SET = 1

-- ========================================
-- Node Colors (AABBGGRR format)
-- ========================================
Constants.COLOR_NODE_TYPE = 0xFF9C27B0        -- Purple
Constants.COLOR_NODE_MANAGED = 0xFF4CAF50      -- Green
Constants.COLOR_NODE_HOOK = 0xFF2196F3         -- Blue
Constants.COLOR_NODE_ENUM = 0xFFE91E63         -- Magenta
Constants.COLOR_NODE_NATIVE = 0xFFFF9800       -- Orange
Constants.COLOR_NODE_PRIMITIVE = 0xFF0097A7    -- Dark Cyan
Constants.COLOR_NODE_METHOD = 0xFFFFC107       -- Yellow
Constants.COLOR_NODE_FIELD = 0xFF8BC34A        -- Lime
Constants.COLOR_NODE_ARRAY = 0xFFFF5722        -- Deep Orange
Constants.COLOR_NODE_HOVER = 0xFF3C3C3C        -- Dark Gray
Constants.COLOR_NODE_SELECTED = 0xFF3C3C3C     -- Dark Gray

-- ========================================
-- Node-Specific Widths
-- ========================================
Constants.PRIMITIVE_NODE_WIDTH = 200

-- ========================================
-- UI Dimensions
-- ========================================
Constants.NODE_WIDTH = 300
Constants.MINIMAP_SIZE = 0.2
Constants.MINIMAP_POSITION = 0  -- bottom-left

-- Style values
Constants.WINDOW_ROUNDING = 7.5
Constants.FRAME_ROUNDING = 5.0
Constants.FRAME_PADDING = Vector2f.new(5, 5)
Constants.MENU_PADDING = Vector2f.new(5, 5)
Constants.COLOR_BUTTON_NORMAL = 0xFF714A29  -- Button color (AABBGGRR)
Constants.COLOR_BUTTON_HOVER = 0xFFFA9642  -- Button hover color (AABBGGRR)

-- ========================================
-- Text Colours
-- ========================================
Constants.COLOR_TEXT_WARNING = 0xFFFFFF00  -- Yellow
Constants.COLOR_TEXT_DEBUG = 0xFFDADADA  -- Light Gray

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