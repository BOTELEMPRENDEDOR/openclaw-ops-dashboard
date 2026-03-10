#!/bin/bash
set -euo pipefail

OUTPUT_FILE="${1:-}"
TIMESTAMP=$(date -Iseconds)
NOW_MS=$(( $(date +%s) * 1000 ))

run_json() {
  local cmd=("$@")
  local output
  if output=$("${cmd[@]}" 2>/dev/null) && [ -n "$output" ] && echo "$output" | jq -e '.' >/dev/null 2>&1; then
    echo "$output"
  else
    echo "null"
  fi
}

STATUS_JSON=$(run_json openclaw status --json)
CRON_JSON=$(run_json openclaw cron list --json)
CHANNELS_JSON=$(run_json openclaw channels status --json)
SECURITY_JSON=$(run_json openclaw security audit --json)
NODE_VERSION=$(node -v 2>/dev/null || echo "unavailable")

PAYLOAD=$(jq -n \
  --arg generated "$TIMESTAMP" \
  --arg nodeVersion "$NODE_VERSION" \
  --argjson nowMs "$NOW_MS" \
  --argjson status "$STATUS_JSON" \
  --argjson cron "$CRON_JSON" \
  --argjson channels "$CHANNELS_JSON" \
  --argjson security "$SECURITY_JSON" '
  def hasData($v): ($v != null and $v != false);
  def gatewayState($status):
    if ($status | hasData(.gateway.reachable) and .gateway.reachable == true) then "ready"
    elif ($status | hasData(.gateway.error) and (.gateway.error | tostring | length) > 0) then "error"
    elif $status == null then "unavailable"
    else "not_ready"
    end;
  def cronJobs:
    ($cron.jobs // [])
    | map({
        id: .id,
        name: (.name // "unknown"),
        schedule: (.schedule.expr // .schedule.kind // "unknown"),
        status: (.state.lastStatus // .state.lastRunStatus // "unknown"),
        lastStatus: (.state.lastRunStatus // "unknown"),
        next: (if (.state.nextRunAtMs // null) != null then (((.state.nextRunAtMs - $nowMs) / 60000) | floor | if . < 0 then 0 else . end | tostring) + "m" else "scheduled" end),
        durationMs: (.state.lastDurationMs // 0)
      });
  def recentJobs:
    ($cron.jobs // [])
    | map(select((.state.lastRunAtMs // null) != null)
      | {
          name: (.name // "unknown"),
          lastRun: .state.lastRunAtMs,
          status: (.state.lastRunStatus // "unknown"),
          duration: (.state.lastDurationMs // 0)
        })
    | sort_by(.lastRun) | reverse | .[:5];
  def securityWarnTitle:
    (($security.findings // []) | map(select(.severity == "warn") | .title) | .[0]) // "Security warnings present";

  {
    generated: $generated,
    data_source: "openclaw_cli",
    system: {
      hostname: ($status.gateway.self.host // "unavailable"),
      ip: ($status.gateway.self.ip // "unavailable"),
      os: ($status.os.label // "unavailable"),
      node: $nodeVersion,
      version: ($status.gateway.self.version // "unavailable"),
      available: ($status != null)
    },
    gateway: {
      state: gatewayState($status),
      reachable: ($status.gateway.reachable // false),
      url: ($status.gateway.url // "unknown"),
      mode: ($status.gateway.mode // "unknown"),
      error: ($status.gateway.error // "")
    },
    agents: {
      default: ($status.agents.defaultId // "unknown"),
      total: ($status.agents.totalSessions // 0),
      list: ($status.agents.agents // [])
    },
    sessions: {
      total: ($status.sessions.count // 0),
      recent: (($status.sessions.recent // [])[:5])
    },
    channels: {
      telegram: {
        running: ($channels.channels.telegram.running // false),
        configured: ($channels.channels.telegram.configured // false)
      },
      whatsapp: {
        linked: ($channels.channels.whatsapp.linked // false),
        running: ($channels.channels.whatsapp.running // false),
        lastError: ($channels.channels.whatsapp.lastError // "unavailable")
      }
    },
    cron: {
      total: ($cron.total // 0),
      jobs: cronJobs,
      active: (($cron.jobs // []) | map(select((.state.runningAtMs // null) != null) | {name: (.name // "unknown"), startedAt: .state.runningAtMs})),
      failed: (($cron.jobs // []) | map(select((.state.consecutiveErrors // 0) > 0) | {name: (.name // "unknown"), errors: (.state.consecutiveErrors // 0), lastStatus: (.state.lastStatus // .state.lastRunStatus // "unknown")})),
      healthy: (($cron.jobs // []) | map(select((.state.lastStatus // .state.lastRunStatus // "unknown") == "ok" and (.state.consecutiveErrors // 0) == 0) | {name: (.name // "unknown"), lastRun: (.state.lastRunAtMs // 0)}))
    },
    recent_jobs: recentJobs,
    security: {
      critical: ($security.summary.critical // 0),
      warnings: ($security.summary.warn // 0),
      info: ($security.summary.info // 0),
      findings: ($security.findings // [])
    },
    blockers: ([
      (if ($channels.channels.whatsapp.linked // false) == false then {type: "channel", channel: "whatsapp", issue: "Not linked (session expired)", severity: "high"} else empty end),
      (if ($security.summary.warn // 0) > 0 then {type: "security", issue: securityWarnTitle, severity: "medium"} else empty end)
    ]),
    next_steps: ([
      (if ($channels.channels.whatsapp.linked // false) == false then "Vincular WhatsApp: openclaw channels link whatsapp" else empty end),
      (if (($cron.jobs // []) | map(select((.state.consecutiveErrors // 0) > 0)) | length) > 0 then "Revisar trabajos con errores en cron" else empty end),
      (if ($security.summary.warn // 0) > 0 then "Ejecutar openclaw security audit --deep para detalles" else empty end)
    ] | if length == 0 then ["Sistema operativo - sin acciones pendientes"] else . end),
    data_quality: {
      dynamic: ["system", "gateway", "agents", "sessions", "channels", "cron", "security"],
      heuristic: ["blockers", "next_steps"],
      stub: ["recent_results"]
    }
  }
')

if [ -n "$OUTPUT_FILE" ]; then
  printf '%s\n' "$PAYLOAD" > "$OUTPUT_FILE"
fi

printf '%s\n' "$PAYLOAD"
