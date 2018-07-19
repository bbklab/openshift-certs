#!/bin/bash
#
# this script is responsible for generating router certificate
#
# requires:
#   - /etc/origin/master/ca.crt
#
# produces: 
#   - /etc/openshift-generated-certs/router/openshift-router.crt
#   - /etc/openshift-generated-certs/router/openshift-router.key
#
# note: the produced cert files will be used by k8s_router_router

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

d_generated_router_cfg_base="/etc/openshift-generated-certs/router"
f_generated_router_cert="${d_generated_router_cfg_base}/openshift-router.crt"
f_generated_router_key="${d_generated_router_cfg_base}/openshift-router.key"

d_mutex="/tmp/.openshift_router_cert.lock"


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

# Obtain Arguments
domain=$1
if [ -z "${domain}" ]; then
    echo "-ERR: require base domain argument, eg: dmos.dataman"
    exit 1
fi

hostnames="${domain},*.${domain}"
echo "+OK: Using parameter wildchars hostnames = ${hostnames}"

# Create router certs
mkdir -p -m 700 ${d_generated_router_cfg_base}
oc adm ca create-server-cert \
	--signer-cert ${f_master_ca_cert} \
	--signer-key ${f_master_ca_key} \
	--signer-serial ${f_master_ca_serial} \
	--cert ${f_generated_router_cert} \
	--key ${f_generated_router_key} \
	--expire-days 730 \
	--hostnames "${hostnames}"  2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate router certificate error: $(cat .errmsg)"
	exit 1
fi
echo "+OK: Router Certificate Created!"

echo "+OK: Result @ ${d_generated_router_cfg_base}"
echo "+OK: DONE"
