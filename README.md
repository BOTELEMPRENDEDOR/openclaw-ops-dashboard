# OpenClaw Operations Dashboard

Dashboard operativo para monitoreo de OpenClaw.

## Estructura

```
openclaw-ops-dashboard/
├── collect.sh          # Recolector de datos REALES desde OpenClaw CLI
├── data.json           # Datos actuales (generado dinámicamente)
├── dashboard.html      # Panel visual
├── README.md           # Este archivo
└── INTEGRATION.md      # Plan de integración
```

## Uso

```bash
# Recolectar datos en tiempo real
./collect.sh > data.json

# Ver dashboard
open dashboard.html en navegador
```

## Datos Dinámicos vs Estáticos

### ✅ Datos Dinámicos (tiempo real)

| Campo | Fuente | Estado |
|-------|--------|--------|
| Sistema (OS, node, hostname) | `openclaw status --json` | ✅ Funcionando |
| Gateway state | `openclaw status --json` | ✅ Funcionando |
| Agents | `openclaw agents list --json` | ✅ Funcionando |
| Sessions | `openclaw status --json` | ✅ Funcionando |
| Cron Jobs | `openclaw cron list --json` | ✅ Funcionando |
| Channels Status | `openclaw channels status --json` | ✅ Funcionando |
| Security Audit | `openclaw security audit --json` | ✅ Funcionando |

### ⚠️ Datos con Degradación

| Campo | Fallback |
|-------|----------|
| hostname/ip | "unknown" si no disponible |
| version | "unknown" si no disponible |
| gateway state | "unavailable" si CLI falla |
| Todos los campos | `null` → se muestra "unknown" |

### ❌ Por hacer ( stubs )

- **Últimos resultados de trabajo**: requiere parseo de logs
- **Blockers detallados**: parcialmente implementado
- **Próximos pasos**: básico, expandir

## Despliegue

### Vercel

```bash
npm i -g vercel
vercel
```

### GitHub Pages

1. Settings > Pages
2. Seleccionar "gh-pages" como source

## Actualización

```bash
# Manual
./collect.sh > data.json
git add data.json
git commit -m "Update dashboard data" && git push

# Automático (cron)
*/5 * * * * cd /root/.openclaw/workspace/tools/openclaw-ops-dashboard && ./collect.sh > data.json
```

---

**Nota**: Dashboard de solo lectura. No modifica configuración de OpenClaw.
