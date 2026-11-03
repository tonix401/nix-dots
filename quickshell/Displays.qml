pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Display profiles: one saved arrangement per set of connected displays. DisplayMenu's Apply saves
// it (where each display sits, its resolution, refresh rate and scale, which one mirrors or is off),
// and it is put back whenever that set is connected again, at startup, and after a Hyprland config
// reload (which brings back hyprland.lua's monitor rules). A profile is the list of hl.monitor rules
// the menu applied, each display named by its description (make, model, serial) instead of its
// connector, so it still matches when a cable goes into another port. Saved in
// Quickshell.statePath("displays.json"); `qs ipc call display forget` drops the current set's one.
Singleton {
    id: root

    property var profiles: ({}) // key -> {displays: [ids], rules: [rules with ids for output/mirror], saved}
    property string key: "" // the connected set, as `profiles` keys it
    property var names: ({}) // id -> connector, for the connected set
    property string handledKey: "" // the set last looked up, so its own monitor events don't apply it again
    property bool force: false // after a config reload: put the profile back although the set is the same
    property string error: ""

    readonly property var current: profiles[key] ?? null

    // connector -> id. Two displays with the same description (no serial) get their connector added.
    function ids(list) {
        const base = m => m.description || [m.make, m.model, m.serial].filter(s => s).join(" ") || m.name;
        const seen = {};
        for (const m of list)
            seen[base(m)] = (seen[base(m)] ?? 0) + 1;
        const out = {};
        for (const m of list)
            out[m.name] = seen[base(m)] > 1 ? `${base(m)} (${m.name})` : base(m);
        return out;
    }

    function keyOf(idByName) {
        return Object.values(idByName).sort().join(" + ");
    }

    function lua(spec) {
        const fields = Object.entries(spec).map(([k, v]) => `${k} = ${typeof v === "string" ? JSON.stringify(v) : v}`);
        return `hl.monitor({ ${fields.join(", ")} })`;
    }

    function luaAll(specs) {
        return specs.map(lua).join("; ");
    }

    // Swaps output/mirror names through `map` (connector -> id to save, id -> connector to apply).
    function renamed(specs, map) {
        return specs.map(s => {
            const r = Object.assign({}, s, {
                output: map[s.output] ?? s.output
            });
            if (r.mirror)
                r.mirror = map[r.mirror] ?? r.mirror;
            return r;
        });
    }

    // Remembers the rules the menu just applied for the set `idByName` describes.
    function save(idByName, specs) {
        const k = keyOf(idByName);
        const all = Object.assign({}, profiles);
        all[k] = {
            displays: Object.values(idByName).sort(),
            rules: renamed(specs, idByName),
            saved: new Date().toISOString()
        };
        profiles = all;
        handledKey = k;
        write();
    }

    function forget(k) {
        if (!(k in profiles))
            return false;
        const all = Object.assign({}, profiles);
        delete all[k];
        profiles = all;
        write();
        return true;
    }

    function write() {
        store.setText(JSON.stringify(profiles, null, 2) + "\n");
    }

    function check() {
        settle.restart();
    }

    // The set hyprctl reports now; applies its profile when the set changed (or after a reload).
    function seen(list) {
        const idByName = ids(list);
        const byId = {};
        for (const [n, id] of Object.entries(idByName))
            byId[id] = n;
        names = byId;
        key = keyOf(idByName);
        if (key === handledKey && !force)
            return;
        force = false;
        handledKey = key;
        const p = profiles[key];
        if (!p || list.length === 0)
            return;
        applier.command = ["hyprctl", "eval", luaAll(renamed(p.rules, byId))];
        applier.running = true;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "configreloaded") {
                root.force = true;
                root.check();
            } else if (n.startsWith("monitoradded") || n.startsWith("monitorremoved")) {
                root.check();
            }
        }
    }

    // monitor events come in bursts (one per output, v1 and v2); look once they've settled
    Timer {
        id: settle
        interval: 400
        running: true // once at startup
        onTriggered: {
            if (reader.running)
                restart();
            else
                reader.running = true;
        }
    }

    Process {
        id: reader
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.seen(JSON.parse(text));
                } catch (e) {
                    console.warn("Displays: couldn't read the monitors:", e);
                }
            }
        }
    }

    Process {
        id: applier
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.error = out === "ok" ? "" : out || "hyprctl eval failed";
                if (root.error)
                    console.warn("Displays: profile for", root.key, "failed:", root.error);
            }
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("displays.json")
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                root.profiles = JSON.parse(text()) ?? {};
            } catch (e) {}
        }
    }
}
