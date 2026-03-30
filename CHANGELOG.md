# Changelog

Todos los cambios notables de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).
Este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

_Próximas mejoras pendientes._

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

[Unreleased]: https://github.com/gzlo/moodle-backup/compare/v4.1.0...HEAD
[4.1.0]: https://github.com/gzlo/moodle-backup/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/gzlo/moodle-backup/releases/tag/v4.0.0
