#!/bin/bash

SOURCE_DIR="$HOME/.config/nixos"
DEST_DIR="/etc/nixos"
BACKUP_DIR="$DEST_DIR/backup"

echo "Copying .nix files from $SOURCE_DIR to $DEST_DIR..."
echo ""

# Create fresh backup folder (delete old one if it exists)
echo "Backing up existing files to $BACKUP_DIR..."
sudo rm -rf "$BACKUP_DIR"
sudo mkdir -p "$BACKUP_DIR"

# Backup all existing .nix files
sudo find "$DEST_DIR" -maxdepth 2 -type f -name "*.nix" -not -path "$BACKUP_DIR/*" | while read file; do
  relative_path="${file#$DEST_DIR/}"
  sudo mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
  sudo cp "$file" "$BACKUP_DIR/$relative_path"
  echo "  ✓ Backed up: $relative_path"
done

echo ""
echo "Copying new files..."

# Copy everything recursively
sudo rsync -av --include="*.nix" --exclude="copy-nix*" "$SOURCE_DIR/" "$DEST_DIR/"

echo ""
echo "Done!"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "1. sudo nixos-rebuild test"
echo "2. sudo nixos-rebuild switch"
echo ""
echo "If you need to restore the backup:"
echo "  sudo cp $BACKUP_DIR/* $DEST_DIR/"
