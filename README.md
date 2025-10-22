# DevTester v2.0
## Visual Node-Based Editor for Monster Hunter

![DevTester v2.0](https://i.imgur.com/VpRqTvL.png)

DevTester v2.0 is a powerful visual scripting tool for Monster Hunter Wilds modding, built on the REFramework. Create complex mod logic through an intuitive node-based interface without writing code.

## Features

### 🎯 **Visual Node-Based Editing**
- Visual connection of data flow
- Real-time execution and debugging
- Clean, organized node graphs

### 🔧 **Node Types**

#### **Starter Nodes**
- **Managed Starter**: Initialize managed objects
- **Hook Starter**: Intercept and modify method calls
- **Native Starter**: Access native game functions

#### **Data Nodes**
- **Primitive Data**: Numbers, strings, booleans
- **Enum Data**: Game enumeration values
- **Variable Data**: Shared variables with persistence

#### **Follower Nodes**
- **Method Follower**: Call object methods
- **Field Follower**: Access object properties
- **Array Follower**: Manipulate collections

#### **Operation Nodes**
- **Math Operations**: Add, subtract, multiply, divide, modulo, power
- **Logic Operations**: AND, OR, NOT, XOR
- **Compare Operations**: Equal, not equal, greater, less, etc.
- **Invert Operation**: Boolean negation

#### **Control Nodes**
- **Select Control**: Conditional branching

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

1. Ensure you have [REFramework](https://github.com/praydog/REFramework) installed for Monster Hunter Wilds
2. Copy the `autorun` folder to your Monster Hunter Wilds mod directory
3. Launch the game with REFramework
4. Access DevTester v2.0 from the REFramework menu

## Quick Start

1. **Launch DevTester**: Press the "DevTester v2.0" button in the REFramework overlay
2. **Create a Starter**: Right-click in the node editor and add a Starter node
3. **Add Operations**: Connect operation nodes to process data
4. **Configure Hooks**: Set up method hooks to intercept game functions
5. **Save Configuration**: Save your setup for reuse

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

This project is part of the Monster Hunter Wilds modding community. Contributions are welcome!

### Development Setup
1. Clone the repository
2. Ensure REFramework development environment
3. Test changes in-game
4. Submit pull requests with detailed descriptions

## Credits

- Built on [REFramework](https://github.com/praydog/REFramework)
- Uses [Dear ImGui](https://github.com/ocornut/imgui) for UI
- Node editor powered by [imnodes](https://github.com/Nelarius/imnodes)