/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

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
    property string groupAppId: ""
    property int groupIndex: -1

    // Find the (non-launcher) top-level row that carries groupAppId
    function resolveGroupIndex() {
        if (!tasksModel || groupAppId === "") {
            return -1;
        }
        var count = tasksModel.count;
        for (var i = 0; i < count; i++) {
            var idx = tasksModel.makeModelIndex(i);
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher)
                    || tasksModel.data(idx, TaskManager.AbstractTasksModel.IsStartup)) {
                continue;
            }
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId) === groupAppId) {
                return i;
            }
        }
        return -1;
    }

    function updateGroupIndex() {
        // Without an app id we can't re-resolve; keep the index we were given
        if (groupAppId === "") {
            return;
        }
        groupIndex = resolveGroupIndex();
    }

    // Bumped whenever the model changes. The model's rowCount()/data() have no
    // change notifications of their own, so bindings read this to re-evaluate.
    property int refreshCounter: 0

    // dataChanged arrives in bursts (many per second, for any task). Each bump
    // re-reads every thumbnail's data and re-sets its icon, so coalesce them.
    function scheduleRefresh() {
        if (!refreshTimer.running) {
            refreshTimer.start();
        }
    }

    function modelChanged() {
        updateGroupIndex();
        syncWindows();
        refreshCounter++;
        closeIfNotGroup();
    }

    // The group dissolves into a plain task once a single window is left (or
    // vanishes entirely), leaving nothing to list: dismiss the dialog.
    function closeIfNotGroup() {
        if (!visible || groupAppId === "") {
            return;
        }
        if (groupIndex < 0
                || !tasksModel.data(tasksModel.makeModelIndex(groupIndex), TaskManager.AbstractTasksModel.IsGroupParent)) {
            visible = false;
        }
    }

    // Window ids of the group's children, in model order. A window's id is
    // also its identity: it stays the same while its row number shifts.
    function childKeys() {
        var keys = [];
        if (!tasksModel || groupIndex < 0) {
            return keys;
        }
        var parentIdx = tasksModel.makeModelIndex(groupIndex);
        var count = tasksModel.rowCount(parentIdx);
        for (var i = 0; i < count; i++) {
            var ids = tasksModel.data(tasksModel.index(i, 0, parentIdx), TaskManager.AbstractTasksModel.WinIdList);
            keys.push(ids && ids.length > 0 ? String(ids[0]) : "");
        }
        return keys;
    }

    // Bring windowsModel in line with the group using single remove/move/insert
    // operations, so delegates of untouched windows (and their live
    // thumbnails) survive. Assigning a new Repeater model would rebuild all.
    function syncWindows() {
        var keys = childKeys();
        for (var i = windowsModel.count - 1; i >= 0; i--) {
            if (keys.indexOf(windowsModel.get(i).winKey) < 0) {
                windowsModel.remove(i);
            }
        }
        for (var j = 0; j < keys.length; j++) {
            if (j < windowsModel.count && windowsModel.get(j).winKey === keys[j]) {
                continue;
            }
            var from = -1;
            for (var k = j + 1; k < windowsModel.count; k++) {
                if (windowsModel.get(k).winKey === keys[j]) {
                    from = k;
                    break;
                }
            }
            if (from >= 0) {
                windowsModel.move(from, j, 1);
            } else {
                windowsModel.insert(j, { winKey: keys[j] });
            }
        }
    }

    // Current row of a window within the group, -1 if it is gone
    function rowOfKey(key) {
        var _ = refreshCounter;
        return childKeys().indexOf(key);
    }

    function childIndex(row) {
        var _ = refreshCounter;
        if (row < 0) {
            return tasksModel.index(-1, -1);
        }
        return tasksModel.index(row, 0, tasksModel.makeModelIndex(groupIndex));
    }

    function childIndexForKey(key) {
        return childIndex(rowOfKey(key));
    }

    function childData(row, role) {
        return row < 0 ? undefined : tasksModel.data(childIndex(row), role);
    }

    Component.onCompleted: {
        updateGroupIndex();
        syncWindows();
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

        // One entry per window in the group, keyed by window id
        ListModel {
            id: windowsModel
        }

        Timer {
            id: refreshTimer
            interval: 250
            onTriggered: groupDialog.refreshCounter++
        }

        // Keep groupIndex pointing at the group and refresh the thumbnails when the model changes
        Connections {
            target: groupDialog.tasksModel
            function onRowsInserted() { groupDialog.modelChanged(); }
            function onRowsRemoved() { groupDialog.modelChanged(); }
            function onRowsMoved() { groupDialog.modelChanged(); }
            function onLayoutChanged() { groupDialog.modelChanged(); }
            function onModelReset() { groupDialog.modelChanged(); }
            function onDataChanged() {
                groupDialog.scheduleRefresh();
                groupDialog.closeIfNotGroup();
            }
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

        Repeater {
            id: windowRepeater

            model: windowsModel

            delegate: Item {
                id: windowDelegate
                width: groupDialog.thumbnailWidth
                height: groupDialog.thumbnailHeight + titleLabel.height + Kirigami.Units.smallSpacing

                // Stable identity of this delegate's window; its row can change
                required property string winKey
                property int row: groupDialog.rowOfKey(winKey)

                property string windowTitle: groupDialog.childData(row, Qt.DisplayRole) || ""
                property var windowIcon: groupDialog.childData(row, Qt.DecorationRole)
                property bool isActive: groupDialog.childData(row, TaskManager.AbstractTasksModel.IsActive) || false
                property bool isMinimized: groupDialog.childData(row, TaskManager.AbstractTasksModel.IsMinimized) || false
                // Derived from the key (not looked up by row) so a thumbnail
                // never switches windows and its stream isn't restarted
                property var winId: Number(winKey) || 0

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
                            groupDialog.tasksModel.requestClose(groupDialog.childIndexForKey(windowDelegate.winKey));
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                        onClicked: function(mouse) {
                            if (mouse.button === Qt.MiddleButton) {
                                groupDialog.tasksModel.requestClose(groupDialog.childIndexForKey(windowDelegate.winKey));
                            } else {
                                groupDialog.tasksModel.requestActivate(groupDialog.childIndexForKey(windowDelegate.winKey));
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
                                groupDialog.tasksModel.requestOpenUrls(groupDialog.childIndexForKey(windowDelegate.winKey), drop.urls);
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
                            groupDialog.tasksModel.requestActivate(groupDialog.childIndexForKey(windowDelegate.winKey));
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
