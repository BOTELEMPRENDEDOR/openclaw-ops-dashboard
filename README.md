# OpenClaw Operations Dashboard

Dashboard operativo para monitoreo de OpenClaw.

## Estructura

```
openclaw-ops-dashboard/
├── collect.sh          # Recolector de datos REALES
├── data.json           # Datos actuales
├── dashboard.html      # Panel visual
├── README.md           # Este archivo
└── INTEGRATION.md      # Plan de integración
```

## Uso

```bash
# Recolectar datos
./collect.sh > data.json

# Ver dashboard
# Abre dashboard.html en navegador
```

## Datos: Dinámico vs Heurístico vs Stub

### ✅ Dinámico (fuente real)

| Campo | Fuente | Estado |
|-------|--------|--------|
| system.hostname | gateway.self.host | ✅ |
| system.ip | gateway.self.ip | ✅ |
| system.os | os.label | ✅ |
| system.version | gateway.self.version | ✅ |
| gateway.state | gateway.reachable | ✅ |
| sessions.total | sessions.count | ✅ |
| sessions.recent | sessions.recent[:5] | ✅ |
| cron.jobs | cron list --json | ✅ |
| cron.active | runningAtMs != null | ✅ |
| cron.failed | consecutiveErrors > 0 | ✅ |
| cron.healthy | lastStatus=ok, errors=0 | ✅ |
| recent_jobs | last 5 executed | ✅ |
| channels | channels status --json | ✅ |
| security | security audit --json | ✅ |

### ⚠️ Heurístico (inferido)

| Campo | Lógica |
|-------|--------|
| blockers | Canales no vinculados + warnings de seguridad |
| next_steps | Basado en estado (WA linked? cron failures?) |

### ❌ Stub (por implementar)

| Campo | Notas |
|-------|-------|
| recent_results | Requiere parseo de logs de sesiones |

## Despliegue

### Vercel
```bash
vercel --prod
```

### GitHub Pages
Settings > Pages > gh-pages

---

**Nota**: Dashboard de solo lectura.
