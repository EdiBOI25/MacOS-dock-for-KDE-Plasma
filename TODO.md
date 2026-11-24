# TODO

## Known issues

- [x] 1. Grouped task previews: the close ("x") button on window previews is too small/barely visible, and clicking it (or near it) activates the window instead of closing it
- [ ] 2. Pinning a `.desktop` file that has launch arguments/flags creates a new icon instead of launching the app from the existing pinned icon
- [x] 3. The dock doesn't create "anchor points" for windows, so minimizing an app doesn't minimize to its dock icon like the standard KDE panel does
- [x] 4. When closing grouped instances down to a single remaining one, that last instance can no longer be closed
- [x] 5. No "preview" dialog shows when only one instance of an app is active. This should be an option in the settings menu.
- [x] 6. Closing an instance from the dock preview doesn't close that preview tab — it just replaces the preview with the app icon
- [ ] 7. When an app is opened, its "dot" is colored in a dark color. Check how it looks when it's replaced with a lighter system color
- [ ] 8. Sometimes, a newly opened app's icon has only one half displayed. A guess is that the panel doesn't extend sometimes to make room for the new task/icon
- [x] 9. Reordering icons also minimizes them (if opened) or opens them (if minimized).This seems to happen to unpinned icons only
- [x] 10. Right clicking an icon doesn't display its "actions". For example, the right click menu for Firefox doesn't display the "New Tab" and "New Private Tab" options. — Fixed: the menu now reads the app's .desktop actions itself (recent documents/places still missing)
- [x] 11. The dock isn't centered: the icons are aligned to the left, so a panel spacer is currently needed to center them. Possible causes: the task list is anchored to `parent.left` in `main.qml` while "Fill available space" is on by default, and the launcher drop gutter only adds space after the last icon — Fixed by the panel's "Fit content" length + centre alignment; icons only left-align in a full-width panel without the dockregion mask
- [ ] 12. Pinning by dropping a file may partly fail silently: upstream's `code/launcherfromdrop.js` reads `.desktop` files with XMLHttpRequest, which Plasma blocks for local files (QML_XHR_ALLOW_FILE_READ is not set)

## Future tasks

- [ ] Change the focused window's dot color; it currently shows a darkened system color (see known issue 7)
- [ ] Research and add a dragging animation when reordering icons ("sliding" into the new position); currently the icon just jumps
- [ ] Research and add an animation when an app is triggered (e.g. a link opened from another app launches the browser): pulsing, a macOS-style bounce, or similar. Currently the only sign is the dot turning orange
- [ ] Research whether the dot under the active app should become a short line
- [ ] Research notification badges on icons (e.g. Discord's unread count), like Windows and Plasma's own task manager show
