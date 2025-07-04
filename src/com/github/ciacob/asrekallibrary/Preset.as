package com.github.ciacob.asrekallibrary {
    import com.github.ciacob.asshardlibrary.Shard;
    import com.adobe.crypto.MD5;
    import com.github.ciacob.asshardlibrary.IShard;
    import flash.filesystem.File;
    import flash.filesystem.FileStream;
    import flash.filesystem.FileMode;
    import flash.utils.ByteArray;

    public class Preset {

        /**
         * Internal storage medium with built-in ByteArray serialization support
         */
        private var _data:Shard;

        /**
         * Node, inside the internal storage, where meta information will live
         */
        private var $meta:Shard;

        /**
         * Node, inside the internal storage, where actual user settings will live
         */
        private var $settings:Shard;

        /**
         * Helper, trims a string.
         */
        private function _trim(str:String):String {
            if (!str) {
                return '';
            }
            return str.replace(/^\s+|\s+$/g, "");
        }

        /**
         * Loads a Preset that was previously saved to disk via `toDisk()`.
         * @param   file
         *          The file to read the preset from.
         * @return
         */
        public static function fromDisk(file:File):Preset {
            if (!file || !file.exists) {
                return null;
            }
            try {
                const stream:FileStream = new FileStream();
                stream.open(file, FileMode.READ);
                const bytes:ByteArray = new ByteArray();
                stream.readBytes(bytes);
                stream.close();

                // Deserialize into a temporary Shard instance
                const loaded:Shard = new Shard();
                loaded.importFrom(bytes);

                const meta:IShard = loaded.getChildAt(0);
                const settings:IShard = loaded.getChildAt(1);

                // Read-only flag lives under meta; optional
                const readonlyFlag:* = meta.$get('readonly');
                const name:String = meta.$get('name');
                const readonly:Boolean = (readonlyFlag === true);

                return new Preset(name, settings, readonly);
            } catch (e:Error) {
                trace('Failed to load preset from file', file ? file.nativePath ? file.nativePath : file : null);
                return null;
            }
        }

        /**
         * Constructs a new Preset instance.
         *
         * @param name
         *        Optional. A label to associate with this Preset.
         *
         * @param initialSettings
         *        Optional. Initial user settings to populate the Preset with.
         *        Accepted types:
         *        - a Shard instance (deep-cloned),
         *        - or a plain Object (for shallow key-value insertion).
         *
         * @param readonly
         *        Optional. Defaults to false. If true, and both `name` and `initialSettings`
         *        are provided, the Preset will become read-only (frozen).
         */
        public function Preset(name:String = null, initialSettings:Object = null, readonly:Boolean = false) {

            // Initialize internal storage structure
            name = _trim(name);
            const mustLock:Boolean = (readonly && name && initialSettings);

            _data = new Shard;
            $meta = new DetachedShard((name ? {'name': name, 'readonly': mustLock} : null), mustLock);
            $settings = new DetachedShard(initialSettings, mustLock);
            _data.addChild($meta);
            _data.addChild($settings);
        }

        /**
         * Creates a deep copy of this Preset, optionally overriding its read-only status.
         *
         * @param ...readonly
         *        Optional. If a Boolean is provided, it will override this Preset’s
         *        current read-only state. Useful for deriving editable versions
         *        from locked (system) presets.
         *
         * @return A new Preset instance with identical content and structure.
         */
        public function clone(... readonly):Preset {
            const readonlyState:Boolean = (readonly[0] is Boolean) ? readonly[0] as Boolean : readonly;
            return new Preset(name, settings, readonlyState);
        }

        /**
         * Saves a serialized form of this Preset to disk, under given name, optionally overriding.
         * @param   file
         *          File to save under. If save is denied (e.g., not writable location), this function
         *          silently fails and returns `false`. It is recommended that folder access be
         *          validated externally.
         *
         * @param   override
         *          Optional, default false. If file exists and `override` is `false`, this function
         *          silently fails and returns `false`. If override fails, `false` is also returned.
         *
         * @return  Returns `true` whether saving the Preset to disk succeeded, false otherwise.
         */
        public function toDisk(file:File, override:Boolean = false):Boolean {
            if (!file) {
                return false;
            }
            if (file.exists && !override) {
                return false;
            }
            try {
                const bytes:ByteArray = _data.toSerialized();
                const stream:FileStream = new FileStream();
                stream.open(file, FileMode.WRITE);
                stream.writeBytes(bytes);
                stream.close();
                return true;
            } catch (e:Error) {
                trace('Failed to write preset', name, 'to file:', file ? file.nativePath ? file.nativePath : file : null);
                return false;
            }
        }

        /**
         * Returns the unique ID of this Preset.
         */
        public function get uid():String {
            return _data.id;
        }

        /**
         * Returns this Preset's name.
         */
        public function get name():String {
            return $meta.$get('name');
        }

        /**
         * Changes this Preset's name, provided the new name is valid,
         * and the Preset is not readonly.
         */
        public function set name(value:String):void {
            $meta.$set('name', value);
        }

        /**
         * Indicates whether this Preset is immutable (read-only).
         */
        public function get readonly():Boolean {
            return $meta.$get('readonly') as Boolean;
        }

        /**
         * Returns an MD5 digest of this Preset's user settings, uniquely identifying
         * the Preset by content, not metadata.
         * Note: this is computed on each call; client code is encourages to cache.
         */
        public function get hash():String {
            return MD5.hashBytes($settings.toSerialized());
        }

        /**
         * Returns the settings this Preset carries as a IShard implementer with methods
         * such as $set, $get, $delete, addChild, etc.
         * @see IShard
         */
        public function get settings():IShard {
            return $settings;
        }

    }
}

import com.github.ciacob.asshardlibrary.Shard;
import com.github.ciacob.asshardlibrary.IShard;

/**
 * Internal storage class based on Shard. Can be read-write or read-only as needed.
 * Can be populated upon instantiation (readonly mode is only engaged if initial
 * content is provided).
 * @see Shard
 * @see IShard
 */
class DetachedShard extends Shard {
    private var _locked:Boolean = false;

    public function DetachedShard(content:* = null, readonly:Boolean = false) {
        super();

        // Initial content can be populated via either another Shard instance
        // (imports both content and children) or plain Object (imports content
        // only).
        if (content is IShard) {
            this.importFrom((content as IShard).toSerialized());
            _locked = readonly;
        } else if (content && (content is Object)) {
            for (var key:String in content) {
                this.$set(key, content[key]);
            }
            _locked = readonly;
        }
    }

    // Disable node mutation if requested so.
    override public function get isReadonly():Boolean {
        return _locked;
    }

    // Prevent node from accessing the rest of the hierarchy
    override public function get parent():IShard {
        return null;
    }
}
