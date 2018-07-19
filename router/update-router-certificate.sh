#!/bin/bash
set -e

d_backup="/etc/origin/master/backup-certificates/router_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/router"

# ensure our generated router cert files exists
if [ ! -e ${d_generated}/openshift-router.crt ]; then
	echo "-ERR: ${d_generated}/openshift-router.crt not prepared"
	exit 1
fi
if [ ! -e ${d_generated}/openshift-router.key ]; then
	echo "-ERR: ${d_generated}/openshift-router.key not prepared"
	exit 1
fi

# backup original router cert files
mkdir -p ${d_backup}
cp -af /etc/origin/master/openshift-router.crt ${d_backup}/openshift-router.crt
cp -af /etc/origin/master/openshift-router.key ${d_backup}/openshift-router.key
echo "+OK: Backup Original Router Certificate Files"

# copy our generated router cert files
cp -af ${d_generated}/openshift-router.crt /etc/origin/master/openshift-router.crt
cp -af ${d_generated}/openshift-router.key /etc/origin/master/openshift-router.key
echo "+OK: Install New Generated Router Certificate Files"

# remove original cert secret
secname="router-certs"
oc delete secret ${secname} >/dev/null || true
echo "+OK: Remove Old Router Secret"

# - combine all cert files as one pem file (note: openshift-router.crt must be the first)
# - create new cert secret with the same name
cat /etc/origin/master/openshift-router.crt /etc/origin/master/openshift-router.key /etc/origin/master/ca.crt > /tmp/openshift-router.pem
oc create secret tls "${secname}" \
	--cert=/tmp/openshift-router.pem \
	--key=/etc/origin/master/openshift-router.key >/dev/null
echo "+OK: Create New Router Secret"

# redeploy the dc
oc rollout latest dc/router -n default >/dev/null
echo "+OK: Redeploy dc/router"

# clear our generated router cert files
rm -f ${d_generated}/openshift-router.crt
rm -f ${d_generated}/openshift-router.key
rmdir ${d_generated}

echo "+OK: DONE"
