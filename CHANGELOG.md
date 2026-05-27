# Changelog

Todos los cambios notables de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).
Este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

_Proximas mejoras pendientes._

## [5.0.2] - 2026-05-27

### Fixed
- **MariaDB 10.11 compatibilidad** (`lib/backup_maintenance.sh`): reemplazado `MYSQL_PWD` por `--defaults-extra-file` con archivo `.cnf` temporal (permisos 600). Resuelve autenticacion fallida con ciertos passwords en MariaDB 10.11 (INC-001).
- **mysqldump exit code 5** (`lib/backup_maintenance.sh`): ahora se acepta exit code 5 (warnings) como exito valido. Previene falsos negativos en dumps completos con tablas MyISAM o vistas con definers distintos (INC-002).
- **Comillas en option files** (`lib/backup_maintenance.sh`): archivo `.cnf` generado sin comillas dobles en valores. MySQL/MariaDB interpretaba las comillas como parte literal del valor (INC-003).
- **trap EXIT anidado + set -u** (`lib/backup_maintenance.sh`): eliminado `trap _phase1_cleanup EXIT` anidado. Cleanup explicito antes de cada `return` evita `unbound variable` en bash 4.x (INC-004).
- **rclone lsf antes de verificar acceso** (`lib/backup_orchestrator.sh`): reordenado `cleanup_old_backups()` para verificar acceso a cloud primero, luego ejecutar `rclone lsf` con `|| true`. Evita aborto del script en primer backup (INC-005).
- **DB_PORT forzado a 3306** (`lib/config.sh`): eliminado default `DB_PORT=3306` cuando no configurado. `--port` solo se pasa si `DB_PORT` tiene valor explicito, preservando conexion via Unix socket (INC-006).
- **Falso positivo permisos de symlink** (`lib/config.sh`): `readlink -f` resuelve symlinks antes de `stat -c "%a"`. Evita warning "permisos inseguros" en symlinks que siempre muestran 777 (INC-007).
- **mb run falso negativo** (`bin/mb`): aumentado `sleep` de 2s a 4s y citado `$pid` en `ps -p "$pid"`. Reduce falsos negativos al verificar proceso en background (INC-008).

## [5.0.1] - 2026-05-26

### Security
- **Credenciales MySQL**: `-p"$DB_PASSWORD"` reemplazado por `MYSQL_PWD` env var. Las credenciales ya no son visibles en `/proc/PID/cmdline`.
- **Passphrase GPG**: `--passphrase "$GPG_PASSPHRASE"` reemplazado por `--passphrase-fd 0` con pipe. Eliminada la exposicion en `/proc`.
- **Contraseña SMTP**: `--user user:pass` en curl reemplazado por `--netrc-file` con archivo temporal de permisos 600.
- **Permisos de configuracion**: `chmod 600` forzado al crear configs con el wizard. Warning en `load_moodle_config` si los permisos son inseguros.
- **Sanitizacion de configs**: `source` restringido a lineas de asignacion `KEY="value"` mediante `grep`, previniendo ejecucion de codigo arbitrario desde archivos de configuracion.

### Fixed
- **Heartbeats**: directorio con `chmod 700` para evitar lectura por otros usuarios.
- **nohup $0**: ruta resuelta con `readlink -f` para evitar fallos con paths relativos en cron.
- **Errores visibles**: eliminado `2>/dev/null` en 5 sitios de `load_moodle_config` para facilitar debugging.
- **Comentario de version** en `bin/mb` corregido (decia `4.0.0`).

## [5.0.0] - 2026-05-26

### Added
- **Lock file global** (`lib/backup_lock.sh`): previene backups concurrentes sobre la misma instancia. Stale lock detection con PID + timestamp, timeout configurable.
- **Rollback/cleanup automatico**: limpieza de archivos parciales (.sql, .zip, .tar.gz) en fallo de Phase 1, Phase 2 y orquestador. Upload parcial con rollback de archivos ya subidos.
- **Verificacion de integridad SHA256**: checksums para BD, App y moodledata. Streaming genera checksum inline (`tar | tee >(sha256sum) | rclone rcat`). Verificacion con `sha256sum -c` desde cloud. Configurable via `VERIFY_INTEGRITY`.
- **Cifrado GPG** (`lib/backup_encryption.sh`): soporte simetrico (AES256 con passphrase) y asimetrico (clave publica). Integrado en Phase 1 (post-zip) y Phase 2 (`tar | gpg | rclone rcat`). Configurable via `ENCRYPT_BACKUPS`.
- **Health check** (`mb health <config>`): heartbeat file con timestamp ISO8601. Exit codes 0=OK, 1=atrasado, 2=nunca ejecutado. Integrable con Nagios/Zabbix.
- **Notificaciones por webhook** (`lib/notifications_webhook.sh`): Discord (embeds con color), Slack (blocks), Telegram (bot API). Integrados en las 5 funciones de notificacion de fase.
- **Reintentos con backoff exponencial** (`retry_with_backoff()`): aplicado a `rclone move`, `rclone mkdir`. Configurable via `MAX_RETRIES` y `RETRY_INITIAL_WAIT`.
- **Rate limiting de upload** (`--bwlimit`): limite de ancho de banda en `rclone move` y `rclone rcat`. Configurable via `UPLOAD_BANDWIDTH_LIMIT` (KBps).
- **Backup incremental** (`lib/backup_incremental.sh`): basado en timestamp del ultimo heartbeat. `tar --newer` para streaming, `find -newermt | zip -@` para app. Fallback automatico a full si no hay backup previo.
- **Modo `--dry-run`**: valida configuracion y requisitos sin ejecutar backup. Muestra plan de ejecucion completo.
- **Soporte PostgreSQL**: `pg_dump` en `backup_database()`, validacion con `psql`, deteccion en wizard via `$CFG->dbtype`. Configurable via `DB_ENGINE`.
- **i18n es/en** (`lib/i18n.sh`): infraestructura de traduccion con 67 claves. CLI, help, status y subjects de email traducidos. Auto-deteccion desde `LANG` del sistema.
- **`mb health`**: nuevo subcomando (exit code 0/1/2 para monitoreo).
- **37+ nuevos tests BATS**: `test_backup_lock.bats` (9), `test_backup_encryption.bats` (6), `test_backup_requirements.bats` (7), tests de integridad (2), heartbeat (4), webhooks (6), retry (3), dry-run (3), PostgreSQL (2).

### Changed
- Version bump: `4.2.0` → `5.0.0`
- `upload_to_cloud()`: maneja `*.zip` y `*.gpg`, sube `*.sha256`, rollback en upload parcial.
- `backup_database()`: soporta MySQL (`mysqldump`) y PostgreSQL (`pg_dump`) via `case`.
- `validate_phase1_requirements()`: bifurca validacion MySQL vs PostgreSQL.
- `test_config()`: validacion de GPG, PostgreSQL, y webhooks.
- `perform_streaming_backup()`: acepta `checksum_file`, cifrado GPG en pipe, `--bwlimit`.
- `verify_streaming_backup()`: reescrito con `sha256sum -c` (antes solo `rclone ls`).
- `run_phase2()`: nombre de archivo con extension `.gpg` si cifrado activo.
- `run_full_backup()`: lock global, heartbeat, dry-run, cleanup orquestador.
- `create_config()` wizard: paso extra para webhooks, deteccion de `$CFG->dbtype`.
- `bin/mb`: filtro `--dry-run`, `load_locale()`, subcomando `health`, strings i18n.
- `moodle.config.example`: +25 nuevas variables documentadas (cifrado, webhooks, lock, retry, rate limit, incremental, i18n, heartbeat, PostgreSQL).
- Librerias: 8 → 14 (+6 nuevas: backup_lock, backup_encryption, notifications_webhook, backup_incremental, i18n, server_detect).
- Mocks: +3 (`gpg`, `pg_dump`, `zip`). `rclone` actualizado con `rcat`, `cat`, `delete`, `purge`. `mysqldump` actualizado con output SQL.
- ShellCheck: 0 errores, 0 warnings. SC2329 y SC2059 justificados (trap + printf i18n).

### Fixed
- `BOLD=''` en `lib/utils.sh:23` documentado como bug conocido.
- `phase2_success=true` seteado correctamente en rama de exito.
- `hb_exit` sin `local` en `bin/mb` (SC2168).
- SC2317/SC2015 ShellCheck en trap handlers, checksums y webhooks.
- `validate_encryption()` sin manejo de `ENCRYPTION_METHOD` desconocido.
- `_notify_webhooks` ahora usa `declare -F` + `if/then` para ser opcional sin romper tests.
- Tests con falsos positivos eliminados: `|| true` en `load_moodle_config`, `validate_phase1_requirements`, `run_phase2 cleanup`.
- Test hibrido `backup --dry-run` reemplazado por 7 tests unitarios aislados de `validate_phase1_requirements`.
- Tests CLI fortalecidos con validacion de output (no solo exit code).
- Mocks corregidos: `gpg` crea `--output`, `zip` crea archivo, `mysqldump`/`pg_dump` generan output, `rclone ls` devuelve formato valido.
- Nuevo test de integracion `check_streaming_prerequisites` (exito y fallo).
- Mock `psql` agregado para validacion PostgreSQL.

## [4.2.0] - 2026-03-30

### Added
- Auto-detección de servidor y paneles de control (cPanel/WHM, Plesk, HestiaCP, CyberPanel, CloudPanel, DirectAdmin, Webmin/Virtualmin, ISPConfig, Docker)
- Nuevo módulo `lib/server_detect.sh` con 8 funciones de detección
- Nuevo comando `mb detect` muestra info completa del servidor
- Wizard mejorado: detecta panel, lista instalaciones Moodle encontradas con selección interactiva
- 18 tests unitarios para detección de servidor

## [4.1.0] - 2026-03-30

### Added
- Soporte multi-cloud: S3, Azure Blob, Backblaze B2, Dropbox, SFTP y cualquier remote de rclone
- ASCII art banner de bienvenida en el CLI
- Documentación completa de prerequisitos (rclone + configuración cloud)
- Guía de múltiples proveedores cloud en README (S3, Azure, B2, Dropbox, SFTP)
- Release workflow mejorado: changelog automático + checksums SHA256
- CONTRIBUTING.md con reglas de contribución (solo PR, sin merge automático)
- Sección de seguridad en README

### Changed
- Refactor: todas las variables `GDRIVE_*` renombradas a `CLOUD_*` con compatibilidad hacia atrás
- `upload_to_gdrive()` renombrado a `upload_to_cloud()` en todos los módulos
- Wizard actualizado: paso de Google Drive ahora es "Cloud Storage (rclone)"
- GitHub Actions actualizado a `actions/checkout@v5` (Node.js 24)
- CHANGELOG.md reformateado con estándar Keep a Changelog
- Email de contacto reemplazado por URL de GitHub para privacidad

### Fixed
- Todos los warnings de shellcheck resueltos (SC2155, SC2086, SC2181, SC2164, SC1090, SC2034, SC2064, SC2115)
- Test de versión corregido para coincidir con banner ASCII

## [4.0.0] - 2026-03-30

### Added
- **CLI `mb`**: Comando global con subcomandos (backup, run, list, status, logs, test, test-email, cron, moodlesite)
- **Multi-configuración**: Soporte para múltiples instancias Moodle (patrón nginx available/enabled)
- **Fase 1**: Backup BD + App con modo mantenimiento automático
- **Fase 2**: Streaming moodledata a Google Drive sin espacio local (tar | rclone rcat)
- **Multi-transport email**: 6 transportes (SMTP/curl, msmtp, ssmtp, mailx, sendmail, API HTTP) con auto-detección y fallback
- **Wizard interactivo**: 5 pasos con auto-detección de Moodle, DB, rclone, email
- **Retención**: Limpieza automática de backups antiguos en GDrive
- **Cron**: Wrapper con periodicidad configurable (diario, semanal, quincenal, mensual, custom)
- **Packaging**: Generadores .deb y .rpm
- **Installer**: `curl | bash` para instalación rápida
- Suite completa BATS (53 tests: unit + integration)
- Docker Compose para tests con MariaDB real
- CI con GitHub Actions (shellcheck + BATS + Docker)

### Changed
- Reescritura completa basada en scripts de producción probados (moodle-bkp-v3)
- Arquitectura modular: 7 librerías independientes extraídas de scripts monolíticos
- Instalación en `/opt/moodle-backup/` con symlink `/usr/local/bin/mb`

[Unreleased]: https://github.com/gzlo/moodle-backup/compare/v5.0.0...HEAD
[5.0.0]: https://github.com/gzlo/moodle-backup/compare/v4.2.0...v5.0.0
[4.2.0]: https://github.com/gzlo/moodle-backup/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/gzlo/moodle-backup/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/gzlo/moodle-backup/releases/tag/v4.0.0
