# TODO

## Known issues

- [x] 1. Grouped task previews: the close ("x") button on window previews is too small/barely visible, and clicking it (or near it) activates the window instead of closing it
- [ ] 2. Pinning a `.desktop` file that has launch arguments/flags creates a new icon instead of launching the app from the existing pinned icon
- [x] 3. The dock doesn't create "anchor points" for windows, so minimizing an app doesn't minimize to its dock icon like the standard KDE panel does
- [ ] 4. When closing grouped instances down to a single remaining one, that last instance can no longer be closed
- [ ] 5. No "preview" dialog shows when only one instance of an app is active. This should be an option in the settings menu.
- [ ] 6. Closing an instance from the dock preview doesn't close that preview tab — it just replaces the preview with the app icon
- [ ] 7. When an app is opened, its "dot" is colored in a dark color. Check how it looks when it's replaced with a lighter system color
- [ ] 8. Sometimes, a newly opened app's icon has only one half displayed. A guess is that the panel doesn't extend sometimes to make room for the new task/icon
- [ ] 9. Reordering icons also minimizes them (if opened) or opens them (if minimized).This seems to happen to unpinned icons only
- [ ] 10. Right clicking an icon doesn't display its "actions". For example, the right click menu for Firefox doesn't display the "New Tab" and "New Private Tab" options.
- [ ] 11. The dock isn't centered: the icons are aligned to the left, so a panel spacer is currently needed to center them. Possible causes: the task list is anchored to `parent.left` in `main.qml` while "Fill available space" is on by default, and the launcher drop gutter only adds space after the last icon

## Future tasks

- [ ] Add "sliding" animation for when moving icons on the taskbar (change position)
