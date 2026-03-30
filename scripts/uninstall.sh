#!/bin/bash
set -euo pipefail

INSTALL_DIR="${MB_INSTALL_DIR:-/opt/moodle-backup}"
BIN_LINK="/usr/local/bin/mb"

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Ejecutar como root: sudo bash scripts/uninstall.sh"
    exit 1
fi

echo "=== Desinstalando Moodle Backup CLI ==="

# Preguntar por configs
if [ -d "$INSTALL_DIR/configs/enabled" ] && ls "$INSTALL_DIR/configs/enabled/"*.config >/dev/null 2>&1; then
    echo "⚠️  Hay configuraciones habilitadas en $INSTALL_DIR/configs/"
    read -p "¿Eliminar configuraciones también? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Conservando $INSTALL_DIR/configs/"
        # Solo eliminar bin/, lib/, scripts/
        rm -rf "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/scripts"
    else
        rm -rf "$INSTALL_DIR"
    fi
else
    rm -rf "$INSTALL_DIR"
fi

rm -f "$BIN_LINK"
echo "✅ Moodle Backup CLI desinstalado"
