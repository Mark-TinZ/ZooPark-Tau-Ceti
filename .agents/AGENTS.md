# Godot UI Generation Rules

Whenever you are asked to create, modify, or refactor any user interface (UI) components or scenes in this project, you must adhere to the following rules:

1. **Use Container-Based Layouts**: Never place Control nodes (buttons, labels, text fields) using absolute pixel coordinates. Always organize them using Godot's container system (`MarginContainer`, `PanelContainer`, `VBoxContainer`, `HBoxContainer`, `GridContainer`, `ScrollContainer`).
2. **Ensure Responsiveness (Anchors & Size Flags)**:
   - Use `anchors_preset` properly (e.g., Full Rect, Center, Top Wide) to ensure the UI scales correctly on different resolutions.
   - Use `size_flags_horizontal` and `size_flags_vertical` (e.g., `Fill` and `Expand`) on child components rather than hardcoding minimum sizes unless necessary.
3. **Respect Project Themes**: Before styling any component, check if there is an existing `.tres` Theme file in the project (e.g. in `res://ui/` or `res://assets/`). If a theme exists, assign it to the root node of the UI scene instead of manually overriding styles on individual nodes.
4. **Logical Naming Convention**: Give Control nodes meaningful, camel-case or snake-case names reflecting their purpose (e.g., `MainMenu`, `SaveButton`, `VolumeSlider`, `StatusLabel`). Avoid default names like `Button`, `Control`, or `Label2`.
5. **Separation of Logic and Presentation**:
   - UI layout should be defined in the `.tscn` file.
   - UI behavior (clicks, updates) must be handled in an attached GDScript.
   - Use clean signal connections, preferably via code in the `_ready()` function using the new Godot 4 syntax: `button.pressed.connect(_on_button_pressed)`.
