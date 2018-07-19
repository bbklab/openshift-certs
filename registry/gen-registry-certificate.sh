#!/bin/bash
#
# this script is responsible for generating registry certificate
#
# requires:
#   - /etc/origin/master/ca.crt
#
# produces: 
#   - /etc/openshift-generated-certs/registry/registry.crt
#   - /etc/openshift-generated-certs/registry/registry.key
#
# note: the produced cert files will be used by k8s_registry_docker-registry

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
export LANG=en_US

#
# Vars Def
#
d_origin_cfg_base="/etc/origin"
d_master_cfg_base="${d_origin_cfg_base}/master"
f_master_ca_cert="${d_master_cfg_base}/ca.crt"
f_master_ca_key="${d_master_cfg_base}/ca.key"
f_master_ca_serial="${d_master_cfg_base}/ca.serial.txt"

d_generated_registry_cfg_base="/etc/openshift-generated-certs/registry"
f_generated_registry_cert="${d_generated_registry_cfg_base}/registry.crt"
f_generated_registry_key="${d_generated_registry_cfg_base}/registry.key"

d_mutex="/tmp/.openshift_registry_cert.lock"

#
# Main
#

# load utils.sh
source  ../lib/utils.sh

trap "rm -f .errmsg; rmdir ${d_mutex}" EXIT 2 15

get_mutex_lock ${d_mutex}

# Ensure CA certificate exists on openshift_ca_host
if [ ! -e "$f_master_ca_cert" ]; then
    echo "-ERR: CA certificate $f_master_ca_cert doesn't exist on Openshift CA host"
    exit 1
fi

# Set argument hostnames
hostnames="docker-registry.default.svc,docker-registry.default.svc.cluster.local"

regclusterip=$( ( oc get service docker-registry -n default -o json | jq ".spec.clusterIP" | tr -d '"' ) 2>/dev/null )
if [ -z "$regclusterip" ]; then
	echo "-ERR: oc get service docker-registry .spec.clusterIP error"
	exit 1
fi
hostnames="${hostnames},${regclusterip}"

reghost=$( ( oc get route docker-registry -n default -o json | jq ".spec.host" | tr -d '"' ) 2>/dev/null )
if [ -z "$reghost" ]; then
	echo "-ERR: oc get route docker-registry .spec.host error"
	exit 1
fi
hostnames="${hostnames},${reghost}"
echo "+OK: Using parameter hostnames = ${hostnames}"

# Create registry certs
mkdir -p -m 700 ${d_generated_registry_cfg_base}
oc adm ca create-server-cert \
	--signer-cert ${f_master_ca_cert} \
	--signer-key ${f_master_ca_key} \
	--signer-serial ${f_master_ca_serial} \
	--cert ${f_generated_registry_cert} \
	--key ${f_generated_registry_key} \
	--expire-days 730 \
	--hostnames "${hostnames}"  2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate registry certificate error: $(cat .errmsg)"
	exit 1
fi
echo "+OK: Registry Certificate Created!"

echo "+OK: Result @ ${d_generated_registry_cfg_base}"
echo "+OK: DONE"
