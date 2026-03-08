# OpenClaw Operations Dashboard

Dashboard estático para monitoreo de operaciones de OpenClaw.

## Estructura

```
openclaw-ops-dashboard/
├── collect.sh          # Recolecta datos del sistema
├── data.json           # Datos actuales (generado por collect.sh)
├── dashboard.html      # Panel visual simple
├── README.md           # Este archivo
└── INTEGRATION.md      # Plan de integración
```

## Uso

```bash
# Recolectar datos
./collect.sh > data.json

# Ver dashboard
# Abre dashboard.html en un navegador
```

## Datos Incluidos

- **Estado general**: OS, Node, Gateway service
- **Agentes**: Lista de agentes activos
- **Sesiones**: Contador de sesiones
- **Canales**: Estado de Telegram/WhatsApp
- **Cron Jobs**: Trabajos programados y su estado
- **Seguridad**: Warnings y errores
- **Blockers**: Problemas conocidos

## Despliegue

Este proyecto está diseñado para desplegarse en Vercel como sitio estático.

### Vercel

```bash
npm i -g vercel
vercel
```

O conecta el repositorio a Vercel para deployments automáticos.

### GitHub Pages

1. Ve a Settings > Pages
2. Selecciona "gh-pages" como source
3. Saves

## Actualización

Para actualizar los datos en producción:

```bash
# Desde el servidor OpenClaw
cd /root/.openclaw/workspace/tools/openclaw-ops-dashboard
./collect.sh > data.json
git add data.json
git commit -m "Update dashboard data"
git push
```

## Automatización

Agrega un cron en el servidor:

```bash
*/5 * * * * cd /root/.openclaw/workspace/tools/openclaw-ops-dashboard && ./collect.sh > data.json
```

---

**Nota**: Este dashboard es de solo lectura. No modify configuración de OpenClaw.
