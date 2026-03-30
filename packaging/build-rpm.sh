#!/bin/bash
# =============================================================================
# BUILD .RPM PACKAGE - Moodle Backup CLI
# =============================================================================
# Genera un paquete .rpm instalable con: sudo dnf install moodle-backup_*.rpm
# Requiere: rpmbuild (rpm-build package)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_DIR/lib/utils.sh"

PKG_NAME="moodle-backup"
PKG_VERSION="${MB_VERSION:-4.0.0}"
INSTALL_PREFIX="/opt/moodle-backup"
BUILD_ROOT="/tmp/${PKG_NAME}-rpm-build"
RPMBUILD_DIR="$HOME/rpmbuild"

echo "=== Building .rpm package v${PKG_VERSION} ==="

# Setup rpmbuild structure
mkdir -p "$RPMBUILD_DIR"/{SPECS,SOURCES,BUILD,RPMS,SRPMS}

# Create tarball for rpmbuild
TARBALL_DIR="/tmp/${PKG_NAME}-${PKG_VERSION}"
rm -rf "$TARBALL_DIR"
mkdir -p "$TARBALL_DIR"

cp -r "$PROJECT_DIR/bin" "$TARBALL_DIR/"
cp -r "$PROJECT_DIR/lib" "$TARBALL_DIR/"
cp -r "$PROJECT_DIR/scripts" "$TARBALL_DIR/"
mkdir -p "$TARBALL_DIR/configs/available" "$TARBALL_DIR/configs/enabled"
cp "$PROJECT_DIR/configs/available/moodle.config.example" "$TARBALL_DIR/configs/available/"

cd /tmp && tar czf "$RPMBUILD_DIR/SOURCES/${PKG_NAME}-${PKG_VERSION}.tar.gz" "${PKG_NAME}-${PKG_VERSION}"
rm -rf "$TARBALL_DIR"

# Create spec file
cat > "$RPMBUILD_DIR/SPECS/${PKG_NAME}.spec" << EOF
Name:           ${PKG_NAME}
Version:        ${PKG_VERSION}
Release:        1%{?dist}
Summary:        Moodle Backup CLI Tool
License:        MIT
URL:            https://github.com/gzlo/moodle-backup
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       bash >= 4.0, mysql, php-cli, tar, gzip, zip
Recommends:     rclone

%description
Sistema de backup automatizado para Moodle con streaming a Google Drive,
modo mantenimiento automático, y notificaciones por email.

%prep
%setup -q

%install
mkdir -p %{buildroot}${INSTALL_PREFIX}/{bin,lib,scripts,configs/available,configs/enabled}
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/var/log/moodle-backup

cp bin/mb %{buildroot}${INSTALL_PREFIX}/bin/
cp lib/*.sh %{buildroot}${INSTALL_PREFIX}/lib/
cp scripts/*.sh %{buildroot}${INSTALL_PREFIX}/scripts/
cp configs/available/moodle.config.example %{buildroot}${INSTALL_PREFIX}/configs/available/

chmod +x %{buildroot}${INSTALL_PREFIX}/bin/mb
chmod +x %{buildroot}${INSTALL_PREFIX}/lib/*.sh
chmod +x %{buildroot}${INSTALL_PREFIX}/scripts/*.sh

ln -sf ${INSTALL_PREFIX}/bin/mb %{buildroot}/usr/local/bin/mb

%files
${INSTALL_PREFIX}/
/usr/local/bin/mb
%dir /var/log/moodle-backup

%post
echo "✅ Moodle Backup CLI instalado. Ejecuta: mb help"

%changelog
* $(date "+%a %b %d %Y") GZLOnline <dev@gzlonline.com> - ${PKG_VERSION}-1
- Complete rewrite as modular CLI tool
EOF

# Build
rpmbuild -bb "$RPMBUILD_DIR/SPECS/${PKG_NAME}.spec" 2>&1

OUTPUT=$(find "$RPMBUILD_DIR/RPMS" -name "${PKG_NAME}*.rpm" -type f | head -1)
if [ -n "$OUTPUT" ]; then
    mkdir -p "$PROJECT_DIR/dist"
    cp "$OUTPUT" "$PROJECT_DIR/dist/"
    echo "✅ Package: $PROJECT_DIR/dist/$(basename "$OUTPUT")"
    echo "   Install: sudo dnf install ./$(basename "$OUTPUT")"
else
    echo "❌ Build failed"
    exit 1
fi
