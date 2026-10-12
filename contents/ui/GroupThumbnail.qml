/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem
import org.kde.pipewire as PipeWire

Item {
    id: thumbnail
    width: dialog.thumbnailWidth
    height: dialog.thumbnailHeight + titleLabel.height + Kirigami.Units.smallSpacing

    // The GroupDialog this thumbnail belongs to (size, drag state, hiding)
    required property var dialog
    // Index of this thumbnail's window in the tasks model
    required property var modelIndex

    property string windowTitle
    property var windowIcon
    property bool isActive: false
    property bool isMinimized: false
    property var winIdList: []
    property var winId: winIdList.length > 0 ? winIdList[0] : 0
    property string winKey: winIdList.length > 0 ? String(winIdList[0]) : ""

    // The uuid the stream is requested for; reset by the retry timer below
    property string streamUuid: winKey
    property int streamRetries: 0

    // Thumbnail container
    Rectangle {
        id: thumbnailContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: dialog.thumbnailWidth
        height: dialog.thumbnailHeight
        color: thumbnail.isActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.backgroundColor
        border.color: mouseArea.containsMouse ? Kirigami.Theme.highlightColor : "transparent"
        border.width: 2
        radius: Kirigami.Units.smallSpacing
        clip: true

        // Wayland: PipeWire thumbnail
        PipeWire.PipeWireSourceItem {
            id: pipeWireThumbnail
            anchors.fill: parent
            anchors.margins: 4
            nodeId: screencastRequest.nodeId
            visible: KWindowSystem.isPlatformWayland && nodeId > 0
        }

        TaskManager.ScreencastingRequest {
            id: screencastRequest
            uuid: thumbnail.streamUuid
        }

        // A window that just opened can be unknown to KWin's screencasting for a
        // moment, which fails the request for good. Re-request a few times, then
        // give up (some windows, e.g. minimized ones, can't be captured at all).
        Timer {
            interval: 250
            repeat: true
            running: KWindowSystem.isPlatformWayland && thumbnail.winKey !== ""
                     && screencastRequest.nodeId === 0 && thumbnail.streamRetries < 12
            onTriggered: {
                thumbnail.streamRetries++;
                thumbnail.streamUuid = "";
                thumbnail.streamUuid = thumbnail.winKey;
            }
        }

        // X11: PlasmaCore.WindowThumbnail
        PlasmaCore.WindowThumbnail {
            id: x11Thumbnail
            anchors.fill: parent
            anchors.margins: 4
            winId: !KWindowSystem.isPlatformWayland ? thumbnail.winId : 0
            visible: !KWindowSystem.isPlatformWayland && thumbnail.winId > 0
        }

        // Fallback icon when thumbnail not available
        Kirigami.Icon {
            id: fallbackIcon
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.huge
            height: width
            source: thumbnail.windowIcon
            visible: {
                if (KWindowSystem.isPlatformWayland) {
                    return screencastRequest.nodeId === 0;
                }
                return thumbnail.winId === 0;
            }
            opacity: thumbnail.isMinimized ? 0.6 : 1.0
        }

        // Small icon overlay at bottom
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            width: Kirigami.Units.iconSizes.medium
            height: width
            source: thumbnail.windowIcon
            visible: !fallbackIcon.visible
        }

        // Close button
        PlasmaComponents3.ToolButton {
            id: closeButton
            z: 1  // Stay above mouseArea
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 2
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            icon.name: "window-close"
            visible: mouseArea.containsMouse || closeButton.hovered
            opacity: closeButton.hovered ? 1.0 : 0.8

            background: Rectangle {
                radius: width / 2
                color: Kirigami.Theme.backgroundColor
                opacity: 0.8
            }

            onClicked: {
                dialog.tasksModel.requestClose(thumbnail.modelIndex);
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton) {
                    dialog.tasksModel.requestClose(thumbnail.modelIndex);
                } else {
                    dialog.tasksModel.requestActivate(thumbnail.modelIndex);
                    dialog.visible = false;
                }
            }
        }

        // Drop area for files
        DropArea {
            id: dropArea
            anchors.fill: parent
            z: 10  // Above container drop area

            property bool dropHovered: false

            onEntered: function(drag) {
                if (drag.hasUrls) {
                    dropHovered = true;
                    dialog.anyDropHovered = true;
                    drag.accepted = true;
                    // Start timer to activate window on hover
                    dropActivationTimer.start();
                }
            }

            onExited: {
                dropHovered = false;
                dialog.anyDropHovered = false;
                dropActivationTimer.stop();
            }

            onDropped: function(drop) {
                dropHovered = false;
                dialog.anyDropHovered = false;
                dropActivationTimer.stop();
                if (drop.hasUrls) {
                    dialog.tasksModel.requestOpenUrls(thumbnail.modelIndex, drop.urls);
                    dialog.visible = false;
                    drop.accepted = true;
                }
            }
        }

        // Timer to activate window when hovering with drag
        Timer {
            id: dropActivationTimer
            interval: 400
            onTriggered: {
                // Activate window so user can see it
                dialog.tasksModel.requestActivate(thumbnail.modelIndex);
            }
        }

        // Drop hover highlight
        Rectangle {
            anchors.fill: parent
            color: Kirigami.Theme.highlightColor
            opacity: dropArea.dropHovered ? 0.3 : 0
            radius: Kirigami.Units.smallSpacing

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }

    // Window title
    PlasmaComponents3.Label {
        id: titleLabel
        anchors.top: thumbnailContainer.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        horizontalAlignment: Text.AlignHCenter
        text: thumbnail.windowTitle
        elide: Text.ElideRight
        maximumLineCount: 1
        opacity: thumbnail.isMinimized ? 0.6 : 1.0
        font.bold: thumbnail.isActive
    }
}

