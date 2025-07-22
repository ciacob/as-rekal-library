package com.github.ciacob.asrekallibrary.events {
    import flash.events.Event;

    public class PresetEvent extends Event {

        public static const LIST_COMPLETE:String = "listComplete";
        public static const LOOKUP_COMPLETE:String = "lookupComplete";
        public static const SET_COMPLETE:String = "setComplete";
        public static const DELETE_COMPLETE:String = "deleteComplete";
        public static const SAVED:String = "presetSaved";
        public static const LOADED:String = "presetLoaded";

        public static const ERROR:String = "presetManagerError";
        public static const CHANGE:String = "presetManagerChange";

        public static const SAVING:String = "presetUiSaving";

        private var _data:*;

        public function PresetEvent(type:String, data:* = null, bubbles:Boolean = false, cancelable:Boolean = false) {
            super(type, bubbles, cancelable);
            _data = data;
        }

        public function get data():* {
            return _data;
        }

        override public function clone():Event {
            return new PresetEvent(type, _data, bubbles, cancelable);
        }

        override public function toString():String {
            return "[PresetEvent type=\"" + type + "\" data=" + _data + "]";
        }
    }
}
