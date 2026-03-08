# OpenClaw Operations Dashboard

Dashboard operativo para monitoreo de OpenClaw en tiempo real.

## Estructura

```
openclaw-ops-dashboard/
├── collect.sh          # Recolector de datos REALES (ejecuta comandos OpenClaw)
├── data.json           # Datos actuales (generado por collect.sh)
├── dashboard.html      # Panel visual (HTML estático)
├── server.js           # Servidor Node para despliegue (expone /api/data)
├── package.json        # Dependencias (express, cors)
├── vercel.json         # Configuración para Vercel (opcional)
├── README.md           # Este archivo
├── INTEGRATION.md      # Plan de integración
└── STATUS.md           # Estado actual del proyecto
```

## Uso local (VPS)

### Requisitos

- Node.js >= 16.x
- `openclaw` CLI disponible en PATH
- `bash` para ejecutar `collect.sh`

### Instalación

```bash
cd /root/.openclaw/workspace/tools/openclaw-ops-dashboard
npm install
```

### Ejecutar servidor

```bash
npm start
```

El dashboard estará disponible en `http://localhost:3000` (o puerto configurado en `PORT`).

- `GET /` → `dashboard.html`
- `GET /api/data` → Ejecuta `collect.sh` y retorna JSON fresco
- `GET /data.json` → Sirve `data.json` estático (fallback)

### Regenerar datos manualmente

```bash
npm run collect  # equivalente a ./collect.sh > data.json
```

## Despliegue en Vercel

### Opción A: Frontend estático + backend externo

1. Despliega este repo en Vercel (Vercel detectará `server.js` y lo desplegará como función serverless).
2. **Nota**: `/api/data` en Vercel no puede ejecutar comandos `openclaw` del host. Para datos en tiempo real, usa un endpoint externo en tu VPS:
   - Ejecuta `npm start` en el VPS en un puerto público (ej. 3000).
   - Configura un proxy/reverse proxy (nginx) o usa el VPS como backend para `/api/data`.
   - En `dashboard.html`, cambia la URL de datos al endpoint del VPS: `const DATA_URL = 'http://tu-vps-ip:3000/api/data';`

### Opción B: Solo frontend estático (GitHub Pages o Vercel estático)

1. Sube `dashboard.html` a un repo y usa GitHub Pages o Vercel para servirlo.
2. Usa `/api/data` desde tu VPS (como en Opción A) o publica `data.json` manualmente en cada despliegue.

## Autenticación de GitHub para push

El repo está configurado para push a `https://github.com/BOTELEMPRENDEDOR/openclaw-ops-dashboard.git`. Para poder hacer push, configura `gh` con el PAT entregado por David:

```bash
export GH_TOKEN="tu-pat-aqui"
gh auth setup --git-protocol=ssh --hostname github.com --scopes "repo,workflow"
```

O usa `git` directamente con token en la URL HTTPS (no recomendado para repos públicos):

```bash
git remote set-url origin https://TOKEN@github.com/BOTELEMPRENDEDOR/openclaw-ops-dashboard.git
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

## Seguridad

- El dashboard es de solo lectura.
- `collect.sh` ejecuta comandos `openclaw` con permisos del usuario que corre el servidor.
- Si expones `/api/data` públicamente, considera agregar autenticación básica o restrict IP.

---

**Nota**: Para datos en tiempo real, el servidor debe correr en el mismo host que OpenClaw o tener acceso a sus comandos vía SSH/API.
