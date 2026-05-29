#!/bin/bash
set -e

PUPPET_REPO="/puppet-repo"
PUPPET_ENV="/etc/puppetlabs/code/environments/production"

echo "=== Installing Puppet 8 ==="
if ! command -v puppet &>/dev/null; then
  wget -O /tmp/puppet8-release-noble.deb https://apt.puppet.com/puppet8-release-noble.deb
  dpkg -i /tmp/puppet8-release-noble.deb
  rm -f /tmp/puppet8-release-noble.deb
  DEBIAN_FRONTEND=noninteractive apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y puppet-agent
fi

export PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:${PATH}"

echo "=== Installing required Puppet modules ==="
puppet module install puppetlabs-stdlib --version 9.7.0 || true
puppet module install puppetlabs-concat --version 9.0.2 || true
puppet module install puppetlabs-firewall --version 8.1.3 || true
puppet module install puppetlabs-vcsrepo --version 6.1.0 || true
puppet module install puppet-redis --version 11.0.0 || true

echo "=== Setting up Puppet environment ==="
mkdir -p "${PUPPET_ENV}/modules" "${PUPPET_ENV}/manifests" "${PUPPET_ENV}/data"

# Copy all modules from repo (including stub for puppetdb_query)
for module in profile_haproxy profile_app_stack profile_redis_cluster puppetdb_query_stub; do
  rm -rf "${PUPPET_ENV}/modules/${module}"
  cp -r "${PUPPET_REPO}/modules/${module}" "${PUPPET_ENV}/modules/${module}"
done

# Copy test manifest and hiera config
cp "${PUPPET_REPO}/test/site.pp" "${PUPPET_ENV}/manifests/site.pp"
cp "${PUPPET_REPO}/test/hiera.yaml" /etc/puppetlabs/puppet/hiera.yaml
cp -r "${PUPPET_REPO}/test/data/"* "${PUPPET_ENV}/data/"

echo "=== Applying Puppet manifest ==="
set +e
puppet apply \
  --modulepath="${PUPPET_ENV}/modules" \
  --hiera_config="/etc/puppetlabs/puppet/hiera.yaml" \
  "${PUPPET_ENV}/manifests/site.pp" \
  --detailed-exitcodes
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "Puppet applied successfully (no changes needed)"
elif [ $EXIT_CODE -eq 2 ]; then
  echo "Puppet applied successfully (changes made)"
else
  echo "Puppet apply FAILED (exit code ${EXIT_CODE})"
  exit 1
fi

echo ""
echo "=== Verifying services ==="
echo "--- HAProxy ---"
haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/conf.d/
systemctl status haproxy --no-pager || true
echo ""
echo "--- Redis ---"
systemctl status redis-server --no-pager || true
echo ""
echo "=== Provisioning complete ==="
