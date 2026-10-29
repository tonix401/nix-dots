pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Password requests from scripts/askpass.sh (SUDO_ASKPASS), which hands one over with
// `qs ipc call askpass ask` and waits on a FIFO for one line: the password, or an empty line when the
// prompt was cancelled. The menu itself is menus/AskpassMenu.qml.
Singleton {
    id: root

    property string reply: "" // FIFO the script reads; "" = no request pending
    property string prompt: ""

    readonly property bool pending: reply !== ""

    function request(fifo, text) {
        answer(""); // a request still open is superseded
        root.prompt = text.replace(/:?\s*$/, ""); // sudo's "[sudo] password for tom: "
        root.reply = fifo;
        Menus.open("askpass");
    }

    // "" cancels. Only the first answer counts.
    function answer(secret) {
        if (!pending)
            return;
        // The password is written to the process's stdin, not put in its arguments, which any process
        // of the user can read. The timeout only matters if the script is gone.
        writer.secret = secret;
        writer.command = ["timeout", "5", "sh", "-c", '[ -p "$1" ] && cat > "$1"', "sh", reply];
        writer.running = true;
        reply = "";
    }

    Process {
        id: writer

        property string secret: ""

        stdinEnabled: true
        onStarted: {
            write(secret + "\n");
            secret = "";
            stdinEnabled = false; // closes stdin, so cat ends
        }
    }
}
