#!/bin/bash
# OpenClaw Operations Dashboard - Real Data Collector v1.1
# Fixed parsing for gateway, hostname, IP, version
# Separates active jobs from recent jobs

OUTPUT_FILE="${1:-data.json}"
TEMP_DIR=$(mktemp -d)

trap "rm -rf $TEMP_DIR" EXIT

TIMESTAMP=$(date -Iseconds)

# Get raw JSON data
STATUS_JSON=$(openclaw status --json 2>/dev/null)
CRON_JSON=$(openclaw cron list --json 2>/dev/null)
AGENTS_JSON=$(openclaw agents list --json 2>/dev/null)
CHANNELS_JSON=$(openclaw channels status --json 2>/dev/null)
SECURITY_JSON=$(openclaw security audit --json 2>/dev/null)

# Helper: check if JSON is valid
is_valid_json() {
    [ -n "$1" ] && echo "$1" | jq -e '.' >/dev/null 2>&1
}

# ========== SYSTEM ==========
echo "{"
echo "  \"generated\": \"$TIMESTAMP\","
echo "  \"data_source\": \"openclaw_cli\","

# System - FIXED PARSING
echo "  \"system\": {"
if is_valid_json "$STATUS_JSON"; then
    echo "    \"hostname\": \"$(echo "$STATUS_JSON" | jq -r '.gateway.self.host // "unknown"')\","
    echo "    \"ip\": \"$(echo "$STATUS_JSON" | jq -r '.gateway.self.ip // "unknown"')\","
    echo "    \"os\": \"$(echo "$STATUS_JSON" | jq -r '.os.label // "unknown"')\","
    echo "    \"node\": \"$(node -v 2>/dev/null || echo 'N/A')\","
    echo "    \"version\": \"$(echo "$STATUS_JSON" | jq -r '.gateway.self.version // "unknown"')\","
    echo "    \"available\": true"
else
    echo "    \"hostname\": \"unavailable\","
    echo "    \"ip\": \"unavailable\","
    echo "    \"os\": \"unavailable\","
    echo "    \"node\": \"unavailable\","
    echo "    \"version\": \"unavailable\","
    echo "    \"available\": false"
fi
echo "  },"

# Gateway - FIXED PARSING
echo "  \"gateway\": {"
if is_valid_json "$STATUS_JSON"; then
    REACHABLE=$(echo "$STATUS_JSON" | jq -r '.gateway.reachable // false')
    URL=$(echo "$STATUS_JSON" | jq -r '.gateway.url // "unknown"')
    MODE=$(echo "$STATUS_JSON" | jq -r '.gateway.mode // "unknown"')
    ERROR=$(echo "$STATUS_JSON" | jq -r '.gateway.error // empty')
    
    if [ "$REACHABLE" = "true" ]; then
        STATE="ready"
    elif [ "$ERROR" != "null" ] && [ -n "$ERROR" ]; then
        STATE="error"
    else
        STATE="not_ready"
    fi
    
    echo "    \"state\": \"$STATE\","
    echo "    \"reachable\": $REACHABLE,"
    echo "    \"url\": \"$URL\","
    echo "    \"mode\": \"$MODE\","
    echo "    \"error\": \"${ERROR}\""
else
    echo "    \"state\": \"unavailable\","
    echo "    \"reachable\": false,"
    echo "    \"url\": \"unknown\","
    echo "    \"mode\": \"unknown\","
    echo "    \"error\": \"CLI not accessible\""
fi
echo "  },"

# Agents
echo "  \"agents\": {"
if is_valid_json "$STATUS_JSON"; then
    echo "    \"default\": \"$(echo "$STATUS_JSON" | jq -r '.agents.defaultId // "unknown"')\","
    echo "    \"total\": $(echo "$STATUS_JSON" | jq -r '.agents.totalSessions // 0'),"
    echo "    \"list\": $(echo "$STATUS_JSON" | jq '.agents.agents // []')"
else
    echo "    \"default\": \"unknown\","
    echo "    \"total\": 0,"
    echo "    \"list\": []"
fi
echo "  },"

# Sessions
echo "  \"sessions\": {"
if is_valid_json "$STATUS_JSON"; then
    echo "    \"total\": $(echo "$STATUS_JSON" | jq -r '.sessions.count // 0'),"
    echo "    \"recent\": $(echo "$STATUS_JSON" | jq '.sessions.recent // []' | jq '.[:5]')"
else
    echo "    \"total\": 0,"
    echo "    \"recent\": []"
fi
echo "  },"

# Channels
echo "  \"channels\": {"
if is_valid_json "$CHANNELS_JSON"; then
    TG_RUNNING=$(echo "$CHANNELS_JSON" | jq -r '.channels.telegram.running // false')
    TG_CONFIGURED=$(echo "$CHANNELS_JSON" | jq -r '.channels.telegram.configured // false')
    WA_LINKED=$(echo "$CHANNELS_JSON" | jq -r '.channels.whatsapp.linked // false')
    WA_RUNNING=$(echo "$CHANNELS_JSON" | jq -r '.channels.whatsapp.running // false')
    WA_ERROR=$(echo "$CHANNELS_JSON" | jq -r '.channels.whatsapp.lastError // "none"')
    
    echo "    \"telegram\": {"
    echo "      \"running\": $TG_RUNNING,"
    echo "      \"configured\": $TG_CONFIGURED"
    echo "    },"
    echo "    \"whatsapp\": {"
    echo "      \"linked\": $WA_LINKED,"
    echo "      \"running\": $WA_RUNNING,"
    echo "      \"lastError\": \"$WA_ERROR\""
    echo "    }"
else
    echo "    \"telegram\": { \"running\": false, \"configured\": false },"
    echo "    \"whatsapp\": { \"linked\": false, \"running\": false, \"lastError\": \"unavailable\" }"
fi
echo "  },"

# Cron Jobs - FIXED: separate active, recent, healthy, failed
echo "  \"cron\": {"
if is_valid_json "$CRON_JSON"; then
    TOTAL=$(echo "$CRON_JSON" | jq '.total // 0')
    echo "    \"total\": $TOTAL,"
    
    # All jobs
    echo "    \"jobs\": ["
    JOBS=$(echo "$CRON_JSON" | jq -c '.jobs[]' 2>/dev/null)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        
        ID=$(echo "$job" | jq -r '.id')
        NAME=$(echo "$job" | jq -r '.name')
        STATUS=$(echo "$job" | jq -r '.state.lastStatus // "unknown"')
        SCHEDULE=$(echo "$job" | jq -r '.schedule.expr // .schedule.kind')
        
        NEXT=$(echo "$job" | jq -r '.state.nextRunAtMs // 0')
        if [ "$NEXT" != "0" ] && [ "$NEXT" != "null" ]; then
            NEXT_MINUTES=$(( (NEXT - $(date +%s) * 1000) / 60000 ))
            [ "$NEXT_MINUTES" -lt 0 ] && NEXT_MINUTES=0
            NEXT_STR="${NEXT_MINUTES}m"
        else
            NEXT_STR="scheduled"
        fi
        
        LAST_STATUS=$(echo "$job" | jq -r '.state.lastRunStatus // "unknown"')
        DURATION=$(echo "$job" | jq -r '.state.lastDurationMs // 0')
        
        echo -n "      {\"id\": \"$ID\", \"name\": \"$NAME\", \"schedule\": \"$SCHEDULE\", \"status\": \"$STATUS\", \"lastStatus\": \"$LAST_STATUS\", \"next\": \"$NEXT_STR\", \"durationMs\": $DURATION}"
    done <<< "$JOBS"
    echo ""
    echo "    ],"
    
    # Active jobs (currently running - has runningAtMs)
    echo "    \"active\": ["
    ACTIVE_JOBS=$(echo "$CRON_JSON" | jq -c '.jobs[] | select(.state.runningAtMs != null)' 2>/dev/null)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        NAME=$(echo "$job" | jq -r '.name')
        RUNNING_AT=$(echo "$job" | jq -r '.state.runningAtMs')
        echo -n "{\"name\": \"$NAME\", \"startedAt\": $RUNNING_AT}"
    done <<< "$ACTIVE_JOBS"
    echo ""
    echo "    ],"
    
    # Failed jobs
    echo "    \"failed\": ["
    FAILED_JOBS=$(echo "$CRON_JSON" | jq -c '.jobs[] | select(.state.consecutiveErrors > 0)' 2>/dev/null)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        NAME=$(echo "$job" | jq -r '.name')
        ERRORS=$(echo "$job" | jq -r '.state.consecutiveErrors')
        LAST_ERR=$(echo "$job" | jq -r '.state.lastStatus')
        echo -n "{\"name\": \"$NAME\", \"errors\": $ERRORS, \"lastStatus\": \"$LAST_ERR\"}"
    done <<< "$FAILED_JOBS"
    echo ""
    echo "    ],"
    
    # Healthy jobs (lastStatus == ok, no errors)
    echo "    \"healthy\": ["
    HEALTHY_JOBS=$(echo "$CRON_JSON" | jq -c '.jobs[] | select(.state.lastStatus == "ok" and (.state.consecutiveErrors // 0) == 0)' 2>/dev/null)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        NAME=$(echo "$job" | jq -r '.name')
        LAST_RUN=$(echo "$job" | jq -r '.state.lastRunAtMs')
        echo -n "{\"name\": \"$NAME\", \"lastRun\": $LAST_RUN}"
    done <<< "$HEALTHY_JOBS"
    echo ""
    echo "    ]"
else
    echo "    \"total\": 0,"
    echo "    \"jobs\": [],"
    echo "    \"active\": [],"
    echo "    \"failed\": [],"
    echo "    \"healthy\": []"
fi
echo "  },"

# Recent Jobs (last 5 executed)
echo "  \"recent_jobs\": ["
if is_valid_json "$CRON_JSON"; then
    RECENT=$(echo "$CRON_JSON" | jq -c '.jobs[] | select(.state.lastRunAtMs != null) | {name: .name, lastRun: .state.lastRunAtMs, status: .state.lastRunStatus, duration: .state.lastDurationMs}' 2>/dev/null | head -5)
    FIRST=1
    while IFS= read -r job; do
        [ -z "$job" ] && continue
        [ "$FIRST" -eq 0 ] && echo ","
        FIRST=0
        echo -n "  $job"
    done <<< "$RECENT"
    echo ""
fi
echo "  ],"

# Security
echo "  \"security\": {"
if is_valid_json "$SECURITY_JSON"; then
    echo "    \"critical\": $(echo "$SECURITY_JSON" | jq -r '.summary.critical // 0'),"
    echo "    \"warnings\": $(echo "$SECURITY_JSON" | jq -r '.summary.warn // 0'),"
    echo "    \"info\": $(echo "$SECURITY_JSON" | jq -r '.summary.info // 0'),"
    echo "    \"findings\": $(echo "$SECURITY_JSON" | jq '.findings // []')"
else
    echo "    \"critical\": 0,"
    echo "    \"warnings\": 0,"
    echo "    \"info\": 0,"
    echo "    \"findings\": []"
fi
echo "  },"

# Blockers - IMPROVED with specific detection
echo "  \"blockers\": ["
FIRST=1
if is_valid_json "$CHANNELS_JSON"; then
    WA_LINKED=$(echo "$CHANNELS_JSON" | jq -r '.channels.whatsapp.linked // false')
    if [ "$WA_LINKED" = "false" ]; then
        echo "    {\"type\": \"channel\", \"channel\": \"whatsapp\", \"issue\": \"Not linked (session expired)\", \"severity\": \"high\"}"
        FIRST=0
    fi
fi

if is_valid_json "$SECURITY_JSON"; then
    HAS_WARN=$(echo "$SECURITY_JSON" | jq -r '.summary.warn // 0')
    if [ "$HAS_WARN" -gt 0 ]; then
        [ "$FIRST" -eq 0 ] && echo ","
        FINDING=$(echo "$SECURITY_JSON" | jq -r '.findings[] | select(.severity == "warn") | .title' 2>/dev/null | head -1)
        echo "    {\"type\": \"security\", \"issue\": \"$FINDING\", \"severity\": \"medium\"}"
    fi
fi
echo "  ],"

# Next Steps - IMPROVED based on actual state
echo "  \"next_steps\": ["
FIRST=1

# Check WhatsApp
if is_valid_json "$CHANNELS_JSON"; then
    WA_LINKED=$(echo "$CHANNELS_JSON" | jq -r '.channels.whatsapp.linked // false')
    if [ "$WA_LINKED" = "false" ]; then
        [ "$FIRST" -eq 0 ] && echo ","
        echo "    \"Vincular WhatsApp: openclaw channels link whatsapp\""
        FIRST=0
    fi
fi

# Check cron failures
if is_valid_json "$CRON_JSON"; then
    FAILED_COUNT=$(echo "$CRON_JSON" | jq '[.jobs[] | select(.state.consecutiveErrors > 0)] | length')
    if [ "$FAILED_COUNT" -gt 0 ]; then
        [ "$FIRST" -eq 0 ] && echo ","
        echo "    \"Revisar $FAILED_COUNT trabajos con errores en cron\""
        FIRST=0
    fi
fi

# Check security
if is_valid_json "$SECURITY_JSON"; then
    WARN_COUNT=$(echo "$SECURITY_JSON" | jq -r '.summary.warn // 0')
    if [ "$WARN_COUNT" -gt 0 ]; then
        [ "$FIRST" -eq 0 ] && echo ","
        echo "    \"Ejecutar openclaw security audit --deep para detalles\""
        FIRST=0
    fi
fi

if [ "$FIRST" -eq 1 ]; then
    echo "    \"Sistema operativo - sin acciones pendientes\""
fi
echo "  ],"

# Data quality indicators
echo "  \"data_quality\": {"
echo "    \"dynamic\": [\"system\", \"gateway\", \"agents\", \"sessions\", \"channels\", \"cron\", \"security\"],"
echo "    \"heuristic\": [\"blockers\", \"next_steps\"],"
echo "    \"stub\": [\"recent_results\"]"
echo "  }"
echo "}"
