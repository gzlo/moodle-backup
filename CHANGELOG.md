# Changelog

Todos los cambios notables de este proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).
Este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

_Próximas mejoras pendientes._

## [4.1.0] - 2026-03-30

### Added
- Documentación completa de prerequisitos (rclone + Google Drive)
- Guía de releases y versionado en README
- Release workflow mejorado: changelog automático + checksums SHA256
- Sección de configuración rclone paso a paso

### Changed
- GitHub Actions actualizado a `actions/checkout@v5` (Node.js 24)
- CHANGELOG.md reformateado con estándar Keep a Changelog
- Release workflow extrae changelog por versión automáticamente

### Fixed
- Todos los warnings de shellcheck resueltos (SC2155, SC2086, SC2181, SC2164, SC1090, SC2034, SC2064, SC2115)

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
