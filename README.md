# 🗄️ Moodle Backup CLI (`mb`)

Sistema de backup automatizado para Moodle con streaming a cloud storage (Google Drive, S3, Azure, Dropbox, etc. via rclone), modo mantenimiento, y notificaciones por email.

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
# Crear configuración con wizard interactivo (5 pasos)
mb moodlesite create mi-moodle

# El wizard te pregunta:
# 📂 Paso 1/5: Rutas (auto-detecta Moodle y moodledata)
# 🗄️ Paso 2/5: Base de datos (lee config.php automáticamente)
# ☁️ Paso 3/5: Cloud Storage (detecta remotes de rclone)
# 📧 Paso 4/5: Notificaciones (email, servidor)
# 📨 Paso 5/5: Transporte email (auto-detecta SMTP, msmtp, etc.)
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
| `mb test-email <config>` | Probar envío de email |
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
5. Sube ZIPs a cloud storage con rclone
6. Envía notificación por email

### Fase 2: Streaming Moodledata
1. Comprime moodledata con tar+gzip
2. **Streaming directo a cloud storage** (sin espacio local adicional)
3. Verifica archivo en cloud storage
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
CLOUD_REMOTE="gdrive"
CLOUD_BASE_PATH="moodle_backups"
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
- mysql client (mysql-client o mariadb-client)
- PHP CLI
- tar, gzip, zip
- **rclone** (configurado con remote de cloud storage: Google Drive, S3, Azure, etc.) — ver sección abajo

### Verificar dependencias
```bash
mb status
# o
bash scripts/check_dependencies.sh
```

## ☁️ Configuración de rclone (Cloud Storage)

`mb` usa [rclone](https://rclone.org) para subir backups a cloud storage (Google Drive, S3, Azure, Dropbox, y 70+ proveedores). Es un requisito previo que debe configurarse **antes** de crear tu primera configuración.

### 1. Instalar rclone

```bash
# Método recomendado (última versión):
curl https://rclone.org/install.sh | sudo bash

# O con tu gestor de paquetes:
sudo apt install rclone        # Debian/Ubuntu
sudo dnf install rclone        # Fedora/RHEL
sudo pacman -S rclone          # Arch
```

### 2. Configurar remote (ejemplo: Google Drive)

```bash
rclone config
```

El asistente te guiará paso a paso:

```
n) New remote
name> gdrive                     ← usa "gdrive" como nombre (recomendado)
Storage> drive                   ← selecciona "Google Drive"
client_id>                       ← Enter (usa el default)
client_secret>                   ← Enter (usa el default)
scope> 1                         ← Full access
root_folder_id>                  ← Enter (raíz de Drive)
service_account_file>            ← Enter (no aplica)
Edit advanced config? n
Use auto config? y               ← Si tienes navegador; si es servidor headless, usa "n"
```

> **Servidor sin navegador (headless)?** Selecciona `n` en auto config. rclone te dará una URL para autorizarte desde otra máquina con navegador y pegar el token resultante.

<details>
<summary><b>Otros proveedores (S3, Azure, Backblaze B2, Dropbox...)</b></summary>

#### Amazon S3

```bash
rclone config
# name> s3backup
# Storage> s3
# provider> AWS
# access_key_id> TU_ACCESS_KEY
# secret_access_key> TU_SECRET_KEY
# region> us-east-1
```

#### Azure Blob Storage

```bash
rclone config
# name> azure
# Storage> azureblob
# account> tu-storage-account
# key> tu-access-key
```

#### Backblaze B2

```bash
rclone config
# name> b2
# Storage> b2
# account> tu-account-id
# key> tu-application-key
```

#### Dropbox

```bash
rclone config
# name> dropbox
# Storage> dropbox
# (autorización OAuth vía navegador)
```

#### SFTP (cualquier servidor remoto)

```bash
rclone config
# name> miserver
# Storage> sftp
# host> backup.midominio.com
# user> backup-user
# key_file> ~/.ssh/id_rsa
```

> Ver lista completa de 70+ proveedores: https://rclone.org/overview/

</details>

### 3. Verificar que funciona

```bash
# Listar contenido de tu remote
rclone lsd gdrive:

# Crear carpeta de prueba
rclone mkdir gdrive:moodle_backups

# Subir archivo de prueba
echo "test" > /tmp/test.txt
rclone copy /tmp/test.txt gdrive:moodle_backups/
rclone ls gdrive:moodle_backups/
rm /tmp/test.txt
```

### 4. Usar en mb

Al crear una configuración con `mb moodlesite create`, el wizard detecta automáticamente los remotes configurados en rclone y te permite seleccionar cuál usar.

```bash
# El wizard detecta tus remotes:
# ☁️ Paso 3/5: Cloud Storage
# Remotes disponibles: gdrive, otro-remote
# Remote de rclone [gdrive]: ← Enter para usar el detectado
```

> **Nota**: Si usas un nombre diferente a `gdrive`, simplemente ingrésalo cuando el wizard lo pregunte.

## 🏷️ Releases

Los releases se publican en [GitHub Releases](https://github.com/gzlo/moodle-backup/releases) con paquetes `.deb` y `.rpm` listos para descargar.

## 🤝 Contribuir

Este proyecto acepta contribuciones via **Pull Requests**. No se permiten merges directos a `main`.

1. Fork el repositorio
2. Crea una rama: `git checkout -b mi-feature`
3. Haz tus cambios y agrega tests
4. Envía un PR a `main`

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para más detalles.

## 🔒 Seguridad

Si encuentras una vulnerabilidad, **no abras un issue público**. Envía un reporte privado via [GitHub Security Advisories](https://github.com/gzlo/moodle-backup/security/advisories/new).

## 📝 Licencia

MIT - Ver [LICENSE](LICENSE)
