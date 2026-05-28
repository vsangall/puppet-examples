#!/bin/bash
# Bolt task: check if a service is running

SERVICE="$PT_service"

if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
  echo "{\"status\": \"running\", \"service\": \"${SERVICE}\"}"
else
  echo "{\"status\": \"stopped\", \"service\": \"${SERVICE}\"}"
fi
