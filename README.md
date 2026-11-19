# SoboModSettings
A [Sobosuba](https://store.steampowered.com/app/1946560/sobosuba) framework that loads other mods' config files into the in-game settings menu.

Tested on Sobosuba v1.3.11


## Installation:
Use [Sobosuba Mod Manager](https://github.com/T0y-9n/sobosuba-mods), or do the following:

Extract `modsettings.zip` from the [latest release](https://github.com/Typhe681/SoboModSettings/releases/latest) into Sobosuba's userdata folder

* **Windows:** `%APPDATA%\Godot\app_userdata\sobosuba`
* **Linux:** `~/.local/share/godot/app_userdata/sobosuba`


It should look like this:
```
├── styles
|   └── modsettings_bootstrap.tres
└── modsettings
    ├── modsettings.gd
    └── broadcaster.gd
```

# For Developers:

## Config files
To add settings for your mod, create a .cfg file in Sobosuba's userdata folder. The framework automatically scans the userdata folder and its immediate subdirectories for config files.

Each config file creates a separate page in the Mods menu.

A config file consists of a [meta] section and one section for each setting.
```
[meta]

name="Example Mod"
description="An example mod with every kind of config button"

[example_bool]

type="bool"
label="example bool"
description="A simple toggle button"
value=false

[example_choice]

type="choice"
label="example choice"
description="Cycles through multiple choices"
options=["option 1", "option 2", "option 3"]
value=0

[example_float]

type="float"
label="example float"
description="A slider for a range of values"
min=0.0
max=100.0
step=1.0
value=50.0

[example_color]

type="color"
label="example color"
description="A tiny color selection ui"
value=Color(0.346704, 0, 1, 1)

```

### Meta section

The `[meta]` section contains information about the mod itself.

| Key | Description | Required |
|---|---|---|
| `name` | Name displayed in the settings menu | Yes |
| `description` | Tooltip shown when hovering over the mod's button | No |

### Setting sections

Every section other than `[meta]` represents a setting.

| Key | Description | Required |
|---|---|---|
| `type` | Setting type | Yes |
| `label` | Display name (defaults to the section name) | No |
| `description` | Tooltip shown when hovering over the setting | No |
| `value` | Initial setting value | No |

All other properties are optional. Choice settings require a non-empty options array.

For `choice` settings, `value` is the zero-based index of the selected option

### Saving settings

When a setting is changed, its new value is automatically written to the corresponding config file.

Your mod is responsible for reading the config values and applying them. The framework doesn't automatically change your mod's runtime behavior lol.

## Config change notifications

To react to settings changes without periodically reloading your config, connect to the broadcaster's `config_changed` signal:

```gdscript
func _ready() -> void:
    var broadcaster = get_tree().root.get_meta("modsettings_broadcaster", null)
    if broadcaster:
        broadcaster.config_changed.connect(_on_config_changed)

func _on_config_changed(path: String, section: String, value: Variant) -> void:
    pass
```
The signal is emitted after a successful save.

- `path`: Path to the config file.
- `section`: Name of the setting's section.
- `value`: The new value.
