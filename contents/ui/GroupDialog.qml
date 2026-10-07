/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem
import org.kde.pipewire as PipeWire

PlasmaCore.Dialog {
    id: groupDialog

    property var tasksModel
    // Index of the group's row in tasksModel. The DelegateModel below keeps it
    // as a persistent index, so it follows the row if tasks above are added/removed.
    property var groupModelIndex

    // The group row stays but loses its children once a single window is left
    // (see TaskGroupingProxyModel), so nothing remains to list: dismiss the dialog.
    function closeIfGone() {
        if (visible && !windowsModel.rootIndex.valid) {
            visible = false;
        }
    }

    // Thumbnail dimensions
    readonly property int thumbnailWidth: Kirigami.Units.gridUnit * 12
    readonly property int thumbnailHeight: Kirigami.Units.gridUnit * 8

    visible: true
    type: PlasmaCore.Dialog.PopupMenu
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    location: Plasmoid.location

    // Track if any window has drag hover active
    property bool anyDropHovered: false

    mainItem: Item {
        id: mainContainer

        implicitWidth: thumbnailGrid.implicitWidth
        implicitHeight: thumbnailGrid.implicitHeight
        width: implicitWidth
        height: implicitHeight

        // If the group row itself disappears, the DelegateModel would fall back
        // to listing every top-level task
        Connections {
            target: groupDialog.tasksModel
            function onRowsRemoved() { groupDialog.closeIfGone(); }
            function onModelReset() { groupDialog.closeIfGone(); }
            function onLayoutChanged() { groupDialog.closeIfGone(); }
        }

        // Container-level drop area to catch drops that miss individual windows
        DropArea {
            id: containerDropArea
            anchors.fill: parent
            z: -1  // Below individual window drop areas

            onEntered: function(drag) {
                // Accept to prevent drop from going through to Task
                if (drag.hasUrls) {
                    groupDialog.anyDropHovered = true;
                    drag.accepted = true;
                }
            }

            onExited: {
                groupDialog.anyDropHovered = false;
            }

            onDropped: function(drop) {
                groupDialog.anyDropHovered = false;
                // Don't do anything - drops should go to individual windows
                drop.accepted = true;
            }
        }

        // Close dialog when mouse leaves
        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (!hovered) {
                    hideTimer.start();
                }
            }
        }

        Timer {
            id: hideTimer
            interval: 300
            onTriggered: {
                // Don't hide if mouse is hovering or if drag is in progress
                if (!hoverHandler.hovered && !groupDialog.anyDropHovered) {
                    groupDialog.visible = false;
                }
            }
        }

        Grid {
            id: thumbnailGrid
            columns: Plasmoid.configuration.groupPreviewMaxColumns
            spacing: Kirigami.Units.smallSpacing

        DelegateModel {
            id: windowsModel
            model: groupDialog.tasksModel
            rootIndex: groupDialog.groupModelIndex

            onCountChanged: {
                if (groupDialog.visible && count < 2) {
                    groupDialog.visible = false;
                }
            }

            delegate: Item {
                id: windowDelegate
                width: groupDialog.thumbnailWidth
                height: groupDialog.thumbnailHeight + titleLabel.height + Kirigami.Units.smallSpacing

                required property var model
                required property int index

                property string windowTitle: model.display || ""
                property var windowIcon: model.decoration
                property bool isActive: model.IsActive || false
                property bool isMinimized: model.IsMinimized || false
                property var winIdList: model.WinIdList || []
                property var winId: winIdList.length > 0 ? winIdList[0] : 0
                property string winKey: winIdList.length > 0 ? String(winIdList[0]) : ""

                // Thumbnail container
                Rectangle {
                    id: thumbnailContainer
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: groupDialog.thumbnailWidth
                    height: groupDialog.thumbnailHeight
                    color: windowDelegate.isActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.backgroundColor
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
                        uuid: windowDelegate.winKey
                    }

                    // X11: PlasmaCore.WindowThumbnail
                    PlasmaCore.WindowThumbnail {
                        id: x11Thumbnail
                        anchors.fill: parent
                        anchors.margins: 4
                        winId: !KWindowSystem.isPlatformWayland ? windowDelegate.winId : 0
                        visible: !KWindowSystem.isPlatformWayland && windowDelegate.winId > 0
                    }

                    // Fallback icon when thumbnail not available
                    Kirigami.Icon {
                        id: fallbackIcon
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.huge
                        height: width
                        source: windowDelegate.windowIcon
                        visible: {
                            if (KWindowSystem.isPlatformWayland) {
                                return screencastRequest.nodeId === 0;
                            }
                            return windowDelegate.winId === 0;
                        }
                        opacity: windowDelegate.isMinimized ? 0.6 : 1.0
                    }

                    // Small icon overlay at bottom
                    Kirigami.Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Kirigami.Units.smallSpacing
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        source: windowDelegate.windowIcon
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
                            groupDialog.tasksModel.requestClose(windowsModel.modelIndex(windowDelegate.index));
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: function(mouse) {
                            if (mouse.button === Qt.MiddleButton) {
                                groupDialog.tasksModel.requestClose(windowsModel.modelIndex(windowDelegate.index));
                            } else {
                                groupDialog.tasksModel.requestActivate(windowsModel.modelIndex(windowDelegate.index));
                                groupDialog.visible = false;
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
                                groupDialog.anyDropHovered = true;
                                drag.accepted = true;
                                // Start timer to activate window on hover
                                dropActivationTimer.start();
                            }
                        }

                        onExited: {
                            dropHovered = false;
                            groupDialog.anyDropHovered = false;
                            dropActivationTimer.stop();
                        }

                        onDropped: function(drop) {
                            dropHovered = false;
                            groupDialog.anyDropHovered = false;
                            dropActivationTimer.stop();
                            if (drop.hasUrls) {
                                groupDialog.tasksModel.requestOpenUrls(windowsModel.modelIndex(windowDelegate.index), drop.urls);
                                groupDialog.visible = false;
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
                            groupDialog.tasksModel.requestActivate(windowsModel.modelIndex(windowDelegate.index));
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
                    text: windowDelegate.windowTitle
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    opacity: windowDelegate.isMinimized ? 0.6 : 1.0
                    font.bold: windowDelegate.isActive
                }
            }
        }

        Repeater {
            model: windowsModel
        }
        }
    }

    onVisibleChanged: {
        if (visible) {
            groupDialog.requestActivate();
        } else {
            destroy();
        }
    }
}
