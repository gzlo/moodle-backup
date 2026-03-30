# 🗄️ Moodle Backup CLI (`mb`)

Sistema de backup automatizado para Moodle con streaming a Google Drive, modo mantenimiento, y notificaciones por email.

[![CI](https://github.com/gzlo/moodle-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/gzlo/moodle-backup/actions/workflows/ci.yml)

## ⚡ Instalación Rápida

```bash
# Opción 1: Desde el repo
git clone https://github.com/gzlo/moodle-backup.git /opt/moodle-backup
cd /opt/moodle-backup
sudo make install

# Opción 2: One-liner
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/scripts/install.sh | sudo bash
```

## 🚀 Uso

```bash
# Ver ayuda
mb help

# Crear y configurar una instancia
mb moodlesite create mi-moodle
nano /opt/moodle-backup/configs/available/mi-moodle.config
mb moodlesite enable mi-moodle

# Probar configuración
mb test mi-moodle

# Ejecutar backup completo
mb backup mi-moodle

# Ejecutar en background
mb run mi-moodle

# Ver estado
mb status

# Ver logs
mb logs mi-moodle
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
│   ├── config.sh               # Gestión de configuraciones
│   ├── notifications.sh        # Notificaciones email
│   ├── backup_maintenance.sh   # Fase 1: BD + App
│   ├── backup_streaming.sh     # Fase 2: moodledata streaming
│   └── backup_orchestrator.sh  # Orquestador completo
├── configs/                    # Configuraciones
│   ├── available/              # Configs disponibles
│   └── enabled/                # Symlinks a configs activas
├── scripts/                    # Scripts auxiliares
│   ├── install.sh              # Instalador
│   ├── uninstall.sh            # Desinstalador
│   ├── cron_wrapper.sh         # Wrapper para cron
│   ├── cron_monitor.sh         # Monitor de cron
│   └── check_dependencies.sh   # Verificador de deps
├── tests/                      # Tests BATS
│   ├── unit/                   # Tests unitarios
│   ├── integration/            # Tests de integración
│   ├── mocks/                  # Mocks (mysql, rclone, etc.)
│   ├── fixtures/               # Configs de prueba
│   └── docker/                 # Docker test environment
├── Makefile                    # install, test, lint
└── .github/workflows/ci.yml   # CI/CD
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
