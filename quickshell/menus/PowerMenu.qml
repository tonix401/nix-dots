import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components

// A 2x1 card: the middle square of the wallpaper on the left, the options on the right, with the
// same inset on every side of the list.
Menu {
    id: menu

    readonly property int inset: 6 // around the list
    // Whether logind can hibernate here: it needs a swap big enough and a resume device, which only
    // the desktop has (nixos/hosts/box); elsewhere the option is left out.
    property bool canHibernate: false
    // The picture's side, inside the box's 2px border: the options fill its height.
    readonly property int side: items.length * rowHeight + (items.length - 1) * listSpacing + 2 * inset

    boxWidth: 2 * side + 4
    boxHeight: side + 4
    fontPt: 11
    rowPadV: 8
    rowPadH: 12
    showInput: false
    matching: "fuzzy"
    listArea: Qt.rect(2 + side + inset, 2 + inset, side - 2 * inset, side - 2 * inset)
    items: [
        {
            text: Theme.g(0xf0425) + "   Shutdown",
            cmd: "systemctl poweroff"
        },
        ...(canHibernate ? [{
                    text: Theme.g(0xf0717) + "   Hibernate",
                    cmd: "systemctl hibernate"
                }] : []),
        {
            text: Theme.g(0xf0709) + "   Reboot",
            cmd: "systemctl reboot"
        },
        {
            text: Theme.g(0xf035b) + "   Reboot into UEFI",
            cmd: "systemctl reboot --firmware-setup"
        },
        {
            text: Theme.g(0xf033e) + "   Lock",
            cmd: "hyprlock"
        },
        {
            text: Theme.g(0xf0343) + "   Log out",
            cmd: "hyprshutdown -vt 2"
        },
        {
            text: Theme.g(0xf16a1) + "   Kill open Apps",
            cmd: "hyprctl -j clients | jq -r '.[].pid' | xargs -r kill"
        }
    ]
    onAccepted: item => Util.run(item.cmd)

    backdrop: ClippingRectangle {
        radius: 10
        color: "transparent"

        Image {
            width: menu.side
            height: menu.side
            source: "file://" + Quickshell.env("HOME") + "/.cache/box-dots/current/wallpaper.png"
            fillMode: Image.PreserveAspectCrop // centred, so the middle square
            cache: false
            smooth: true
            mipmap: true
        }

        // The divider: stops short of the border at both ends, with rounded ends.
        Rectangle {
            x: menu.side - width / 2
            y: 5
            width: 2
            height: menu.side - 2 * y
            radius: width / 2
            color: Theme.primary
        }
    }

    rowContent: MenuText {}

    Process {
        running: true
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: menu.canHibernate = text.includes('"yes"')
        }
    }
}
