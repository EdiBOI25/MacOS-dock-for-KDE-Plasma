# dockregion plugin

Optional C++ plugin from upstream 1.5. It shapes the panel to the dock (rounded,
24 px corners) and lets that shape grow and shrink with magnification. The panel's
own background and shadow are hidden, leaving KWin's blur behind the dock shape.
Without the plugin, the dock falls back to the normal panel background.

Don't use it together with Panel Colorizer on the same panel: both set the panel
mask, shadow margins and background opacity. The Colorizer look is saved as a preset.

## Install

1. Build (no sudo; output in `dockregion/build/`, git-ignored):

   ```bash
   cmake -B dockregion/build -S dockregion
   cmake --build dockregion/build
   ```

2. Install only the plugin. Not `cmake --install`: that also installs the widget
   under upstream's Id into `/usr/share`.

   ```bash
   sudo cp -r dockregion/build/bin/org/kde/plasma/icontasks2 /usr/lib64/qt6/qml/org/kde/plasma/
   ```

3. Turn it on:
   - `./reload-plasma.sh`
   - Dock settings → Appearance → untick "Keep the panel background and shadow"

## Uninstall

1. Tick "Keep the panel background and shadow" again (reverts the look at once).
2. Remove the plugin and reload:

   ```bash
   sudo rm -r /usr/lib64/qt6/qml/org/kde/plasma/icontasks2
   ./reload-plasma.sh
   ```

3. Optionally delete `dockregion/build/`.

## Maintenance

After a big Qt or Plasma update the plugin may stop loading; the dock then falls
back to the normal background. Rebuild and reinstall (steps 1–2) to fix it.
