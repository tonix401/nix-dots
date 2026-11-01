import QtQuick
import Quickshell.Io
import qs
import qs.components

// Hidden on machines without a battery.
Module {
    id: root

    property int capacity: -1
    property string status: ""
    property real hoursLeft: -1
    property int acOnline: -1 // -1 = no adapter file
    property real smoothedPower: 0
    property string smoothedStatus: ""
    property real lastSample: 0

    // The adapter's online flag flips the moment the plug moves; the battery's STATUS can trail it.
    readonly property bool charging: acOnline >= 0 ? acOnline === 1 : status === "Charging" || status === "Full" || status === "Not charging"

    visible: capacity >= 0
    text: icon() + " " + capacity + "%"
    tooltip: {
        if (!(hoursLeft > 0))
            return status;
        const mins = Math.round(hoursLeft * 60);
        return status + " · " + Math.floor(mins / 60) + "h " + String(mins % 60).padStart(2, "0") + "m " + (status === "Charging" ? "to full" : "left");
    }
    onClicked: Util.run("kitty -e btop")
    onRightClicked: Util.run("kitty -e btop")

    function icon() {
        const step = Math.max(0, Math.min(9, Math.floor(capacity / 10)));
        // nf-md-battery_charging_{10..100} and nf-md-battery_{10..90}, battery
        const charge = [0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d, 0xf0089, 0xf089e, 0xf008a, 0xf008b, 0xf0085];
        const drain = [0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079];
        return Theme.g(charging ? charge[step] : capacity >= 95 ? 0xf0079 : drain[step]);
    }

    FileView {
        id: uevent
        path: "/sys/class/power_supply/BAT0/uevent"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: adapter
        path: "/sys/class/power_supply/ADP1/online"
        blockLoading: true
        printErrors: false
    }

    function refresh() {
        adapter.reload();
        const ac = adapter.text().trim();
        root.acOnline = ac === "" ? -1 : Number(ac);
        uevent.reload();
        const text = uevent.text();
        const get = key => {
            const m = text.match(new RegExp("^POWER_SUPPLY_" + key + "=(.*)$", "m"));
            return m ? m[1] : null;
        };
        const cap = get("CAPACITY");
        root.capacity = cap === null ? -1 : Number(cap);
        root.status = get("STATUS") ?? "";
        const raw = Number(get("POWER_NOW")), now = Number(get("ENERGY_NOW")), full = Number(get("ENERGY_FULL"));
        // EMA of the power draw (~1 min time constant) so the estimate doesn't jump with every load
        // spike. Weighted by elapsed time, since events make the samples irregular. Reset when
        // charging/discharging flips, since the old average no longer applies.
        const t = Date.now() / 1000, dt = t - root.lastSample;
        root.lastSample = t;
        if (!(raw > 0) || root.status !== root.smoothedStatus)
            root.smoothedPower = raw;
        else
            root.smoothedPower += (1 - Math.exp(-dt / 60)) * (raw - root.smoothedPower);
        root.smoothedStatus = root.status;
        const power = root.smoothedPower;
        if (power > 0 && root.status === "Discharging")
            root.hoursLeft = now / power;
        else if (power > 0 && root.status === "Charging")
            root.hoursLeft = (full - now) / power;
        else
            root.hoursLeft = -1;
    }

    // Plugging in or out sends a power_supply uevent; read right away instead of waiting for the poll.
    // One plug fires several events (adapter, battery, USB-C), so they're coalesced.
    Process {
        id: watch
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=power_supply"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("KERNEL["))
                    coalesce.restart();
            }
        }
        onExited: retry.start()
    }

    Timer {
        id: coalesce
        interval: 100
        onTriggered: {
            root.refresh();
            settle.restart();
        }
    }

    // The battery's STATUS and POWER_NOW lag the adapter by a moment and send no event of their own.
    Timer {
        id: settle
        interval: 2000
        onTriggered: root.refresh()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: watch.running = true
    }

    // Capacity changes send no uevent on this laptop (checked 2026-11-01: 38 -> 41% charging, no
    // events), so the percentage and time estimate still need a slow poll.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
