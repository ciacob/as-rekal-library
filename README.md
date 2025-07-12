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
<md5_hash>_<label>
```
They serialize two internal Shard nodes:
- Metadata (name, readonly)
- User-defined settings

## License
MIT © 2025 [ciacob](https://github.com/ciacob)

## Contact
Feedback, ideas, or bugs? [Open an issue](https://github.com/ciacob/as-rekal-library/issues) or start a discussion.
