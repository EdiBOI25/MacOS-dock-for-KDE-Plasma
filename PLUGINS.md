# Optional plugins

Two optional C++ QML plugins. The dock works without either; each one only adds
a feature.

| Plugin | Folder | Adds |
|---|---|---|
| dockregion (upstream 1.5) | `dockregion/` | Panel shaped to the dock, growing with magnification |
| badges | `badges/` | Unread-count badges on icons (e.g. Discord) |

## dockregion

Shapes the panel to the dock (rounded, 24 px corners) and lets that shape grow and
shrink with magnification. The panel's own background and shadow are hidden,
leaving KWin's blur behind the dock shape. Without the plugin, the dock falls back
to the normal panel background.

Turn it on after installing: Dock settings → Appearance → untick "Keep the panel
background and shadow". Tick it again to revert the look at once.

Don't use it together with Panel Colorizer on the same panel: both set the panel
mask, shadow margins and background opacity. The Colorizer look is saved as a preset.

## badges

Listens to the Unity launcher D-Bus API (`com.canonical.Unity.LauncherEntry`),
which apps such as Discord, Signal, Telegram, VS Code and Thunderbird use to
publish unread counts. It claims the `com.canonical.Unity` name if it's free, as
Plasma's own task manager does. Without the plugin, icons show no badges.

Run its tests: `cmake -B badges/build -S badges -DBUILD_TESTING=ON && cmake --build badges/build && (cd badges/build && ctest)`.

## Install

```bash
./install-plugins.sh
./reload-plasma.sh
```

The script builds both plugins (output in each `build/` folder, git-ignored), then,
with one `sudo`, replaces their folders under `/usr/lib64/qt6/qml`. It never runs
`cmake --install`: dockregion's CMake would also install the widget under
upstream's Id into `/usr/share`.

## Uninstall

```bash
./install-plugins.sh uninstall
./reload-plasma.sh
```

Optionally delete `dockregion/build/` and `badges/build/`.

## Recovery

If plasmashell keeps crashing after installing (no panel), open Konsole with
Ctrl+Alt+T and run the uninstall commands above.

## Maintenance

After a big Qt or Plasma update a plugin may stop loading; the dock then works
without it. Run `./install-plugins.sh` again to rebuild and reinstall.
