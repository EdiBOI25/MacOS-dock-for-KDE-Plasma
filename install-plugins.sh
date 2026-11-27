#!/usr/bin/env bash
# Builds and installs (or removes) the dock's optional QML plugins.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

readonly QML_DIR=/usr/lib64/qt6/qml
readonly DOCKREGION_SRC=dockregion/build/bin/org/kde/plasma/icontasks2
readonly DOCKREGION_DEST=$QML_DIR/org/kde/plasma/icontasks2
readonly BADGES_SRC=badges/build/bin/local/icontasks2byedi/badges
readonly BADGES_DEST=$QML_DIR/local/icontasks2byedi/badges

case "${1:-install}" in
install)
    for project in dockregion badges; do
        cmake -B "$project/build" -S "$project" -DBUILD_TESTING=OFF
        cmake --build "$project/build"
    done
    for src in "$DOCKREGION_SRC" "$BADGES_SRC"; do
        if [[ ! -f $src/qmldir ]] || ! compgen -G "$src/*.so" >/dev/null; then
            echo "Missing build output in $src; nothing installed." >&2
            exit 1
        fi
    done
    if ! sudo sh -c "rm -rf '$DOCKREGION_DEST' '$BADGES_DEST' \
        && mkdir -p '$QML_DIR/org/kde/plasma' '$QML_DIR/local/icontasks2byedi' \
        && cp -r '$DOCKREGION_SRC' '$DOCKREGION_DEST' \
        && cp -r '$BADGES_SRC' '$BADGES_DEST'"; then
        echo "Install failed; the plugins may now be missing (the dock works without them). Run the script again." >&2
        exit 1
    fi
    ;;
uninstall)
    sudo sh -c "rm -rf '$DOCKREGION_DEST' '$BADGES_DEST' \
        && { rmdir '$QML_DIR/local/icontasks2byedi' '$QML_DIR/local' 2>/dev/null || true; }"
    ;;
*)
    echo "Usage: $0 [install|uninstall]" >&2
    exit 2
    ;;
esac

echo "Done. Run ./reload-plasma.sh to apply."
