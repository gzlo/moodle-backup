#!/bin/bash
# =============================================================================
# BUILD .DEB PACKAGE - Moodle Backup CLI
# =============================================================================
# Genera un paquete .deb instalable con: sudo dpkg -i moodle-backup_*.deb
# Requiere: dpkg-deb
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_DIR/lib/utils.sh"

PKG_NAME="moodle-backup"
PKG_VERSION="${MB_VERSION:-4.0.0}"
PKG_ARCH="all"
INSTALL_PREFIX="/opt/moodle-backup"
BUILD_DIR="/tmp/${PKG_NAME}-deb-build"

echo "=== Building .deb package v${PKG_VERSION} ==="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR${INSTALL_PREFIX}/"{bin,lib,scripts,configs/available,configs/enabled}
mkdir -p "$BUILD_DIR/usr/local/bin"
mkdir -p "$BUILD_DIR/var/log/moodle-backup"

# Copy files
cp "$PROJECT_DIR/bin/mb" "$BUILD_DIR${INSTALL_PREFIX}/bin/"
cp "$PROJECT_DIR/lib/"*.sh "$BUILD_DIR${INSTALL_PREFIX}/lib/"
cp "$PROJECT_DIR/scripts/"*.sh "$BUILD_DIR${INSTALL_PREFIX}/scripts/"
cp "$PROJECT_DIR/configs/available/moodle.config.example" "$BUILD_DIR${INSTALL_PREFIX}/configs/available/"

# Permissions
chmod +x "$BUILD_DIR${INSTALL_PREFIX}/bin/mb"
chmod +x "$BUILD_DIR${INSTALL_PREFIX}/lib/"*.sh
chmod +x "$BUILD_DIR${INSTALL_PREFIX}/scripts/"*.sh

# Symlink
ln -sf "${INSTALL_PREFIX}/bin/mb" "$BUILD_DIR/usr/local/bin/mb"

# Control file
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Section: admin
Priority: optional
Architecture: ${PKG_ARCH}
Depends: bash (>= 4.0), mysql-client | mariadb-client, php-cli, tar, gzip, zip
Recommends: rclone, mailutils
Maintainer: GZLOnline <https://github.com/gzlo>
Description: Moodle Backup CLI Tool
 Sistema de backup automatizado para Moodle con streaming a cloud storage,
 modo mantenimiento automático, y notificaciones por email.
 Soporta múltiples instancias y retención configurable.
Homepage: https://github.com/gzlo/moodle-backup
EOF

# Post-install
cat > "$BUILD_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
mkdir -p /var/log/moodle-backup
mkdir -p /opt/moodle-backup/configs/enabled
echo "✅ Moodle Backup CLI instalado. Ejecuta: mb help"
EOF
chmod +x "$BUILD_DIR/DEBIAN/postinst"

# Build
OUTPUT="${PROJECT_DIR}/dist/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"
mkdir -p "$(dirname "$OUTPUT")"
dpkg-deb --build "$BUILD_DIR" "$OUTPUT" 2>/dev/null

echo "✅ Package: $OUTPUT"
echo "   Install: sudo dpkg -i $OUTPUT"
echo "   Or:      sudo apt install ./$OUTPUT"

# Clean
rm -rf "$BUILD_DIR"
