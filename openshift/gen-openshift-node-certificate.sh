#!/bin/bash
#
# this script is responsible for generating openshift master ca certificate
#
# Example:
#   ./gen-openshift-node-certificate.sh  node232.dmos.dataman https://master231.dmos.dataman:8443
#
# requires:
#   - /etc/origin/master/ca.crt
#
# produces:
#   - /etc/openshift-generated-certs/origin/node/
#   - /etc/openshift-generated-certs/origin/node/

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

d_generated_origin_cfg_base="/etc/openshift-generated-certs/origin"
d_generated_node_cfg_base="${d_generated_origin_cfg_base}/node"

d_mutex="/tmp/.openshift_origin_node_cert.lock"

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
node_hostnames=$1
if [ -z "${node_hostnames}" ]; then
    echo "-ERR: require node_hostnames argument for node cert, eg: node232.dmos.dataman"
    exit 1
fi

master_api_url=$2
if [ -z "${master_api_url}" ]; then
    echo "-ERR: require master_api_url argument for master cert, eg: https://master231.dmos.dataman:8443"
    exit 1
fi

echo "+OK: Using parameter node_hostnames = ${node_hostnames}"
echo "+OK: Using parameter master_api_url = ${master_api_url}"

mkdir -p -m 700 ${d_generated_node_cfg_base}
mkdir -p -m 700 ${d_generated_node_cfg_base}/${node_hostnames}

# create node client config
oc adm create-api-client-config \
    --certificate-authority=${f_master_ca_cert} \
    --client-dir=${d_generated_node_cfg_base}/${node_hostnames} \
    --groups=system:nodes \
    --master=${master_api_url} \
    --signer-cert=${f_master_ca_cert} \
    --signer-key=${f_master_ca_key} \
    --signer-serial=${f_master_ca_serial} \
    --user=system:node:${node_hostnames} \
    --expire-days=730 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate origin node client configs error: $(cat .errmsg)"
	exit 1
fi

echo "+OK: Origin Node Client Configs Created!"

# create node certificate
oc adm ca create-server-cert \
    --cert=${d_generated_node_cfg_base}/${node_hostnames}/server.crt \
    --key=${d_generated_node_cfg_base}/${node_hostnames}/server.key \
    --expire-days=730 \
    --overwrite=true \
    --hostnames=${node_hostnames} \
    --signer-cert=${f_master_ca_cert} \
    --signer-key=${f_master_ca_key} \
    --signer-serial=${f_master_ca_serial} 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate origin node certificates error: $(cat .errmsg)"
	exit 1
fi

echo "+OK: Origin Node Certificates Created!"

echo "+OK: Result @ ${d_generated_node_cfg_base}/${node_hostnames}"
echo "+OK: DONE"
echo_yellow "Pls Update Origin Node Certificates & Configs Immediately!\n"
echo_yellow "1. remote copy the node certificates: scp ${d_generated_node_cfg_base}/${node_hostnames}/* root@${node_hostnames}:/etc/origin/node/\n"
echo_yellow "2. restart the node service: systemctl restart origin-node\n"
