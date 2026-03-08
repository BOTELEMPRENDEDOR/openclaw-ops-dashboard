#!/bin/bash
# OpenClaw Operations Dashboard - Real Data Collector
# Uses actual OpenClaw CLI commands with JSON output

OUTPUT_FILE="${1:-data.json}"
TEMP_DIR=$(mktemp -d)

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

# Helper: Get JSON or return null
get_json() {
    local cmd="$1"
    $cmd > "$TEMP_DIR/out.json" 2>/dev/null
    if [ -s "$TEMP_DIR/out.json" ]; then
        cat "$TEMP_DIR/out.json"
    else
        echo "null"
    fi
}

# Timestamp
TIMESTAMP=$(date -Iseconds)

# ========== SYSTEM INFO ==========
SYSTEM_INFO=$(get_json "openclaw status --json")
CRON_JOBS=$(get_json "openclaw cron list --json")
AGENTS_LIST=$(get_json "openclaw agents list --json")
CHANNELS=$(get_json "openclaw channels status --json")
SECURITY=$(get_json "openclaw security audit --json")

# Check if we got valid data
if [ "$SYSTEM_INFO" = "null" ] || [ -z "$SYSTEM_INFO" ]; then
    SYSTEM_AVAILABLE="false"
else
    SYSTEM_AVAILABLE="true"
fi

if [ "$CRON_JOBS" = "null" ] || [ -z "$CRON_JOBS" ]; then
    CRON_AVAILABLE="false"
else
    CRON_AVAILABLE="true"
fi

# ========== BUILD JSON OUTPUT ==========
echo "{"
echo "  \"generated\": \"$TIMESTAMP\","
echo "  \"data_source\": \"openclaw_cli\","

# System Status
echo "  \"system\": {"
echo "    \"available\": $SYSTEM_AVAILABLE,"
if [ "$SYSTEM_AVAILABLE" = "true" ]; then
    echo "    \"hostname\": \"$(echo "$SYSTEM_INFO" | jq -r '.host.hostname // "unknown"' 2>/dev/null)\","
    echo "    \"ip\": \"$(echo "$SYSTEM_INFO" | jq -r '.host.ip // "unknown"' 2>/dev/null)\","
    echo "    \"os\": \"$(uname -s) $(uname -r)\","
    echo "    \"node\": \"$(node -v 2>/dev/null || echo 'N/A')\","
    echo "    \"version\": \"$(echo "$SYSTEM_INFO" | jq -r '.app.version // "unknown"' 2>/dev/null)\""
else
    echo "    \"hostname\": \"unknown\","
    echo "    \"ip\": \"unknown\","
    echo "    \"os\": \"unknown\","
    echo "    \"node\": \"unknown\","
    echo "    \"version\": \"unknown\""
fi
echo "  },"

# Gateway
echo "  \"gateway\": {"
if [ "$SYSTEM_AVAILABLE" = "true" ]; then
    GATEWAY_STATE=$(echo "$SYSTEM_INFO" | jq -r '.gateway.state // "unknown"' 2>/dev/null)
    echo "    \"state\": \"$GATEWAY_STATE\","
    echo "    \"url\": \"$(echo "$SYSTEM_INFO" | jq -r '.gateway.url // "unknown"' 2>/dev/null)\""
else
    echo "    \"state\": \"unavailable\","
    echo "    \"url\": \"unknown\""
fi
echo "  },"

# Agents
echo "  \"agents\": {"
echo "    \"available\": $([ "$AGENTS_LIST" != "null" ] && echo "true" || echo "false"),"
if [ "$AGENTS_LIST" != "null" ] && [ -n "$AGENTS_LIST" ]; then
    AGENT_COUNT=$(echo "$AGENTS_LIST" | jq 'length' 2>/dev/null || echo "0")
    echo "    \"count\": $AGENT_COUNT,"
    echo "    \"list\": $AGENTS_LIST"
else
    echo "    \"count\": 0,"
    echo "    \"list\": []"
fi
echo "  },"

# Sessions
echo "  \"sessions\": {"
if [ "$SYSTEM_AVAILABLE" = "true" ]; then
    echo "    \"total\": $(echo "$SYSTEM_INFO" | jq -r '.sessions.count // 0' 2>/dev/null),"
    echo "    \"recent\": $(echo "$SYSTEM_INFO" | jq '.sessions.recent // []' 2>/dev/null)"
else
    echo "    \"total\": 0,"
    echo "    \"recent\": []"
fi
echo "  },"

# Channels
echo "  \"channels\": {"
echo "    \"available\": $([ "$CHANNELS" != "null" ] && echo "true" || echo "false"),"
if [ "$CHANNELS" != "null" ] && [ -n "$CHANNELS" ]; then
    TG_RUNNING=$(echo "$CHANNELS" | jq -r '.channels.telegram.running // false' 2>/dev/null)
    WA_RUNNING=$(echo "$CHANNELS" | jq -r '.channels.whatsapp.running // false' 2>/dev/null)
    TG_ERROR=$(echo "$CHANNELS" | jq -r '.channels.whatsapp.lastError // "none"' 2>/dev/null)
    
    echo "    \"telegram\": {"
    echo "      \"running\": $TG_RUNNING,"
    echo "      \"configured\": $(echo "$CHANNELS" | jq -r '.channels.telegram.configured // false' 2>/dev/null)"
    echo "    },"
    echo "    \"whatsapp\": {"
    echo "      \"running\": $WA_RUNNING,"
    echo "      \"linked\": $(echo "$CHANNELS" | jq -r '.channels.whatsapp.linked // false' 2>/dev/null),"
    echo "      \"lastError\": \"$TG_ERROR\""
    echo "    }"
else
    echo "    \"telegram\": { \"running\": false, \"configured\": false },"
    echo "    \"whatsapp\": { \"running\": false, \"linked\": false, \"lastError\": \"unavailable\" }"
fi
echo "  },"

# Cron Jobs
echo "  \"cron_jobs\": {"
echo "    \"available\": $CRON_AVAILABLE,"
if [ "$CRON_AVAILABLE" = "true" ]; then
    echo "    \"total\": $(echo "$CRON_JOBS" | jq '.total // 0' 2>/dev/null),"
    echo "    \"jobs\": ["
    JOBS=$(echo "$CRON_JOBS" | jq -c '.jobs[]' 2>/dev/null)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        
        ID=$(echo "$job" | jq -r '.id // "unknown"' 2>/dev/null)
        NAME=$(echo "$job" | jq -r '.name // "unnamed"' 2>/dev/null)
        STATUS=$(echo "$job" | jq -r '.state.lastStatus // "unknown"' 2>/dev/null)
        SCHEDULE=$(echo "$job" | jq -r '.schedule.expr // .schedule.kind // "unknown"' 2>/dev/null)
        
        # Next run time
        NEXT=$(echo "$job" | jq -r '.state.nextRunAtMs // 0' 2>/dev/null)
        if [ "$NEXT" != "0" ] && [ "$NEXT" != "null" ]; then
            NEXT_MINUTES=$(( (NEXT - $(date +%s) * 1000) / 60000 ))
            if [ "$NEXT_MINUTES" -lt 0 ]; then
                NEXT_STR="<1m"
            else
                NEXT_STR="${NEXT_MINUTES}m"
            fi
        else
            NEXT_STR="unknown"
        fi
        
        echo -n "      {\"id\": \"$ID\", \"name\": \"$NAME\", \"schedule\": \"$SCHEDULE\", \"status\": \"$STATUS\", \"next\": \"$NEXT_STR\"}"
    done <<< "$JOBS"
    echo ""
    echo "    ]"
else
    echo "    \"total\": 0,"
    echo "    \"jobs\": []"
fi
echo "  },"

# Security
echo "  \"security\": {"
if [ "$SECURITY" != "null" ] && [ -n "$SECURITY" ]; then
    echo "    \"critical\": $(echo "$SECURITY" | jq -r '.summary.critical // 0' 2>/dev/null),"
    echo "    \"warnings\": $(echo "$SECURITY" | jq -r '.summary.warn // 0' 2>/dev/null),"
    echo "    \"info\": $(echo "$SECURITY" | jq -r '.summary.info // 0' 2>/dev/null),"
    echo "    \"findings\": $(echo "$SECURITY" | jq '.findings // []' 2>/dev/null)"
else
    echo "    \"critical\": 0,"
    echo "    \"warnings\": 0,"
    echo "    \"info\": 0,"
    echo "    \"findings\": []"
fi
echo "  },"

# Active Jobs (from cron jobs with recent activity)
echo "  \"active_jobs\": ["
if [ "$CRON_AVAILABLE" = "true" ]; then
    JOBS=$(echo "$CRON_JOBS" | jq -c '.jobs[] | select(.state.lastRunStatus == "ok") | {name: .name, lastRun: .state.lastRunAtMs, status: .state.lastStatus}' 2>/dev/null)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        echo -n "  $job"
    done <<< "$JOBS"
    echo ""
fi
echo "  ],"

# Blockers
echo "  \"blockers\": ["
if [ "$CHANNELS" != "null" ]; then
    WA_LINKED=$(echo "$CHANNELS" | jq -r '.channels.whatsapp.linked // false' 2>/dev/null)
    WA_ERROR=$(echo "$CHANNELS" | jq -r '.channels.whatsapp.lastError // ""' 2>/dev/null)
    
    FIRST=1
    if [ "$WA_LINKED" = "false" ]; then
        echo "    {\"type\": \"channel\", \"channel\": \"whatsapp\", \"issue\": \"Not linked (session expired or not configured)\"}"
        FIRST=0
    fi
    
    # Check Telegram group policy warning
    if [ "$SYSTEM_AVAILABLE" = "true" ]; then
        TG_WARN=$(echo "$SYSTEM_INFO" | jq -r '.doctor[] | select(.contains("groupPolicy"))' 2>/dev/null)
        if [ -n "$TG_WARN" ]; then
            [ "$FIRST" -eq 0 ] && echo ","
            echo "    {\"type\": \"channel\", \"channel\": \"telegram\", \"issue\": \"groupPolicy allowlist empty - groups silently dropped\"}"
        fi
    fi
fi
echo "  ],"

# Next Steps (dynamic based on state)
echo "  \"next_steps\": ["
if [ "$CHANNELS" != "null" ]; then
    WA_LINKED=$(echo "$CHANNELS" | jq -r '.channels.whatsapp.linked // false' 2>/dev/null)
    if [ "$WA_LINKED" = "false" ]; then
        echo "    \"Vincular WhatsApp: ejecutar openclaw channels link whatsapp\","
        echo "    \"Revisar configuración de grupo en Telegram\""
    else
        echo "    \"Monitorear trabajos activos\","
        echo "    \"Revisar logs de sesiones\""
    fi
else
    echo "    \"Verificar conectividad con OpenClaw\""
fi
echo "  ],"

# Data freshness indicator
echo "  \"metadata\": {"
echo "    \"collector_version\": \"1.0.0\","
echo "    \"dynamic_data\": true,"
echo "    \"sources\": ["
echo "      \"openclaw status --json\","
echo "      \"openclaw cron list --json\","
echo "      \"openclaw agents list --json\","
echo "      \"openclaw channels status --json\","
echo "      \"openclaw security audit --json\""
echo "    ]"
echo "  }"
echo "}"
