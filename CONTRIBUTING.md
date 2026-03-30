# Contribuir a Moodle Backup CLI

¡Gracias por tu interés en contribuir! 🎉

## Reglas

- **Solo Pull Requests** — No se permiten pushes directos a `main`
- **Todos los PRs requieren revisión** antes de merge
- **Los tests deben pasar** — CI ejecuta shellcheck + BATS automáticamente
- **No incluir credenciales** ni datos sensibles en el código

## Cómo contribuir

1. **Fork** el repositorio
2. Crea una rama descriptiva: `git checkout -b fix/nombre-del-fix`
3. Haz tus cambios
4. Ejecuta lint y tests localmente:
   ```bash
   make lint
   make test
   ```
5. Commit con mensaje descriptivo
6. Envía un **Pull Request** a `main`

## Reportar bugs

Abre un [Issue](https://github.com/gzlo/moodle-backup/issues) con:
- Descripción del problema
- Pasos para reproducir
- Sistema operativo y versión de bash

## Seguridad

Si encuentras una vulnerabilidad, **no abras un issue público**. Usa [GitHub Security Advisories](https://github.com/gzlo/moodle-backup/security/advisories/new).
