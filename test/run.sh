#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Building Puppet test container ==="
podman build -t puppet-haproxy-test -f "$SCRIPT_DIR/Containerfile" "$REPO_DIR"

echo "=== Starting container (systemd init) ==="
podman rm -f puppet-test 2>/dev/null || true
podman run -d --name puppet-test --privileged puppet-haproxy-test

# Wait for systemd to initialize
sleep 3

echo "=== Applying Puppet manifest ==="
set +e
podman exec puppet-test puppet apply \
  --modulepath=/etc/puppetlabs/code/environments/production/modules \
  /etc/puppetlabs/code/environments/production/manifests/site.pp \
  --detailed-exitcodes
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "Puppet applied successfully (no changes needed)"
elif [ $EXIT_CODE -eq 2 ]; then
  echo "Puppet applied successfully (changes made)"
else
  echo "Puppet apply FAILED (exit code $EXIT_CODE)"
  exit 1
fi

echo ""
echo "=== Verifying HAProxy ==="

echo ""
echo "--- Config validation (main + conf.d) ---"
podman exec puppet-test haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/conf.d/

echo ""
echo "--- /etc/haproxy/haproxy.cfg ---"
podman exec puppet-test cat /etc/haproxy/haproxy.cfg

echo ""
echo "--- Backend fragments ---"
podman exec puppet-test ls -la /etc/haproxy/conf.d/

echo ""
echo "--- /etc/haproxy/conf.d/webservers.cfg ---"
podman exec puppet-test cat /etc/haproxy/conf.d/webservers.cfg

echo ""
echo "--- /etc/haproxy/conf.d/api.cfg ---"
podman exec puppet-test cat /etc/haproxy/conf.d/api.cfg

echo ""
echo "--- Error pages ---"
podman exec puppet-test ls -la /etc/haproxy/errors/
podman exec puppet-test cat /etc/haproxy/errors/503.http

echo ""
echo "--- Logrotate ---"
podman exec puppet-test cat /etc/logrotate.d/haproxy

echo ""
echo "--- HAProxy user/group ---"
podman exec puppet-test id haproxy

echo ""
echo "--- /var/lib/haproxy permissions ---"
podman exec puppet-test ls -ld /var/lib/haproxy

echo ""
echo "--- HAProxy service status ---"
podman exec puppet-test systemctl status haproxy --no-pager || true

echo ""
echo "========================================="
echo "=== Puppet apply PASSED ==="
echo "========================================="
echo ""
echo "Container 'puppet-test' is running with systemd. Use:"
echo "  podman exec -it puppet-test bash"
echo "  podman rm -f puppet-test"
