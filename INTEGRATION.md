# Plan de Integración

## Arquitectura final recomendada

### Camino 1: simple y estable
- **Frontend + auth + fallback estático en Vercel**
- **`data.json` actualizado desde el VPS**
- Bueno para snapshot operativo sin exponer OpenClaw directamente

### Camino 2: tiempo real real
- **`server.js` corriendo en el VPS** donde existe `openclaw`
- Reverse proxy / dominio / auth por delante
- Opcionalmente reutilizar el mismo frontend

## Hechos ya completados

- [x] Dashboard HTML funcional
- [x] Backend Node funcional
- [x] Login + auth básica
- [x] Fallback estático documentado y visible en UI
- [x] Health endpoint
- [x] Configuración Vercel básica
- [x] Recolección real via `collect.sh`

## Pendientes reales

- [ ] Push/deploy final
- [ ] Configurar variables `ADMIN_USER` y `ADMIN_PASS` en Vercel
- [ ] Decidir si el modo productivo será snapshot estático o backend realtime en VPS

## Nota clave

**Vercel no sustituye al host OpenClaw.** Si el objetivo es telemetría en tiempo real del VPS, el backend que ejecuta `openclaw` debe vivir en ese VPS o detrás de él.
