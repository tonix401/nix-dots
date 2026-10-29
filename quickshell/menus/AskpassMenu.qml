import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components

// Password prompt (see Askpass.qml), in the same box as the menus. Keys: Enter confirms, Esc cancels;
// a click outside the box cancels too.
PanelWindow {
    id: root

    // Closing the menu any other way (another menu opened, a click outside) cancels the request.
    Component.onDestruction: Askpass.answer("")

    function submit() {
        // Answers before closing: closing destroys the menu.
        Askpass.answer(field.text);
        Menus.close();
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        onClicked: Menus.close()
    }

    Rectangle {
        anchors.centerIn: parent
        scale: Theme.popoutScale // laid out at full size, smaller on small screens
        width: 440
        height: content.implicitHeight + 2 * (2 + 16)
        radius: 12
        color: Theme.surface
        border.width: 2
        border.color: Theme.primary

        MouseArea {
            anchors.fill: parent // swallow clicks so they don't close the menu
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 2 + 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: Theme.g(0xf033e) // lock
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    renderType: Theme.renderType
                }
                Text {
                    Layout.fillWidth: true
                    text: Askpass.prompt
                    wrapMode: Text.Wrap
                    color: Theme.on_surface
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    renderType: Theme.renderType
                }
            }

            Field {
                id: field

                implicitHeight: 36
                placeholder: "Password"
                onAccepted: root.submit()
                onCancelled: Menus.close()
                Component.onCompleted: {
                    input.echoMode = TextInput.Password;
                    input.forceActiveFocus();
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextButton {
                    text: "Cancel"
                    onClicked: Menus.close()
                }
                TextButton {
                    text: "Confirm"
                    onClicked: root.submit()
                }
            }
        }
    }
}
