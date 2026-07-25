// Desktop widget for workspace 1 — greeting, clock, weather, system stats.
// Runs as its own quickshell config:  qs -c deskwidget  (systemd: deskwidget.service)
// Sits on the wlr-layer-shell Bottom layer (above wallpaper, below windows)
// and is fully click-through.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shellRoot

    // ---- palette ----
    // Raw colors come from the wallust-generated qml_color.json; each panel
    // picks the light or dark variant based on the wallpaper brightness
    // behind it (see monLuma below). Set useThemeColors: false to keep the
    // fallback palette.
    property bool useThemeColors: true
    property color themeFgLight: "#eceaf4"
    property color themeFgDark: "#16141c"
    property color themeDimLight: "#a9a7c4"
    property color themeDimDark: "#3a3547"
    property color themeAccent: "#ff5e63"
    property color themeMem: "#7aa2f7"
    property color themeDisk: "#9ece6a"
    readonly property string fontFam: "JetBrainsMono Nerd Font"

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/quickshell/qml_color.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            shellRoot.applyTheme();
            lumaProc.running = true;   // wallpaper changed too — resample brightness
        }
    }

    function applyTheme() {
        if (!useThemeColors)
            return;
        try {
            const t = JSON.parse(themeFile.text());
            // wallust template sometimes emits "##RRGGBB"
            const c = s => (typeof s === "string" && s !== "") ? s.replace(/^#+/, "#") : undefined;
            if (c(t.surfaceText))      themeFgLight = c(t.surfaceText);
            if (c(t.windowBackground)) themeFgDark = c(t.windowBackground);
            if (c(t.secondaryText))    themeDimLight = c(t.secondaryText);
            if (c(t.layerBackground3)) themeDimDark = c(t.layerBackground3);
            if (c(t.accentPrimary))    themeAccent = c(t.accentPrimary);
            if (c(t.primaryText))      themeMem = c(t.primaryText);
            if (c(t.layerBackground2)) themeDisk = c(t.layerBackground2);
        } catch (e) {
            console.log("deskwidget: failed to parse qml_color.json:", e);
        }
    }

    // ---- wallpaper brightness per monitor ----
    // Average luminance of the region the widget occupies (left ~35% of the
    // screen, vertically centered). Text flips dark/light per monitor.
    property var monLuma: ({})
    Process {
        id: lumaProc
        command: ["sh", "-c",
            "awww query 2>/dev/null | while IFS= read -r line; do " +
            "mon=\"${line#: }\"; mon=\"${mon%%:*}\"; img=\"${line##*image: }\"; " +
            "[ -f \"$img\" ] || continue; " +
            "l=$(magick \"$img\" -gravity West -crop '35x60%+0+0' -resize 1x1 -colorspace gray -format '%[fx:luma]' info: 2>/dev/null); " +
            "[ -n \"$l\" ] && printf '%s %s\\n' \"$mon\" \"$l\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                text.trim().split("\n").forEach(line => {
                    const p = line.trim().split(/\s+/);
                    if (p.length === 2 && !isNaN(parseFloat(p[1])))
                        m[p[0]] = parseFloat(p[1]);
                });
                if (Object.keys(m).length > 0)
                    shellRoot.monLuma = m;
            }
        }
    }

    // Quickshell doesn't refresh monitor state on every workspace event, so
    // activeWorkspace (and the visibility binding below) can go stale without this.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "workspace":
            case "workspacev2":
            case "focusedmon":
            case "focusedmonv2":
            case "moveworkspace":
            case "moveworkspacev2":
            case "createworkspace":
            case "createworkspacev2":
            case "destroyworkspace":
            case "destroyworkspacev2":
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
                break;
            }
        }
    }

    // ---- clock ----
    property date now: new Date()
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: shellRoot.now = new Date()
    }
    readonly property int hourNow: now.getHours()
    readonly property string daypart:
        hourNow < 5 ? "NIGHT" :
        hourNow < 12 ? "MORNING" :
        hourNow < 17 ? "AFTERNOON" :
        hourNow < 22 ? "EVENING" : "NIGHT"

    // ---- weather (wttr.in, refreshed every 30 min) ----
    property string weatherLine: ""
    Process {
        id: weatherProc
        command: ["sh", "-c", "curl -sf --max-time 10 'https://wttr.in/?format=%t|%C|%l'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|");
                if (p.length >= 3)
                    shellRoot.weatherLine = "Currently " + p[0].replace("+", "")
                        + " · " + p[1].toLowerCase() + "\nin " + p[2];
            }
        }
    }
    Timer {
        interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    // ---- system stats (every 3 s) ----
    property real cpuUsage: 0
    property var cpuPrev: null
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + f[4];
                const total = f.reduce((a, b) => a + b, 0);
                if (shellRoot.cpuPrev) {
                    const dt = total - shellRoot.cpuPrev.total;
                    if (dt > 0)
                        shellRoot.cpuUsage = Math.min(1, Math.max(0, 1 - (idle - shellRoot.cpuPrev.idle) / dt));
                }
                shellRoot.cpuPrev = ({ total: total, idle: idle });
            }
        }
    }
    property real memUsage: 0
    Process {
        id: memProc
        command: ["sh", "-c", "free | awk 'NR==2 {print $3, $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length >= 2 && p[1] > 0) shellRoot.memUsage = p[0] / p[1];
            }
        }
    }
    property real diskUsage: 0
    Process {
        id: diskProc
        command: ["sh", "-c", "df --output=pcent / | tail -1 | tr -dc '0-9'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v)) shellRoot.diskUsage = v / 100;
            }
        }
    }
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
            diskProc.running = true;
        }
    }

    // ---- circular stat meter ----
    component StatMeter: Item {
        id: meter
        property string label
        property real value
        property color ringColor
        property color trackColor
        property color fgColor
        property color dimColor
        property color haloColor
        implicitWidth: 60
        implicitHeight: ring.height + labelText.height + 6

        onValueChanged: ring.requestPaint()
        onRingColorChanged: ring.requestPaint()
        onTrackColorChanged: ring.requestPaint()

        Canvas {
            id: ring
            width: 54; height: 54
            anchors.horizontalCenter: parent.horizontalCenter
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2, r = c - 4;
                ctx.lineWidth = 5;
                ctx.lineCap = "round";
                ctx.strokeStyle = meter.trackColor;
                ctx.beginPath();
                ctx.arc(c, c, r, 0, 2 * Math.PI);
                ctx.stroke();
                ctx.strokeStyle = meter.ringColor;
                ctx.beginPath();
                ctx.arc(c, c, r, -Math.PI / 2,
                        -Math.PI / 2 + 2 * Math.PI * Math.max(0.01, meter.value));
                ctx.stroke();
            }
            Text {
                anchors.centerIn: parent
                text: Math.round(meter.value * 100) + "%"
                font { family: shellRoot.fontFam; pixelSize: 12; weight: Font.Bold }
                color: meter.fgColor
                style: Text.Raised
                styleColor: meter.haloColor
            }
        }
        Text {
            id: labelText
            anchors { top: ring.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
            text: meter.label
            font { family: shellRoot.fontFam; pixelSize: 11 }
            color: meter.dimColor
            style: Text.Raised
            styleColor: meter.haloColor
        }
    }

    // ---- one widget surface per monitor, shown only on workspace 1 ----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            readonly property var hyprMon: Hyprland.monitorFor(panel.screen)
            visible: panel.hyprMon && panel.hyprMon.activeWorkspace
                     ? panel.hyprMon.activeWorkspace.id === 1 : false

            // Contrast: flip the palette when the wallpaper behind us is bright.
            readonly property real bgLuma:
                shellRoot.monLuma[panel.screen.name] !== undefined
                ? shellRoot.monLuma[panel.screen.name] : 0.15
            readonly property bool darkBg: bgLuma < 0.55
            readonly property color colFg: darkBg ? shellRoot.themeFgLight : shellRoot.themeFgDark
            readonly property color colDim: darkBg ? shellRoot.themeDimLight : shellRoot.themeDimDark
            readonly property color colAccent: darkBg ? shellRoot.themeAccent : Qt.darker(shellRoot.themeAccent, 1.55)
            readonly property color colMem: darkBg ? shellRoot.themeMem : Qt.darker(shellRoot.themeMem, 1.55)
            readonly property color colDisk: darkBg ? shellRoot.themeDisk : Qt.darker(shellRoot.themeDisk, 1.35)
            readonly property color colPillText: darkBg ? shellRoot.themeFgDark : shellRoot.themeFgLight
            readonly property color colTrack: darkBg ? "#2effffff" : "#2e000000"
            readonly property color colHalo: darkBg ? "#88000000" : "#88ffffff"

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:deskwidget"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}   // empty input region: clicks pass through everywhere

            anchors { left: true; top: true; bottom: true }
            implicitWidth: 470

            ColumnLayout {
                id: content
                anchors { left: parent.left; leftMargin: 52; verticalCenter: parent.verticalCenter }
                spacing: 16

                Text {
                    text: "It's " + Qt.formatDateTime(shellRoot.now, "dddd")
                    font { family: shellRoot.fontFam; pixelSize: 15; italic: true }
                    color: panel.colAccent
                    style: Text.Raised
                    styleColor: panel.colHalo
                }

                Text {
                    text: "HOPE YOUR " + shellRoot.daypart + "\nIS GOING WELL,\nHANYU!"
                    font { family: shellRoot.fontFam; pixelSize: 30; weight: Font.ExtraBold; letterSpacing: 1.5 }
                    lineHeight: 1.15
                    color: panel.colFg
                    style: Text.Raised
                    styleColor: panel.colHalo
                }

                Text {
                    visible: shellRoot.weatherLine !== ""
                    text: shellRoot.weatherLine
                    font { family: shellRoot.fontFam; pixelSize: 14 }
                    lineHeight: 1.25
                    color: panel.colDim
                    style: Text.Raised
                    styleColor: panel.colHalo
                }

                Rectangle {
                    radius: 7
                    color: panel.colAccent
                    implicitWidth: timeText.implicitWidth + 26
                    implicitHeight: timeText.implicitHeight + 12
                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(shellRoot.now, "hh:mm AP")
                        font { family: shellRoot.fontFam; pixelSize: 15; weight: Font.Bold }
                        color: panel.colPillText
                    }
                }

                RowLayout {
                    spacing: 24
                    StatMeter {
                        label: "CPU"; value: shellRoot.cpuUsage; ringColor: panel.colAccent
                        trackColor: panel.colTrack; fgColor: panel.colFg
                        dimColor: panel.colDim; haloColor: panel.colHalo
                    }
                    StatMeter {
                        label: "MEM"; value: shellRoot.memUsage; ringColor: panel.colMem
                        trackColor: panel.colTrack; fgColor: panel.colFg
                        dimColor: panel.colDim; haloColor: panel.colHalo
                    }
                    StatMeter {
                        label: "DISK"; value: shellRoot.diskUsage; ringColor: panel.colDisk
                        trackColor: panel.colTrack; fgColor: panel.colFg
                        dimColor: panel.colDim; haloColor: panel.colHalo
                    }
                }
            }
        }
    }
}
