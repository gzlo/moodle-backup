#!/bin/bash
# =============================================================================
# INSTALADOR - Moodle Backup CLI
# =============================================================================
# Uso: curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/scripts/install.sh | bash
# O:   ./scripts/install.sh
# =============================================================================

set -euo pipefail

INSTALL_DIR="${MB_INSTALL_DIR:-/opt/moodle-backup}"
BIN_LINK="/usr/local/bin/mb"
REPO_URL="https://github.com/gzlo/moodle-backup.git"
LOG_DIR="/var/log/moodle-backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

msg() { echo -e "${GREEN}[MB]${NC} $1"; }
warn() { echo -e "${YELLOW}[MB]${NC} $1"; }
err() { echo -e "${RED}[MB]${NC} $1" >&2; }

# Verificar root
if [ "$(id -u)" -ne 0 ]; then
    err "Este instalador debe ejecutarse como root"
    echo "  sudo bash scripts/install.sh"
    exit 1
fi

msg "=== Instalando Moodle Backup CLI ==="
echo ""

# Detectar si estamos ejecutando desde el repo clonado
if [ -f "$(dirname "$0")/../bin/mb" ]; then
    SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    msg "Instalando desde directorio local: $SOURCE_DIR"
else
    msg "Clonando repositorio..."
    SOURCE_DIR=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$SOURCE_DIR" 2>/dev/null || {
        err "No se pudo clonar el repositorio"
        exit 1
    }
fi

# Crear directorio de instalación
msg "Instalando en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copiar archivos
cp -r "$SOURCE_DIR/bin" "$INSTALL_DIR/"
cp -r "$SOURCE_DIR/lib" "$INSTALL_DIR/"
cp -r "$SOURCE_DIR/scripts" "$INSTALL_DIR/"

# Configuraciones: crear estructura pero no sobreescribir configs existentes
mkdir -p "$INSTALL_DIR/configs/available" "$INSTALL_DIR/configs/enabled"
if [ -f "$SOURCE_DIR/configs/available/moodle.config.example" ]; then
    cp "$SOURCE_DIR/configs/available/moodle.config.example" "$INSTALL_DIR/configs/available/"
fi

# Permisos de ejecución
chmod +x "$INSTALL_DIR/bin/mb"
chmod +x "$INSTALL_DIR/lib/"*.sh
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# Crear symlink global
msg "Creando symlink: $BIN_LINK → $INSTALL_DIR/bin/mb"
ln -sf "$INSTALL_DIR/bin/mb" "$BIN_LINK"

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Verificar instalación
if "$BIN_LINK" --version >/dev/null 2>&1; then
    echo ""
    msg "=== ✅ Instalación completada ==="
    echo ""
    echo -e "  Versión: $("$BIN_LINK" --version)"
    echo -e "  Ubicación: $INSTALL_DIR"
    echo -e "  Comando: mb"
    echo ""
    echo -e "${YELLOW}Próximos pasos:${NC}"
    echo "  1. Crear configuración:  mb moodlesite create mi-moodle"
    echo "  2. Editar:               nano $INSTALL_DIR/configs/available/mi-moodle.config"
    echo "  3. Habilitar:            mb moodlesite enable mi-moodle"
    echo "  4. Probar:               mb test mi-moodle"
    echo "  5. Ejecutar backup:      mb backup mi-moodle"
else
    err "La instalación falló - mb no responde"
    exit 1
fi

# Limpiar si se clonó temporalmente
if [ "$SOURCE_DIR" != "$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" ]; then
    rm -rf "$SOURCE_DIR"
fi
