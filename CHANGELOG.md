# Changelog

## [4.0.0] - 2026-03-30

### 🔄 Complete Rewrite
- Reescritura completa basada en scripts de producción probados (moodle-bkp-v3)
- Arquitectura modular con librerías separadas
- CLI tool instalable con `make install` o `curl | bash`

### ✨ Features
- **CLI `mb`**: Comando global con subcomandos (backup, run, list, status, logs, test, cron)
- **Multi-configuración**: Soporte para múltiples instancias Moodle (pattern nginx available/enabled)
- **Fase 1**: Backup BD + App con modo mantenimiento automático
- **Fase 2**: Streaming moodledata a Google Drive sin espacio local
- **Notificaciones**: Emails por fase con estado detallado
- **Retención**: Limpieza automática de backups antiguos en GDrive
- **Cron**: Wrapper con periodicidad configurable (diario, semanal, mensual, custom)

### 🧪 Testing
- Suite completa con BATS (unit + integration)
- Mocks para mysql, rclone, php, mail
- Docker Compose para tests de integración con MariaDB real
- CI con GitHub Actions (shellcheck + BATS + Docker)

### 📦 Instalación
- `make install` para instalación desde clone
- `curl -fsSL .../install.sh | bash` para instalación remota
- Instala en `/opt/moodle-backup/` con symlink `/usr/local/bin/mb`
