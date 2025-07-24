#### as-rekal-library
# Rekal – Configuration Memory for AIR Applications
### "We can remember it for you wholesale."

Rekal is a lightweight, extensible ActionScript 3 library for managing name–value presets in Adobe AIR desktop applications. It enables applications to define, store, retrieve, and manage structured configuration profiles — from UI settings to functional preferences — with minimal effort and full control.

---

## Features
- **Named Presets**: Store configurations under unique string labels.
- **Content-Hashed**: Identify presets by their serialized structure.
- **Powered by Shard**: Uses [`as-shard-library`](https://github.com/ciacob/as-shard-library) for modular, hierarchical data storage.
- **Disk Persistence**: Fully supports sync and async saving/loading to the filesystem.
- **Robust Test Suite**: 60+ unit tests with full coverage of core features and edge cases.

---

## Getting Started

### Installation
Clone or download the repo, and include the contents of the `src/` directory in your AIR project:
`/src/com/github/ciacob/asrekallibrary`

---

## Usage

### Create a Preset
```as3
const preset:Preset = new Preset("DarkTheme", {bg: 0x000000, fg: 0xFFFFFF});
```

### Save a Preset
```as3
const manager:Manager = new Manager(myPresetsFolder);
manager.$set(preset, preset.name);
```

### Load and Apply a Preset
```as3
const darkPreset:Preset = manager.lookup("DarkTheme");
applySettings(darkPreset.settings); // your own logic
```

### Asynchronous Save
```as3
manager.addEventListener(PresetEvent.SET_COMPLETE, onPresetSaved);
manager.addEventListener(PresetEvent.ERROR, onSaveError);
manager.$setAsync({foo: 42}, "MyPreset");
```

### Preset Format
Presets are saved to disk as binary files, named like:
```bash
md5(<label>)
```
> This allows one to use any chars in a Preset name, because it always gets hashed to a fixed-length, OS-safe string.

They serialize two internal Shard nodes:
- Metadata (name, readonly)
- User-defined settings

## Built-in Preset Manager UI Component
The library includes a minimal, skinnable, out-of-the-box UI component for managing presets using the `Manager` class. This component supports:
- Listing existing presets (read-only and read-write).
- Selecting and applying presets.
- Saving new or updated presets.
- Deleting user presets.
- Programmatic initialization and skinning.

### Features
- Fully decoupled from preset data: never mutates presets directly.
- Event-based interaction: emits `PresetEvent.CHANGE` and `PresetEvent.SAVING`.
- Typing into the ComboBox selects existing presets or prepares new ones.
- Built-in prompt and status message area with auto-dismiss timer.
- Button state management is fully automatic.
- Style hooks available for full visual control.

### Usage
Add the component to your MXML:
```xml
<yourNamespace:PresetManagerUi
    id="presetUi"
    width="100%"
    styleName="presetUi"
    headerText="My Presets"
    statusTimeOut="5"
    keepSelection="false"
    showHeader="true"
    promptText="Choose or name a preset..."
    deleteButtonContent="❌"
    saveButtonContent="💾"
/>
```

Then, wire it to a Manager instance:
```actionscript
presetUi.initializeWith(myManager);
```

And listen for preset events:
```actionscript
presetUi.addEventListener(PresetEvent.CHANGE, onPresetApplied);
presetUi.addEventListener(PresetEvent.SAVING, function(e:PresetEvent):void {
    const commit:Function = e.data.commit;
    // Provide your current settings as an Object or Shard
    commit({ brightness: 0.5, contrast: 1.2 });
});
```

### Style Hooks
You can control layout and look using the following styles:
| Style Name                     | Purpose                                             |
| ------------------------------ | --------------------------------------------------- |
| `headerStyle`                  | Applied to the label above the ComboBox             |
| `footerStyle`                  | Applied to the container holding the status message |
| `comboStyle`                   | Applied to the ComboBox itself                      |
| `saveButtonStyle`              | Applied to the Save button                          |
| `deleteButtonStyle`            | Applied to the Delete button                        |
| `vGap`, `hGap`                 | Vertical and horizontal gaps                        |
| `padding`, `paddingLeft`, etc. | Layout padding (mirrors `VGroup` styles)            |

Example:
```css
.presetUi {
    comboStyle: myPresetComboStyle;
    saveButtonStyle: myPresetButtonsStyle;
    deleteButtonStyle: myPresetButtonsStyle;
}

.myPresetComboStyle {
    padding: 5;
}

.myPresetButtonsStyle {
    fontSize: 14;
    skinClass:ClassReference("my.fancy.button.SkinClass");
}
```

> **Notes:**
> - The component only emits CHANGE when a valid, existing preset is selected.
> - It does not monitor changes in your working settings; this is left to your app logic (if desired).
> - You can override or hide the header as needed.

### Source
The component lives in:
```bash
src/com/github/ciacob/asrekallibrary/ui/PresetManagerUi.mxml
```

## License
MIT © 2025 [ciacob](https://github.com/ciacob)

## Contact
Feedback, ideas, or bugs? [Open an issue](https://github.com/ciacob/as-rekal-library/issues) or start a discussion.