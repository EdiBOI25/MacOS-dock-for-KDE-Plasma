#!/bin/bash
# Reload plasmashell to pick up QML changes to this plasmoid, without
# tying plasmashell's lifetime to this terminal (Ctrl+C / closing the
# terminal won't kill it).
kstart plasmashell -- --replace
