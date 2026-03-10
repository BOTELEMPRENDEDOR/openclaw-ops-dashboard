# OpenClaw Operations Dashboard

Panel operativo para monitoreo de OpenClaw con dos modos de datos:

- **Tiempo real**: `server.js` ejecuta `collect.sh` en el mismo host donde existe `openclaw`.
- **Fallback estático**: si el runtime no puede ejecutar OpenClaw CLI (caso típico en Vercel), sirve `data.json`.

## Qué quedó resuelto

- Frontend con login y manejo de sesión local.
- Backend con Basic Auth vía `/api/login` + `/api/data`.
- Sin credenciales hardcodeadas por defecto: ahora el backend falla cerrado si faltan `ADMIN_USER` / `ADMIN_PASS`.
- Fallback claro entre **realtime** y **static-fallback**.
- `healthz` con estado de auth y disponibilidad de fallback.
- Recolección JSON robusta en `collect.sh` usando `jq`, con orden correcto de `recent_jobs`.
- Configuración de Vercel con headers básicos y timeout explícito.

## Estructura

```text
openclaw-ops-dashboard/
├── collect.sh
├── data.json
├── dashboard.html
├── server.js
├── package.json
├── vercel.json
├── README.md
├── INTEGRATION.md
└── STATUS.md
```

## Requisitos locales

- Node.js >= 16
- `jq`
- `bash`
- `openclaw` CLI disponible en PATH para modo tiempo real

## Instalación local

```bash
cd /root/.openclaw/workspace/tools/openclaw-ops-dashboard
npm install
```

## Variables de entorno

### Obligatorias para auth

```bash
export ADMIN_USER='tu-usuario'
export ADMIN_PASS='tu-password-largo-y-unico'
```

### Opcionales

```bash
export PORT=3000
export DISABLE_AUTH=1   # solo para debug local; no usar en producción
```

## Uso local

### Ejecutar servidor

```bash
ADMIN_USER=admin ADMIN_PASS='cambia-esto' npm start
```

Rutas:

- `GET /` → UI del dashboard
- `POST /api/login` → devuelve token Basic Auth codificado
- `GET /api/data` → datos en tiempo real o fallback estático
- `GET /data.json` → fallback estático protegido
- `GET /healthz` → health público del servicio

### Generar / actualizar fallback estático

```bash
./collect.sh > data.json
```

## Despliegue en Vercel

### Lo que sí hace bien en Vercel

- Sirve el frontend
- Ejecuta auth
- Expone `healthz`
- Devuelve `data.json` cuando no puede correr OpenClaw CLI

### Lo que no puede hacer Vercel por sí solo

- Ejecutar `openclaw` del VPS remoto
- Entregar telemetría real del host donde corre OpenClaw

### Configuración mínima recomendada en Vercel

Variables de entorno del proyecto:

- `ADMIN_USER`
- `ADMIN_PASS`

### Dos formas de operar

#### Opción A — Vercel como frontend + fallback estático

1. Despliega este repo en Vercel.
2. Configura `ADMIN_USER` y `ADMIN_PASS`.
3. Actualiza `data.json` desde el VPS cuando quieras refrescar el snapshot.
4. El panel mostrará banner de fallback cuando no haya tiempo real.

#### Opción B — VPS para realtime real

1. Corre `server.js` directamente en el VPS donde existe OpenClaw.
2. Protege el acceso con reverse proxy o red privada.
3. Si quieres UI en Vercel, apunta `/api/data` del frontend a un backend real separado o publica todo detrás de un mismo proxy.

## Seguridad básica aplicada

- Auth obligatoria salvo `DISABLE_AUTH=1`.
- Sin password por defecto embebido.
- `Cache-Control: no-store` en respuestas.
- `X-Content-Type-Options: nosniff` y `Referrer-Policy: same-origin` en Vercel.
- `x-powered-by` deshabilitado.

## Validación local sugerida

```bash
./collect.sh | jq '.generated, .gateway.state, (.recent_jobs | length)'
ADMIN_USER=admin ADMIN_PASS=test node server.js
curl http://127.0.0.1:3000/healthz
curl -X POST http://127.0.0.1:3000/api/login \
  -H 'content-type: application/json' \
  -d '{"user":"admin","pass":"test"}'
```

## Estado actual

- **Local/VPS**: listo para tiempo real
- **Vercel**: listo para frontend + auth + fallback estático
- **Bloqueo externo**: si se quiere realtime en Vercel, hace falta un backend externo real o cambiar arquitectura
