package com.github.ciacob.asrekallibrary {
    import com.github.ciacob.asshardlibrary.Shard;
    import com.adobe.crypto.MD5;
    import com.github.ciacob.asshardlibrary.IShard;

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
            $meta = new DetachedShard((name ? {'name': name} : null), mustLock);
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
            return $meta.isReadonly;
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
