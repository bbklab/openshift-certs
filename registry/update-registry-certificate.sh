#!/bin/bash
set -e

d_backup="/etc/origin/master/backup-certificates/registry_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/registry"

# ensure our generated registry cert files exists
if [ ! -e ${d_generated}/registry.crt ]; then
	echo "-ERR: ${d_generated}/registry.crt not prepared"
	exit 1
fi
if [ ! -e ${d_generated}/registry.key ]; then
	echo "-ERR: ${d_generated}/registry.key not prepared"
	exit 1
fi

# backup original registry cert files
mkdir -p ${d_backup}
cp -af /etc/origin/master/registry.crt  ${d_backup}/registry.crt
cp -af /etc/origin/master/registry.key  ${d_backup}/registry.key
echo "+OK: Backup Original Registry Certificate Files"

# copy our generated registry cert files
cp -af ${d_generated}/registry.crt /etc/origin/master/registry.crt
cp -af ${d_generated}/registry.key /etc/origin/master/registry.key
echo "+OK: Install New Generated Registry Certificate Files"

# remove original cert secret
secname="registry-certificates"
oc delete secret ${secname} >/dev/null || true
echo "+OK: Remove Old Registry Secret"

# - combine all cert files as one pem file (note: registry.crt must be the first)
# - create new cert secret with the same name
cat /etc/origin/master/registry.crt /etc/origin/master/registry.key /etc/origin/master/ca.crt > /tmp/openshift-registry.pem
oc create secret generic "${secname}" \
	--from-file=registry.crt=/tmp/openshift-registry.pem \
	--from-file=registry.key=/etc/origin/master/registry.key >/dev/null
echo "+OK: Create New Registry Secret"

# redeploy the dc
oc rollout latest dc/docker-registry -n default >/dev/null
echo "+OK: Redeploy dc/docker-registry"

# clear our generated registry cert files
rm -f ${d_generated}/registry.crt
rm -f ${d_generated}/registry.key
rmdir ${d_generated}

echo "+OK: DONE"
