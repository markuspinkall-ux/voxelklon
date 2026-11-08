#!/bin/sh
# Startskript innerhalb des Flatpaks
exec /app/lib/creative-craft/CreativeCraft.x86_64 --main-pack /app/lib/creative-craft/CreativeCraft.pck "$@"
