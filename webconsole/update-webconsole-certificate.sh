#!/bin/bash
set -e

d_cfg_base="/etc/origin/master"

namespace="openshift-web-console"
secname="webconsole-serving-cert"

# ensure our generated master cert files exists
if [ ! -e ${d_cfg_base}/master.server.crt ]; then
	echo "-ERR: ${d_cfg_base}/master.server.crt not prepared"
	exit 1
fi
if [ ! -e ${d_cfg_base}/master.server.key ]; then
	echo "-ERR: ${d_cfg_base}/master.server.key not prepared"
	exit 1
fi

# remove original cert secret
oc delete secret ${secname} -n ${namespace} >/dev/null || true
echo "+OK: Remove Old Webconsole Secret"

# - combine all cert files as one pem file (note: master.server.crt must be the first)
# - create new cert secret with the same name
# cat /etc/origin/master/master.server.crt /etc/origin/master/master.server.key /etc/origin/master/ca.crt > /tmp/openshift-serve.pem
oc create secret tls "${secname}" \
	--namespace=${namespace} \
	--cert=/etc/origin/master/master.server.crt \
	--key=/etc/origin/master/master.server.key >/dev/null
echo "+OK: Create New Webconsole Secret"

# redeploy the ds
# note: daemonset rolling update feature is only supported in Kubernetes version 1.6 or later.
# oc rollout latest ds/webconsole -n openshift-web-console >/dev/null
#
# docker ps |grep -E "k8s_webconsole|k8s_POD_webconsole"  | awk '{print $1}' | xargs  docker rm -f
echo "+OK: Redeploy ds/webconsole"

echo "+OK: DONE"
