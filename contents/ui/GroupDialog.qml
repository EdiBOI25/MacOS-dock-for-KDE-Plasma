/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import org.kde.taskmanager as TaskManager

PlasmaCore.Dialog {
    id: groupDialog

    property var tasksModel
    // Index of the group's row in tasksModel. The DelegateModel below keeps it
    // as a persistent index, so it follows the row if tasks above are added/removed.
    property var groupModelIndex

    // True while showing a single window: the group row itself, which has no children
    property bool showLast: false
    // Bumped on model changes to re-read that window's index and data
    property int lastWindowRev: 0

    function lastWindowIndex() {
        var _ = lastWindowRev;
        return windowsModel.rootIndex;
    }

    function lastWindowData(role) {
        return tasksModel.data(lastWindowIndex(), role);
    }

    // A group that drops below two windows keeps its row but loses its
    // children (see TaskGroupingProxyModel); the row is then the only window.
    // A single-window task is shown the same way. Show that window unless the
    // user chose to hide single-window previews, or the row is no longer a
    // window; the dialog is dismissed in those cases and when the row is gone.
    function updateMode() {
        if (!visible) {
            return;
        }
        if (!windowsModel.rootIndex.valid) {
            visible = false;
        } else if (windowsModel.count >= 2) {
            showLast = false;
        } else {
            showLast = !Plasmoid.configuration.hidePreviewForSingleWindow
                && tasksModel.data(windowsModel.rootIndex, TaskManager.AbstractTasksModel.IsWindow);
            if (!showLast) {
                visible = false;
            }
        }
    }

    function modelChanged() {
        if (showLast) {
            lastWindowRev++;
        }
        updateMode();
    }

    Component.onCompleted: updateMode()

    // Thumbnail dimensions
    readonly property int thumbnailWidth: Kirigami.Units.gridUnit * 12
    readonly property int thumbnailHeight: Kirigami.Units.gridUnit * 8

    visible: true
    type: PlasmaCore.Dialog.PopupMenu
    // Never take focus: the preview is hover-driven and must not steal focus
    // from the window the user is working in
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    location: Plasmoid.location

    // Track if any window has drag hover active
    property bool anyDropHovered: false

    // Whether the pointer is on the dock icon this preview belongs to. Without
    // focus the dialog can't dismiss itself on deactivation, so it goes away
    // once the pointer is on neither the icon nor the dialog.
    property bool anchorHovered: true
    onAnchorHoveredChanged: {
        if (!anchorHovered) {
            hideTimer.restart();
        }
    }

    mainItem: Item {
        id: mainContainer

        implicitWidth: thumbnailGrid.implicitWidth
        implicitHeight: thumbnailGrid.implicitHeight
        width: implicitWidth
        height: implicitHeight

        // Re-evaluate what to show when the group row changes or disappears (an
        // invalid root would make the DelegateModel list every top-level task)
        Connections {
            target: groupDialog.tasksModel
            function onRowsInserted() { groupDialog.modelChanged(); }
            function onRowsRemoved() { groupDialog.modelChanged(); }
            function onRowsMoved() { groupDialog.modelChanged(); }
            function onLayoutChanged() { groupDialog.modelChanged(); }
            function onModelReset() { groupDialog.modelChanged(); }
            function onDataChanged() { groupDialog.modelChanged(); }
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
                    hideTimer.restart();
                }
            }
        }

        Timer {
            id: hideTimer
            interval: 300
            onTriggered: {
                // Don't hide if mouse is hovering or if drag is in progress
                if (!hoverHandler.hovered && !groupDialog.anchorHovered && !groupDialog.anyDropHovered) {
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

            onCountChanged: groupDialog.updateMode()

            delegate: GroupThumbnail {
                required property var model
                required property int index

                dialog: groupDialog
                modelIndex: windowsModel.modelIndex(index)
                windowTitle: model.display || ""
                windowIcon: model.decoration
                isActive: model.IsActive || false
                isMinimized: model.IsMinimized || false
                winIdList: model.WinIdList || []
            }
        }

        Repeater {
            model: windowsModel
        }

        // A single window (a task with one window, or the last one of a dissolved
        // group): the row itself has no children, so it is read directly
        Loader {
            active: groupDialog.showLast

            sourceComponent: GroupThumbnail {
                dialog: groupDialog
                modelIndex: groupDialog.lastWindowIndex()
                windowTitle: groupDialog.lastWindowData(Qt.DisplayRole) || ""
                windowIcon: groupDialog.lastWindowData(Qt.DecorationRole)
                isActive: groupDialog.lastWindowData(TaskManager.AbstractTasksModel.IsActive) || false
                isMinimized: groupDialog.lastWindowData(TaskManager.AbstractTasksModel.IsMinimized) || false
                winIdList: groupDialog.lastWindowData(TaskManager.AbstractTasksModel.WinIdList) || []
            }
        }
        }
    }

    onVisibleChanged: {
        if (!visible) {
            destroy();
        }
    }
}
