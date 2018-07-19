#!/bin/bash
#
# this script is responsible for generating openshift master ca certificate
# See: 
#   - openshift-ansible/playbooks/openshift-master/private/redeploy-certificates.yml
#   - openshift-ansible/playbooks/openshift-master/private/roles/openshift_master_certificates
#
# Example:
#   ./gen-openshift-master-certificate.sh  master231.dmos.dataman  https://master231.dmos.dataman:8443
#
# requires:
#   - /etc/origin/master/ca.crt  (or given CA dir)
#
# produces:
#   - /etc/openshift-generated-certs/origin/master/master.server.crt
#   - /etc/openshift-generated-certs/origin/master/master.server.key
#   - /etc/openshift-generated-certs/origin/master/loopback-client/openshift-master.crt
#   - /etc/openshift-generated-certs/origin/master/loopback-client/openshift-master.key
#   - /etc/openshift-generated-certs/origin/master/loopback-client/openshift-master.kubeconfig
#
# note: the produced `master.server.crt` and `master.server.key` cert files will be used by section `servingInfo`

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
export LANG=en_US

#
# Vars Def
#
d_origin_cfg_base="/etc/origin"
d_master_cfg_base="${d_origin_cfg_base}/master"   # use default system ca dir or use given ca dir
if [ ! -z "${USE_CA_BASE_DIR}" ]; then
	d_master_cfg_base="${USE_CA_BASE_DIR}"
fi
f_master_ca_cert="${d_master_cfg_base}/ca.crt"
f_master_ca_key="${d_master_cfg_base}/ca.key"
f_master_ca_serial="${d_master_cfg_base}/ca.serial.txt"

d_generated_origin_cfg_base="/etc/openshift-generated-certs/origin"
d_generated_master_cfg_base="${d_generated_origin_cfg_base}/master"
f_generated_master_server_cert="${d_generated_master_cfg_base}/master.server.crt"
f_generated_master_server_key="${d_generated_master_cfg_base}/master.server.key"

d_generated_loopback_client_cfg_base="${d_generated_master_cfg_base}/loopback-client"

d_mutex="/tmp/.openshift_origin_master_cert.lock"

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
openshift_hostnames=$1
if [ -z "${openshift_hostnames}" ]; then
    echo "-ERR: require hostnames argument for master cert, eg: dmos.dataman,192.168.1.231"
    echo "-ERR: better to keep same as master-config.yaml"
    exit 1
fi
k8sclusterip=$( ( oc get service kubernetes -n default -o json | jq ".spec.clusterIP" | tr -d '"' ) 2>/dev/null )
if [ -z "$k8sclusterip" ]; then
    echo "-ERR: oc get service kubernetes .spec.clusterIP error"
    exit 1
fi
openshift_hostnames="${openshift_hostnames},${k8sclusterip}"                    # with k8s server cluster ip
openshift_hostnames="${openshift_hostnames},$(hostname 2>&-)"  			# with hostnames
openshift_hostnames="${openshift_hostnames},$(get_local_physical_ips 2>&-)"  	# with local ips
openshift_hostnames="${openshift_hostnames},kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local"
openshift_hostnames="${openshift_hostnames},openshift,openshift.default,openshift.default.svc,openshift.default.svc.cluster.local"

loopback_api_url=$2
if [ -z "${loopback_api_url}" ]; then
    echo "-ERR: require loopback_api_url argument for master cert, eg: https://192.168.1.231:8443"
    echo "-ERR: better to keep same as master-config.yaml"
    exit 1
fi

echo "+OK: Using parameter openshift_hostnames= ${openshift_hostnames}"
echo "+OK: Using parameter loopback_api_url = ${loopback_api_url}"

mkdir -p -m 700 ${d_generated_master_cfg_base}

# create openshift master cert
oc adm ca create-server-cert \
	--hostnames=${openshift_hostnames}  \
	--cert=${f_generated_master_server_cert} \
	--key=${f_generated_master_server_key} \
	--signer-cert=${f_master_ca_cert} \
	--signer-key=${f_master_ca_key} \
	--signer-serial=${f_master_ca_serial} \
	--expire-days=730 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate origin master certificate error: $(cat .errmsg)"
	exit 1
fi

echo "+OK: Origin Master Certificates Created!"

# create loopback master client config
mkdir -p -m 700 ${d_generated_loopback_client_cfg_base}
oc adm create-api-client-config \
       --certificate-authority=${f_master_ca_cert} \
       --client-dir=${d_generated_loopback_client_cfg_base} \
       --groups=system:masters,system:openshift-master \
       --master=${loopback_api_url} \
       --public-master=${loopback_api_url} \
       --signer-cert=${f_master_ca_cert} \
       --signer-key=${f_master_ca_key} \
       --signer-serial=${f_master_ca_serial} \
       --user=system:openshift-master \
       --basename=openshift-master \
       --expire-days=730 2>.errmsg
if [ $? -ne 0 ]; then
       echo "-ERR: generate origin api loopback client config error: $(cat .errmsg)"
       exit 1
fi
rm -f ${d_generated_loopback_client_cfg_base}/ca.crt    # remove unused ca.crt

echo "+OK: Origin Loopback Master Client Certificates Created!"

echo "+OK: Result @ ${d_generated_master_cfg_base}"
echo "+OK: DONE"
