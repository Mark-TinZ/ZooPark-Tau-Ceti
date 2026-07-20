---
name: godot-ui-generation
description: Use this skill when the user asks you to create, modify, design, or layout any UI scene, menu, HUD, or control panel in Godot 4.
---

# Godot 4 UI Generation Guidelines

This skill guides the agent in generating beautiful, clean, responsive, and logically structured Godot 4 user interfaces.

## 1. Directory Structure
All UI-related files should be organized within a dedicated directory (typically `res://ui/` or `res://scenes/ui/`).
- Layouts/Scenes: `.tscn`
- Scripts: `.gd`
- Themes/Styles: `.tres`

## 2. Structural Principles for UI Scenes
Always design UI scenes hierarchically using containers. A typical beautiful panel layout:

```
CanvasLayer (or Control as root)
└── PanelContainer (Main background panel)
    └── MarginContainer (Inner padding, e.g., 15-20px)
        └── VBoxContainer (Vertical layout)
            ├── Label (Title / Header)
            ├── HSeparator (Sleek divider line)
            ├── ScrollContainer (If content is dynamic / long)
            │   └── VBoxContainer (Content container)
            │       ├── HBoxContainer (Row with label and value/input)
            │       └── GridContainer (For inventory grids or uniform tables)
            └── HBoxContainer (Footer buttons, e.g., "Cancel", "Apply")
```

### Key Node Options
* **PanelContainer**: Automatically wraps content in a styled panel. Best for windows, dialogs, cards.
* **MarginContainer**: Adds padding around its children. Always set override constants (e.g. `theme_override_constants/margin_left = 20`, etc.).
* **ScrollContainer**: Essential for lists or text blocks that might overflow on smaller screens.
* **AspectRatioContainer / CenterContainer**: Use to prevent stretching of icons or square buttons.

## 3. Style and Theming
* **Do not use Raw Overrides**: Avoid manually changing `self_modulate` or applying custom flat styles inline on multiple individual buttons. 
* **Create/Use a Theme**: Ensure a central `Theme` resource is applied. If none exists, propose creating a basic, beautiful one with a modern dark theme style:
  - Background panels: Deep charcoal grey (`#1e1e24` or `#121214`)
  - Accent colors: Soft teal/blue (`#4d96ff` or `#3b82f6`) or amber for warnings.
  - Buttons: Rounded corners (corner radius 4-8px), subtle gradient or solid color, with clear hover and pressed state colors.
  - Text: Clean sans-serif fonts with good line spacing.

## 4. Scripting Logic in Godot 4
When generating or modifying the UI controller script:
* **Strong Typing**: Use typed variables and return types (`var button: Button`, `func _ready() -> void`).
* **Signal Connections**: Connect signals in `_ready()` via code:
  ```gdscript
  func _ready() -> void:
      close_button.pressed.connect(_on_close_button_pressed)
      volume_slider.value_changed.connect(_on_volume_changed)
  ```
* **Decouple Game Logic**: Do not access global gameplay states directly from UI elements. Use a Controller pattern or emit custom signals from the UI root node:
  ```gdscript
  signal settings_saved(settings_dict: Dictionary)
  ```

## 5. Integrating with Godot MCP Tools
Always leverage the installed `godot` MCP tools for automating scene operations, validating code correctness, and inspecting UI states at runtime:

### Static Analysis & Verification (No game running)
* **`validate_script`**: Run this immediately after creating or modifying any GDScript UI controller file to ensure there are no syntax or typing errors (e.g., `validate_script(path: "res://ui/settings_menu.gd")`).
* **`read_scene`**: Use to parse a `.tscn` file and examine its node hierarchy to verify that `MarginContainer`, `PanelContainer`, and size flags are correctly configured without manually viewing the raw scene text.
* **`modify_scene_node`**: Use to adjust properties (like `anchors_preset`, themes, or constants) directly inside the `.tscn` files instead of manual regex edits.
* **`create_resource`**: Use to programmatically generate theme files (`.tres`) or styles when setting up theme elements.

### Runtime UI Testing & Manipulation (When game is running)
* **`game_get_node_info`**: Use to introspect active UI nodes to verify their runtime hierarchy, parameters, and visible states.
* **`game_ui_theme`**: Run to dynamically override colors, constants, and fonts on running UI elements to preview adjustments without restarting the game.
* **`game_eval`**: Execute code blocks (e.g., triggering a menu popup using `game_eval("get_node('/root/Main/SettingsMenu').show()")`) to verify animations and show/hide transitions.
* **`game_get_errors` & `game_get_logs`**: Retrieve runtime warnings or script errors during UI interactions.
* **`game_click` / `game_mouse_drag` / `game_key_press`**: Simulate user interaction with buttons, sliders, and text fields to verify state progression and signal logic.

## 6. Walkthrough for UI Task Execution
1. **Search & Introspect**: Look for existing UI styles, folders, and `Theme` assets (`.tres`).
2. **Propose Scene Hierarchy**: Describe the container hierarchy in text form and request user feedback.
3. **Generate Scene**: Use Godot MCP `write_file` or `modify_scene_node` to build the `.tscn` layout.
4. **Attach and Code Script**: Add the controller GDScript, attach it using `attach_script`, and validate it immediately using `validate_script`.
5. **Simulate/Run & Verify**: Ask the user to run the project. Use runtime commands (`game_get_node_info`, `game_click`, `game_get_errors`) to ensure the layout behaves correctly and errors are captured.

