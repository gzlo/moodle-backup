# 🗄️ Moodle Backup CLI (`mb`)

Sistema de backup automatizado para Moodle con streaming a Google Drive, modo mantenimiento, y notificaciones por email.

[![CI](https://github.com/gzlo/moodle-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/gzlo/moodle-backup/actions/workflows/ci.yml)

## ⚡ Instalación

### Opción 1: One-liner (siempre la última versión)
```bash
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/scripts/install.sh | sudo bash
```

### Opción 2: Paquete .deb (Debian/Ubuntu)
```bash
# Descargar de GitHub Releases
wget https://github.com/gzlo/moodle-backup/releases/latest/download/moodle-backup_4.0.0_all.deb
sudo apt install ./moodle-backup_4.0.0_all.deb
```

### Opción 3: Paquete .rpm (RHEL/Fedora/CentOS)
```bash
wget https://github.com/gzlo/moodle-backup/releases/latest/download/moodle-backup-4.0.0-1.noarch.rpm
sudo dnf install ./moodle-backup-4.0.0-1.noarch.rpm
```

### Opción 4: Desde el repo
```bash
git clone https://github.com/gzlo/moodle-backup.git /opt/moodle-backup
cd /opt/moodle-backup
sudo make install
```

## 🚀 Inicio Rápido

```bash
# Crear configuración con wizard interactivo (4 pasos)
mb moodlesite create mi-moodle

# El wizard te pregunta:
# 📂 Paso 1/4: Rutas (auto-detecta Moodle y moodledata)
# 🗄️ Paso 2/4: Base de datos (lee config.php automáticamente)
# ☁️ Paso 3/4: Google Drive (detecta remotes de rclone)
# 📧 Paso 4/4: Email y servidor (usa hostname del sistema)
# → Al final pregunta si habilitar. ¡Listo!

# Probar que todo está bien
mb test mi-moodle

# Ejecutar backup
mb backup mi-moodle
```

## 📋 Comandos

| Comando | Descripción |
|---------|-------------|
| `mb backup <config>` | Ejecutar backup completo (Fase 1 + Fase 2) |
| `mb run <config>` | Ejecutar backup en background |
| `mb list` | Listar configuraciones |
| `mb status` | Estado del sistema |
| `mb logs <config>` | Ver logs recientes |
| `mb test <config>` | Probar configuración |
| `mb cron` | Monitor del cron |
| `mb moodlesite <cmd>` | Gestión de configuraciones |

### Gestión de Configuraciones

```bash
mb moodlesite list              # Listar todas
mb moodlesite create <nombre>   # Crear nueva
mb moodlesite enable <nombre>   # Habilitar
mb moodlesite disable <nombre>  # Deshabilitar
mb moodlesite show <nombre>     # Ver detalles
mb moodlesite test <nombre>     # Probar
```

## 🔄 Proceso de Backup

El backup se ejecuta en dos fases:

### Fase 1: Backup BD + Aplicación
1. Activa modo mantenimiento de Moodle
2. Dump de base de datos MySQL → ZIP
3. Comprime directorio de aplicación → ZIP
4. Desactiva modo mantenimiento
5. Sube ZIPs a Google Drive con rclone
6. Envía notificación por email

### Fase 2: Streaming Moodledata
1. Comprime moodledata con tar+gzip
2. **Streaming directo a Google Drive** (sin espacio local adicional)
3. Verifica archivo en GDrive
4. Envía notificación por email

## ⚙️ Configuración

Cada instancia Moodle tiene su archivo `.config` en `configs/available/`. Ejemplo:

```bash
# configs/available/mi-moodle.config
INSTANCE_NAME="mi-moodle"
SRC_APP="/var/www/html/moodle"
SRC_DATA="/var/moodledata"
BACKUP_BASE="/var/backups/moodle"
DB_NAME="moodle_db"
DB_USER="moodle_user"
DB_PASSWORD="secreto"
DB_HOST="localhost"
GDRIVE_REMOTE="gdrive"
GDRIVE_BASE_PATH="moodle_backups"
PHP_CLI="/usr/bin/php"
NOTIFICATION_EMAIL="admin@ejemplo.com"
SERVER_NAME="mi-servidor"
SYSTEM_USER="www-data"
CRON_SCHEDULE="7"        # 1=diario, 4=semanal, 7=custom
RETENTION_COPIES="2"
MOODLEDATA_EXCLUDES="cache/* sessions/* temp/*"
```

Ver `configs/available/moodle.config.example` para todas las opciones.

## ⏰ Automatización con Cron

```bash
# Ejecutar backup mensual el día 28 a las 2 AM
0 2 28 * * /opt/moodle-backup/scripts/cron_wrapper.sh mi-moodle

# Monitorear estado
mb cron
```

## 📂 Estructura

```
moodle-backup/
├── bin/mb                      # CLI entry point
├── lib/                        # Librerías modulares
│   ├── utils.sh                # Colores, helpers
│   ├── logging.sh              # Sistema de logging
│   ├── config.sh               # Gestión de configs + wizard
│   ├── notifications.sh        # Notificaciones email
│   ├── backup_maintenance.sh   # Fase 1: BD + App
│   ├── backup_streaming.sh     # Fase 2: moodledata streaming
│   └── backup_orchestrator.sh  # Orquestador completo
├── configs/                    # Configuraciones
│   ├── available/              # Configs disponibles
│   └── enabled/                # Symlinks a configs activas
├── scripts/                    # Scripts auxiliares
├── packaging/                  # Generadores .deb y .rpm
├── tests/                      # Tests BATS
│   ├── unit/                   # Tests unitarios
│   ├── integration/            # Tests de integración
│   └── docker/                 # Docker test environment
├── Makefile                    # install, test, lint, build-deb, build-rpm
└── .github/workflows/          # CI + Release automático
```

## 🧪 Testing

```bash
# Setup entorno de desarrollo
make dev-setup

# Ejecutar todos los tests
make test

# Solo unitarios
make test-unit

# Con Docker (incluye MariaDB real)
make test-docker

# Lint con shellcheck
make lint
```

## 📋 Requisitos

### Obligatorios
- Bash ≥ 4.0
- mysql client
- PHP CLI
- tar, gzip, zip
- rclone (configurado con remote de Google Drive)

### Verificar dependencias
```bash
mb status
# o
bash scripts/check_dependencies.sh
```

## 📝 Licencia

MIT - Ver [LICENSE](LICENSE)
