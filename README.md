# DevTester v2.0
## Visual Node-Based Editor for RE Engine Games

![DevTester v2.0](https://i.imgur.com/ZJubBDz.png)

DevTester v2.0 is a powerful visual scripting tool for RE Engine game modding, built on the REFramework. Create complex mod logic through an intuitive node-based interface without writing code.

### Supported Games
DevTester v2.0 works with **any RE Engine game that supports REFramework**, with primary development and testing focused on:
- **Monster Hunter Rise (MHRise)**
- **Monster Hunter Wilds (MHWilds)**

Other RE Engine games may work with varying degrees of compatibility.

## Features

### 🎯 **Visual Node-Based Editing**
- Visual connection of data flow
- Real-time execution and debugging
- Clean, organized node graphs
- **Copy & Paste**: Duplicate nodes and configurations with CTRL+C/CTRL+V

### 🔧 **Node Types**

#### **Starter Nodes**
Entry points for your node graphs - start execution and provide initial data.
- **Managed Starter**: Initialize managed objects from type definitions
- **Type Starter**: Access static types and their members without instances
- **Hook Starter**: Intercept and modify method calls in real-time
- **Native Starter**: Call native game functions directly
- **Player Starter**: Quick access to the player character object (MHRise/MHWilds)

#### **Data Nodes**
Source nodes that provide values to your graph.
- **Primitive Data**: Numbers, strings, booleans with manual input
- **Enum Data**: Game enumeration values with dropdown selection
- **Variable Data**: Shared variables with get/set modes and persistence

#### **Follower Nodes**
Process and manipulate data from parent nodes.
- **Method Follower**: Call methods on objects with parameter support
- **Field Follower**: Get or set object field values
- **Array Follower**: Access array elements by index

#### **Operation Nodes**
Mathematical and logical operations for data processing.
- **Math Operation**: Add, subtract, multiply, divide, modulo, power, min, max
- **Logic Operation**: AND, OR, NAND, NOR
- **Compare Operation**: Equals, not equals, greater than, less than
- **Invert Operation**: Boolean negation (NOT)

#### **Control Nodes**
Control flow and conditional logic.
- **Switch Control**: Multi-way branching based on input values
- **Toggle Control**: Enable/disable pass-through with manual or connected toggle
- **Counter Control**: Count events with configurable start, max, and step values
- **Condition Control**: If/else branching based on boolean conditions

#### **Utility Nodes**
Helper nodes for organization and documentation.
- **Label**: Add text labels and comments to your node graph
- **History Buffer**: Capture and store value history with pause/replay functionality

### 🎣 **Advanced Hooking**
- Method hooking with pre/post callbacks
- Return value overriding
- Parameter manipulation
- Real-time method interception

### 💾 **Save/Load System**
- Save complex node configurations
- Load and modify existing setups
- Persistent variable storage
- Configuration management

### 🔍 **Debugging Tools**
- Real-time node execution monitoring
- Status indicators
- Tooltip information
- Execution flow visualization

## Installation

1. Ensure you have [REFramework](https://github.com/praydog/REFramework) installed for your RE Engine game
2. Copy the `autorun` folder to your game's REFramework directory (typically `<game_directory>/reframework/autorun`)
3. Launch the game with REFramework
4. Access DevTester v2.0 from the REFramework menu (Script Generated UI)

## Quick Start

1. **Launch DevTester**: Press the "DevTester v2.0" button in the REFramework overlay
2. **Create a Starter**: Right-click in the node editor and add a Starter node
3. **Add Operations**: Connect operation nodes to process data
4. **Configure Hooks**: Set up method hooks to intercept game functions
5. **Copy & Paste**: Select nodes and use CTRL+C to copy, CTRL+V to paste with new IDs
6. **Save Configuration**: Save your setup for reuse

## Usage Guide

### Creating Your First Node Graph

1. **Add a Hook Starter**:
   - Select a game type (e.g., `app.PlayerManager`)
   - Choose a method to hook
   - Configure pre/post hook behavior

2. **Add Data Processing**:
   - Connect Primitive Data nodes for input values
   - Use Math Operations for calculations
   - Apply Logic Operations for conditions

3. **Override Return Values**:
   - Connect data nodes to the return override input
   - Use manual input or linked values
   - Monitor the overridden output

### Variable System

- **Shared Variables**: Create Variable Data nodes that share values across the graph
- **Persistence**: Variables can be marked as persistent across sessions
- **Reset Functionality**: Reset variables to their default values

## Configuration Files

DevTester v2.0 stores configurations in JSON format:
- Main window state: `Data.json`
- Node configurations: `YourConfigName.json`

## Contributing

This project is part of the RE Engine modding community. Contributions are welcome!

### Development Setup
1. Clone the repository
2. Ensure REFramework development environment with a supported RE Engine game
3. Test changes in-game (preferably with MHRise or MHWilds)
4. Submit pull requests with detailed descriptions

### Testing Guidelines
- Test with Monster Hunter Rise and/or Monster Hunter Wilds when possible
- Report compatibility issues with other RE Engine games
- Document game-specific behaviors or limitations

## Compatibility

DevTester v2.0 is designed to work with any RE Engine game that supports REFramework. The node-based system dynamically adapts to the game's type system, allowing you to:
- Hook any game method
- Access any game object
- Manipulate game data in real-time

Primary testing and development is done with Monster Hunter Rise and Monster Hunter Wilds, but the tool should function with other RE Engine titles.

## Credits

- Built on [REFramework](https://github.com/praydog/REFramework)
- Uses [Dear ImGui](https://github.com/ocornut/imgui) for UI
- Node editor powered by [imnodes](https://github.com/Nelarius/imnodes)