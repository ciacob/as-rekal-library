package com.github.ciacob.asrekallibrary {
    import com.github.ciacob.asrekallibrary.events.PresetEvent;
    import flash.events.EventDispatcher;
    import flash.filesystem.File;
    import flash.events.FileListEvent;
    import com.adobe.crypto.MD5;
    import flash.events.IOErrorEvent;
    import com.github.ciacob.asshardlibrary.IShard;
    import com.github.ciacob.asshardlibrary.Shard;
    import flash.events.Event;

    public class Manager extends EventDispatcher {

        /**
         * Internal storage for the directory where presets are expected to live.
         */
        private var _homeDir:File;

        /**
         * Internal storage to hold the maximum accepted preset label length.
         */
        private var _labelMaxLength:uint = 40;

        /**
         * Internal storage to cache last retrieved list of Presets, externally accessible via
         * `get lastListed`. Saves CPU time giving the caller the chance to use caching when
         * appropriate.
         */
        private var _lastListed:Vector.<Preset>;

        /**
         * @constructor
         * @param   homeDir
         *          Directory where managed presets will live on disk.
         *
         * @param   labelMaxLength
         *          Optional, default `0`. Limits the maximum length of a Preset label, in
         *          number of chars. If missing or `0`, the default of `40` is assumed.
         *
         * @throws  If an invalid `homeDir` was given. This includes `null`, not existing on disk,
         *          or not a folder.
         *
         * Note: do not hook two `Manager` instances to the same `homeDir` directory, or undefined behavior
         * could result.
         */
        public function Manager(homeDir:File, labelMaxLength:uint = 0) {
            if (!homeDir || !homeDir.exists || !homeDir.isDirectory) {
                throw new ArgumentError("Invalid home directory provided.");
            }
            _homeDir = homeDir;
            if (labelMaxLength) {
                _labelMaxLength = labelMaxLength;
            }
        }

        /**
         * Internal delegatee that attempts to redeem Preset instances out of disk files and optionally
         * filter and sort them before returning. Used by both `list` and `listAsync`.
         *
         * @param   files
         *          The raw list of files to process.
         *
         * @param   filter
         *          An optional filtering function to apply to resulting Presets.
         *
         * @param   sort
         *          An optional sorting function to apply to the resulting list of Presets, as a whole.
         *
         * @return  A Vector of (filtered and sorted) Preset instances.
         */
        private function _processRawFiles(files:Array, filter:Function = null, sort:Function = null):Vector.<Preset> {
            const result:Vector.<Preset> = new <Preset>[];
            if (!files || !files.length) {
                _lastListed = result;
                return result;
            }
            for each (var file:File in files) {
                if (file.isDirectory) {
                    continue;
                }
                const preset:Preset = Preset.fromDisk(file);
                if (preset) {
                    if (filter === null || filter(preset)) {
                        result.push(preset);
                    }
                }
            }

            if (sort != null) {
                result.sort(sort);
            }
            _lastListed = result;
            return result;
        }

        /**
         * Internal helper used by both `lookup` and `lookupAsync`. Establishes whether a given
         * `preset` corresponds or not to a given `criteria`.
         *
         * @param   preset
         *          A preset to test.
         *
         * @param   criteria
         *          A criteria to test by. Can be a Preset, IShard, Object (all to be resolved
         *          to a hash) or a String (to be resolved to a name).
         *
         * @return  Returns `true` if test passes, `false` otherwise (and also for a missing
         *          criteria).
         */
        private function _matches(preset:Preset, criteria:*):Boolean {
            if (!preset || !criteria) {
                return false;
            }
            if (criteria is Preset) {
                return preset.hash === (criteria as Preset).hash;
            }
            if (criteria is IShard) {
                return preset.hash === MD5.hashBytes((criteria as IShard).toSerialized(true));
            }
            if (criteria is String) {
                return preset.name === criteria;
            }
            if (criteria is Object) {
                const temp:Shard = new Shard();
                for (var key:String in criteria) {
                    temp.$set(key, criteria[key]);
                }
                return preset.hash === MD5.hashBytes(temp.toSerialized(true));
            }
            return false;
        }

        /**
         * Looks up and returns the first matching Preset from the home directory.
         *
         * @param   criteria
         *          The value to use for lookup. Can be:
         *          - A `Preset` instance: match is based on `hash`.
         *          - A `Shard` or plain `Object`: interpreted as settings, match is based on `hash`.
         *          - A `String`: interpreted as the `name` of the Preset.
         *
         * @param   presets
         *          Optional, a pool of presets to look into. Gives caller code a chance to leverage
         *          caching, when appropriate. If missing, `lookup` calls `list` under the hood.
         *
         * @return  A matching Preset, or `null` if not found.
         */
        public function lookup(criteria:*, presets:Vector.<Preset> = null):Preset {
            if (!presets) {
                presets = list();
            }

            for each (var preset:Preset in presets) {
                if (_matches(preset, criteria)) {
                    return preset;
                }
            }
            return null;
        }

        /**
         * Asynchronously looks up the first matching Preset.
         *
         * Dispatches:
         * - `PresetEvent.LOOKUP_COMPLETE` with the found Preset (or null)
         * - `PresetEvent.ERROR` if listing fails
         *
         * @param criteria The value to use for lookup.
         */
        public function lookupAsync(criteria:*):void {
            const self:Manager = this;

            const unbind:Function = function():void {
                self.removeEventListener(PresetEvent.LIST_COMPLETE, onListed);
                self.removeEventListener(PresetEvent.ERROR, onListError);
            }

            const onListed:Function = function(event:PresetEvent):void {
                unbind();
                const matches:Vector.<Preset> = event.data as Vector.<Preset>;
                const match:Preset = matches.length > 0 ? matches[0] : null;
                dispatchEvent(new PresetEvent(PresetEvent.LOOKUP_COMPLETE, match));
            };

            const onListError:Function = function(event:PresetEvent):void {
                unbind();
                dispatchEvent(event.clone());
            };

            const filter:Function = function(preset:Preset):Boolean {
                return _matches(preset, criteria);
            }

            addEventListener(PresetEvent.LIST_COMPLETE, onListed);
            addEventListener(PresetEvent.ERROR, onListError);
            listAsync(filter);
        }

        /**
         * Synchronously lists all valid Presets in the home directory.
         *
         * @param filter Optional. A filter function that takes a Preset and returns a Boolean.
         * @param sort   Optional. A sort function that compares two Presets.
         *
         * @return Vector of matching Presets.
         */
        public function list(filter:Function = null, sort:Function = null):Vector.<Preset> {
            const files:Array = _homeDir.getDirectoryListing();
            return _processRawFiles(files, filter, sort);
        }

        /**
         * Asynchronously lists all valid Presets and dispatches PresetEvent.LIST_COMPLETE.
         *
         * @param filter Optional. A filter function that takes a Preset and returns a Boolean.
         * @param sort   Optional. A sort function that compares two Presets.
         *
         * @eventType   PresetEvent - PresetEvent.LIST_COMPLETE
         *              Dispatched when Presets have been successfully listed. The `data` property
         *              of the event holds a vector of Preset instances.
         *
         * @eventType   PresetEvent - PresetEvent.ERROR
         *              Dispatched when listing the Presets has failed. The `data` property
         *              of the event holds low-level information to help debugging.
         */
        public function listAsync(filter:Function = null, sort:Function = null):void {
            const unbind:Function = function():void {
                _homeDir.removeEventListener(FileListEvent.DIRECTORY_LISTING, onDirListed);
                _homeDir.removeEventListener(IOErrorEvent.IO_ERROR, onDirListingError);
            }

            const onDirListed:Function = function(event:FileListEvent):void {
                unbind();
                const files:Array = event.files;
                const result:Vector.<Preset> = _processRawFiles(files, filter, sort);
                dispatchEvent(new PresetEvent(PresetEvent.LIST_COMPLETE, result, true));
            }

            const onDirListingError:Function = function(event:IOErrorEvent):void {
                unbind();
                dispatchEvent(new PresetEvent(PresetEvent.ERROR, event.text, true));
            }

            _homeDir.addEventListener(FileListEvent.DIRECTORY_LISTING, onDirListed);
            _homeDir.addEventListener(IOErrorEvent.IO_ERROR, onDirListingError);
            _homeDir.getDirectoryListingAsync();
        }

        /**
         * Synchronously attempts to save a Preset to disk inside the `homeDir` the manager was
         * instantiated with.
         * NOTE: do not use any other mechanisms for saving Presets to the `homeDir`. Use only
         * this `$set` method to do do, or the ability of this method to detect duplicates could
         * be compromised
         *
         * @param   data
         *          The settings to store for that Preset. Can be sourced from:
         *          - an in-memory Preset, or
         *          - an IShard implementor instance (assumed to be a settings node of a Preset), or
         *          - an Object (assumed to be the raw settings to be saved).
         *
         * @param   name
         *          A label to associate with the preset. It must not exceed the `labelMaxLength`
         *          the manager was instantiated with, or saving will fail. Preset names must be
         *          unique within a specific `homeDir` (see next).
         *
         * @param   overwrite
         *          Optional. If `false` (default), denies saving if a Preset with the same `name`
         *          already exists. If `true`, such a Preset is silently overwritten.
         *
         * @return  Returns a numeric code to indicate the outcome of the attempted save. Note that,
         *          if several scenarios apply at the same time, the lower code is returned.
         *          Positive realm is success, negative realm is error, zero is neither:
         *         - `0` if saving is not needed (because a Preset with the same `name` and
         *          `hash` already exists).
         *         - `1` if Preset was novel and was successfully saved.
         *         - `2` if a Preset with the same name existed, but it was not read-only, and
         *           `overwrite` was `true`, and it was was successfully overwritten.
         *         - `-1` if a Preset with the same name existed and override was false (save was
         *           aborted).
         *         - `-2` if a Preset with the same name existed and it was read-only (save was aborted).
         *         - `-3` if missing or invalid `data` (save was aborted).
         *         - `-4` if missing or invalid `name`, including a name that's over `labelMaxLength`
         *           characters (save was aborted).
         *         - `-5` if anything else prevented save from succeeding, such as missing write
         *           permissions on the target file or on the `homeDir`.
         */
        public function $set(data:*, name:String, overwrite:Boolean = false):int {

            // Missing or invalid `name`
            name = name ? name.replace(/^\s+|\s+$/g, "") : null;
            if (!name || name.length > _labelMaxLength) {
                return -4;
            }

            var preset:Preset;
            if (data is Preset) {
                preset = new Preset(name, (data as Preset).settings, (data as Preset).readonly);
            } else if (data is IShard || data is Object) {
                preset = new Preset(name, data, false);
            } else {
                // Missing or invalid `data`
                return -3;
            }

            // If we could not instantiate a Preset, this is also due to invalid `data`.
            if (!preset) {
                return -3;
            }

            // Get a presets registry to work with
            if (!_lastListed) {
                list();
            }

            // Try to locate an existing preset with the same name
            const existingPreset:Preset = lookup(name, _lastListed);
            if (existingPreset) {

                // No save needed
                if (existingPreset.hash == preset.hash) {
                    return 0;
                }

                // Readonly preset
                if (existingPreset.readonly) {
                    return -2;
                }

                // `overwrite` not given for an existing preset.
                if (!overwrite) {
                    return -1;
                }
            }

            // Attempt to actually save the preset to disk. If it fails, is for unknown reasons
            // (-5), as we addressed everything else above. If it succeeds, it is either because
            // of a non existing Preset (1), or an existing and overwritten Preset (2).
            const fileName:String = preset.hash + "_" + name;
            const file:File = _homeDir.resolvePath(fileName);
            const result:uint = preset.toDisk(file, true) ? existingPreset ? 2 : 1 : -5;

            // We take a shortcut by upfront caching the saved Preset.
            if (result > 0) {
                _lastListed.push(preset);
            }

            return result;
        }

        /**
         * Asynchronously attempts to save a Preset to disk inside the `homeDir` the manager was
         * instantiated with. Does not return a value; use the events emitted by the Manager
         * class instead.
         *
         * @param   data
         *          The settings to store for that Preset. Can be sourced from:
         *          - an in-memory Preset, or
         *          - an IShard implementor instance (assumed to be a settings node of a Preset), or
         *          - an Object (assumed to be the raw settings to be saved).
         *
         * @param   name
         *          A label to associate with the preset. It must not exceed the `labelMaxLength`
         *          the manager was instantiated with, or saving will fail. Preset names must be
         *          unique within a specific `homeDir` (see next).
         *
         * @param   overwrite
         *          Optional. If `false` (default), denies saving if a Preset with the same `name`
         *          already exists. If `true`, such a Preset is silently overwritten, provided
         *          not read-only.
         *
         * @eventType   PresetEvent - PresetEvent.ERROR
         *              Dispatched when:
         *              - Saving the Preset failed, or
         *              - Preset was read only (save was aborted), or
         *              - Preset was not read only, but `overwrite` was not given (save was aborted), or
         *              - Bad `data` was given (save was aborted), or
         *              - A bad `name` was given (save was aborted), or
         *              - Internally extracting the list with known presets failed (needed to determine
         *                unicity; save was aborted).
         *              In all these cases, the `data` property of the event is an Object that contains an
         *              error code and a textual representation.
         *
         * @eventType   PresetEvent - PresetEvent.SET_COMPLETE
         *              Dispatched when:
         *              - Saving the Preset succeeded, or
         *              - There was no need to save (because an identical Preset was found to exist).
         *              In both cases, the `data` property of the event is an Object with a numeric code and
         *              a Preset instance for immediate use.
         *
         * Note: see `$set` for the numeric codes in use.
         */
        public function $setAsync(data:*, name:String, overwrite:Boolean = false):* {
            var existingPreset:Preset = null;
            var preset:Preset = null;

            // Helper: dispatches error events
            const errOut:Function = function(code:int, message:String):void {
                dispatchEvent(new PresetEvent(PresetEvent.ERROR, {code: code, reason: message}, true));
            }

            // Helper: releases event listeners
            const unbind:Function = function():void {
                preset.removeEventListener(PresetEvent.SAVED, onSaved);
                preset.removeEventListener(PresetEvent.ERROR, onError);
                removeEventListener(PresetEvent.ERROR, onListingFailed);
                removeEventListener(PresetEvent.LIST_COMPLETE, onListingDone);
            }

            // Listener: executed when saving the Preset succeeded 
            const onSaved:Function = function(e:PresetEvent):void {
                unbind();
                if (_lastListed) {
                    _lastListed.push(preset);
                }
                dispatchEvent(new PresetEvent(PresetEvent.SET_COMPLETE, {code: existingPreset ? 2 : 1,
                        preset: preset}));
            };

            // Listener: executed when saving the Preset failed
            const onError:Function = function(e:PresetEvent):void {
                unbind();
                errOut(-5, e.data && e.data.reason ? e.data.reason : "Unknown failure");
            };

            // Listener: executed when listing the known presets completed. Also called directly
            // if a cached list of Presets was already available.
            const onListingDone:Function = function(...ignore):* {
                unbind();
                existingPreset = lookup(name, _lastListed);
                if (existingPreset) {

                    // Early exit: no save needed
                    if (existingPreset.hash == preset.hash) {
                        dispatchEvent(new PresetEvent(PresetEvent.SET_COMPLETE, {code: 0, preset: existingPreset}));
                        return;
                    }

                    // Early exit: preset was read-only
                    if (existingPreset.readonly) {
                        return errOut(-2, "Cannot overwrite read-only preset");
                    }

                    // Early exit: preset exists and `overwrite` was not given.
                    if (!overwrite) {
                        return errOut(-1, "Overwrite not allowed");
                    }
                }

                const fileName:String = preset.hash + "_" + name;
                const file:File = _homeDir.resolvePath(fileName);
                preset.addEventListener(PresetEvent.SAVED, onSaved);
                preset.addEventListener(PresetEvent.ERROR, onError);
                preset.toDiskAsync(file, true);
            }

            // Listener: executed when listing the known presets failed
            const onListingFailed:Function = function(event:PresetEvent):void {
                unbind();
                errOut(-5, String(event.data));
            }

            // MAIN LOGIC
            // Early exit: name was invalid
            name = name ? name.replace(/^\s+|\s+$/g, "") : null;
            if (!name || name.length > _labelMaxLength) {
                return errOut(-4, "Invalid name");
            }

            // Try to source the new Preset to save
            if (data is Preset) {
                preset = new Preset(name, (data as Preset).settings, (data as Preset).readonly);
            } else if (data is IShard || data is Object) {
                preset = new Preset(name, data, false);
            } else {

                // Early exit: source `data` was invalid
                return errOut(-3, "Invalid data");
            }

            // Ensure we have a list of known Presets to operate on
            if (!_lastListed) {
                addEventListener(PresetEvent.ERROR, onListingFailed);
                addEventListener(PresetEvent.LIST_COMPLETE, onListingDone);
                listAsync();
            } else {
                onListingDone();
            }
        }

        /**
         * Synchronously deletes a Preset from disk.
         * Uses `lookup` under the hood, which may use `list` if needed.
         * @see list
         * @see lookup
         *
         * @param   criteria
         *          A value to internally look up, prior to deletion. Can be:
         *          - A `Preset` instance: match is based on `hash`.
         *          - A `Shard` or plain `Object`: interpreted as settings, match is based on `hash`.
         *          - A `String`: interpreted as the `name` of the Preset.
         *          Note that `$delete` only affects Presets that exist on disk. Providing a newly-created,
         *          no-yet-stored Preset will have no effect.
         *
         * @return Returns a numeric code representing the outcome:
         *         - `1`  if deletion succeeded.
         *         - `0`  if no matching stored Preset was found (nothing to delete).
         *         - `-1` if the Preset is read-only.
         *         - `-2` if deletion failed due to I/O or any other error.
         */
        public function $delete(criteria:*):int {
            const preset:Preset = lookup(criteria as String, _lastListed);

            // Early exit: we could not resolve `criteria` to a stored Preset.
            if (!preset) {
                return 0;
            }

            // Early exit: the Preset `criteria` resolved to was readonly.
            if (preset.readonly) {
                return -1;
            }

            const fileName:String = preset.hash + "_" + preset.name;
            const file:File = _homeDir.resolvePath(fileName);
            try {
                file.deleteFile(); // Will throw if fails

                // Shortcut: update the cache directly
                if (_lastListed) {
                    const index:int = _lastListed.indexOf(preset);
                    if (index >= 0) {
                        _lastListed.splice(index, 1);
                    }
                }
                return 1;
            } catch (e:Error) {
                trace("Deletion failed:", e.message);
                return -2;
            }

            // We can only get down here in error
            return -2;
        }

        /**
         * Asynchronously deletes a Preset from disk. Emits events to signal the outcome.
         *
         * @param nameOrPreset Either the name of the Preset to delete (String), or a Preset instance.
         *
         * @eventType PresetEvent.DELETE_COMPLETE
         *            Dispatched when deletion completes. The event's `data` includes:
         *            - `code` = 1 if deleted, 0 if not found.
         *            - `preset` = the Preset (if found).
         *
         * @eventType PresetEvent.ERROR
         *            Dispatched when deletion fails (read-only or I/O error). The `data` includes:
         *            - `code` = -1 (read-only) or -2 (file system error),
         *            - `reason` = explanation
         */
        public function $deleteAsync(nameOrPreset:*):* {
            var file:File = new File;
            var preset:Preset = null;

            // Helper: dispatches error events
            const errOut:Function = function(code:int, message:String):void {
                dispatchEvent(new PresetEvent(PresetEvent.ERROR, {code: code, reason: message}, true));
            }

            // Helper: releases event listeners
            const unbind:Function = function():void {
                file.removeEventListener(Event.COMPLETE, onDeleted);
                file.removeEventListener(IOErrorEvent.IO_ERROR, onError);
                removeEventListener(PresetEvent.ERROR, onListingFailed);
                removeEventListener(PresetEvent.LIST_COMPLETE, onListingDone);
            }

            // Listener: executed when a Preset file has been successfully removed from disk
            const onDeleted:Function = function():void {
                unbind();
                if (_lastListed) {
                    const index:int = _lastListed.indexOf(preset);
                    if (index >= 0) {
                        _lastListed.splice(index, 1);
                    }
                }
                dispatchEvent(new PresetEvent(PresetEvent.DELETE_COMPLETE, {code: 1, preset: preset}));
            };

            // Listener: executed when a Preset file removal has failed (e.g., security errors)
            const onError:Function = function(e:IOErrorEvent):void {
                unbind();
                errOut(-2, e.text)
            };

            // Listener: executed when listing the known presets failed
            const onListingFailed:Function = function(event:PresetEvent):void {
                unbind();
                errOut(-2, event.data || "Listing failed before delete attempt.");
            }

            // Listener: executed when listing the known presets completed. Also called directly
            // if a cached list of Presets was already available.
            const onListingDone:Function = function(...ignore):* {
                preset = lookup(nameOrPreset, _lastListed);
                if (!preset) {
                    dispatchEvent(new PresetEvent(PresetEvent.DELETE_COMPLETE, {code: 0, preset: null}));
                    return;
                }
                if (preset.readonly) {
                    return errOut(-1, "Preset is read-only");
                }

                const fileName:String = preset.hash + "_" + preset.name;
                file = _homeDir.resolvePath(fileName);
                try {
                    file.addEventListener(Event.COMPLETE, onDeleted);
                    file.addEventListener(IOErrorEvent.IO_ERROR, onError);
                    file.deleteFileAsync();
                } catch (e:Error) {
                    onError(new IOErrorEvent(IOErrorEvent.IO_ERROR, false, false, e.message));
                }
            }


            // MAIN LOGIC
            // Ensure we have a list of known Presets to operate on
            if (!_lastListed) {
                addEventListener(PresetEvent.ERROR, onListingFailed);
                addEventListener(PresetEvent.LIST_COMPLETE, onListingDone);
                listAsync();
            } else {
                onListingDone();
            }
        }

        /**
         * Public getter for the home directory this manager has been instantiated with.
         */
        public function get homeDir():File {
            return _homeDir;
        }

        /**
         * Public getter for the last cached listing of presets. Use where appropriate.
         */
        public function get lastListed():Vector.<Preset> {
            return _lastListed;
        }

        /**
         * Public getter for the maximum length in use for preset labels.
         */
        public function get labelMaxLength():uint {
            return _labelMaxLength;
        }
    }
}
