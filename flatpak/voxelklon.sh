#!/bin/sh
# Startskript innerhalb des Flatpaks
exec /app/lib/voxelklon/VoxelKlon.x86_64 --main-pack /app/lib/voxelklon/VoxelKlon.pck "$@"
