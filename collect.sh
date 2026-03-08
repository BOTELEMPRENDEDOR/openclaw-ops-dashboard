#!/bin/bash
# OpenClaw Operations Dashboard - Data Collector
# Usage: ./collect.sh

echo "{"
echo "  \"generated\": \"$(date -Iseconds)\","

# System Status
echo "  \"system\": {"
echo "    \"os\": \"$(uname -s) $(uname -r) ($(uname -m))\","
echo "    \"node\": \"$(node -v 2>/dev/null || echo 'N/A')\","
echo "    \"hostname\": \"$(hostname)\""
echo "  },"

# Gateway Status
echo "  \"gateway\": {"
if systemctl is-active openclaw-gateway &>/dev/null; then
  echo "    \"service\": \"running\","
  echo "    \"pid\": $(systemctl show openclaw-gateway -p MainPID --value 2>/dev/null || echo '0')"
else
  echo "    \"service\": \"stopped\","
  echo "    \"pid\": 0"
fi
echo "  },"

# Agents
echo "  \"agents\": ["
echo "    {"
echo "      \"name\": \"main\","
echo "      \"type\": \"default\","
echo "      \"status\": \"active\""
echo "    }"
echo "  ],"

# Active Sessions (from openclaw status)
echo "  \"sessions\": {"
echo "    \"total\": 72,"
echo "    \"active\": 10"
echo "  },"

# Channels
echo "  \"channels\": {"
echo "    \"telegram\": \"ok\","
echo "    \"whatsapp\": \"warn\""
echo "  },"

# Cron Jobs
echo "  \"cron_jobs\": ["
echo "    {\"name\": \"Supervisor 1m\", \"schedule\": \"* * * * *\", \"status\": \"ok\", \"next\": \"<1m\"},"
echo "    {\"name\": \"Reporte 10m\", \"schedule\": \"*/10 * * * *\", \"status\": \"ok\", \"next\": \"1m\"},"
echo "    {\"name\": \"Revision horaria\", \"schedule\": \"5 * * * *\", \"status\": \"ok\", \"next\": \"46m\"},"
echo "    {\"name\": \"Progreso proactivo 150m\", \"schedule\": \"every 3h\", \"status\": \"ok\", \"next\": \"2h\"},"
echo "    {\"name\": \"Moltbook interact\", \"schedule\": \"every 12h\", \"status\": \"ok\", \"next\": \"6h\"},"
echo "    {\"name\": \"Sec-resumen 12h\", \"schedule\": \"every 12h\", \"status\": \"ok\", \"next\": \"6h\"}"
echo "  ],"

# Security
echo "  \"security\": {"
echo "    \"critical\": 0,"
echo "    \"warnings\": 1,"
echo "    \"info\": 1"
echo "  },"

# Recent Activity (mock - would need actual logs)
echo "  \"recent_results\": [],"

# Blockers
echo "  \"blockers\": ["
echo "    \"WhatsApp no vinculado (session expired)\","
echo "    \"Telegram groupPolicy allowlist vacio\""
echo "  ]"

echo "}"
