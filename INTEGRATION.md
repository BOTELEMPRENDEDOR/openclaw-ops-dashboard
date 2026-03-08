# Plan de Integración

## Objetivo
Dashboard de operaciones OpenClaw accesible via web (Vercel/GitHub Pages).

## Estado Actual
- [x] Estructura de proyecto creada
- [x] Script de recolección de datos (collect.sh)
- [ ] HTML del dashboard
- [ ] Git repository inicializado
- [ ] Despliegue configurado

## Tareas Pendientes

### 1. Dashboard HTML
- [ ] Crear dashboard.html con datos de data.json
- [ ] Diseño responsivo (móvil + escritorio)
- [ ] Indicadores visuales de estado (verde/amarillo/rojo)

### 2. GitHub
- [ ] Inicializar git: `git init`
- [ ] Crear .gitignore
- [ ] Commit inicial
- [ ] Crear repo en GitHub (manual o gh CLI)
- [ ] Push

### 3. Vercel
- [ ] Conectar repo a Vercel
- [ ] Configurar build: `vercel --prod`
- [ ] Domain (opcional)

### 4. Actualización Automática
- [ ] Webhook desde OpenClaw?
- [ ] Cron en servidor actualiza JSON
- [ ] Git push dispara rebuild

## Alternativas de Hosting

| Opción | Costo | Ventajas |
|--------|-------|----------|
| Vercel | Gratis | CI/CD automático, global CDN |
| GitHub Pages | Gratis | Integrado con GitHub |
| Netlify | Gratis | Similar a Vercel |

## API de Datos

Para datos en tiempo real, considerar:

```javascript
// Ejemplo: Endpoint en el servidor OpenClaw
app.get('/api/dashboard', (req, res) => {
  exec('./collect.sh', (err, stdout) => {
    res.json(JSON.parse(stdout));
  });
});
```

Esto permitiría actualizar sin commit+push.

---

**Ultima actualización**: 2026-03-08
