#!/bin/bash
#
# this script is responsible for generating openshift master ca certificate
# See: 
#   - openshift-ansible/playbooks/openshift-master/private/redeploy-openshift-ca.yml
#   - openshift-ansible/playbooks/openshift-master/private/roles/openshift_ca
#
# Example:
#   ./gen-openshift-ca-certificate.sh  master231.dmos.dataman  https://master231.dmos.dataman:8443  https://master231.dmos.dataman:8443
#
# requires:
#   - origin
#
# produces:
#   - /etc/openshift-generated-certs/origin/ca/ca.crt
#   - /etc/openshift-generated-certs/origin/ca/ca.key
#   - /etc/openshift-generated-certs/origin/ca/ca.serial.txt
#   - /etc/openshift-generated-certs/origin/ca/ca-bundle.crt   		(actually clone of ca.crt)
#   - /etc/openshift-generated-certs/origin/ca/client-ca-bundle.crt	(actually clone of ca.crt)
#   - admin.crt
#   - admin.key
#   - admin.kubeconfig
#   - etcd.server.crt          (no use)
#   - etcd.server.key          (no use)
#   - frontproxy-ca.crt        (no use)
#   - frontproxy-ca.key        (no use)
#   - frontproxy-ca.serial.txt (no use)
#   - master.kubelet-client.crt
#   - master.kubelet-client.key
#   - master.proxy-client.crt
#   - master.proxy-client.key
#   - openshift-aggregator.crt
#   - openshift-aggregator.key
#   - service-signer.crt
#   - service-signer.key


export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
export LANG=en_US

#
# Vars Def
#
d_generated_origin_cfg_base="/etc/openshift-generated-certs/origin"
d_generated_master_cfg_base="${d_generated_origin_cfg_base}/ca"
f_generated_master_ca_cert="${d_generated_master_cfg_base}/ca.crt"
f_generated_master_ca_key="${d_generated_master_cfg_base}/ca.key"
f_generated_master_ca_serial="${d_generated_master_cfg_base}/ca.serial.txt"
f_generated_master_ca_bundle_crt="${d_generated_master_cfg_base}/ca-bundle.crt"
f_generated_master_client_ca_bundle_crt="${d_generated_master_cfg_base}/client-ca-bundle.crt"

d_mutex="/tmp/.openshift_origin_ca_cert.lock"

#
# Main
#

# load utils.sh
source  ../lib/utils.sh

trap "rm -f .errmsg; rmdir ${d_mutex}" EXIT 2 15

get_mutex_lock ${d_mutex}

if [ -e ${f_generated_master_ca_cert} ]; then
        echo "-WARN: openshift origin ca certificates already generated @ ${f_generated_master_ca_cert}, skip"
        exit 0
fi

yum_install_package origin 5

# Obtain Arguments
openshift_hostnames=$1
if [ -z "${openshift_hostnames}" ]; then
    echo "-ERR: require hostnames argument for ca cert, eg: master231.dmos.dataman,192.168.1.231"
    echo "-ERR: better to keep same as master-config.yaml"
    exit 1
fi
openshift_hostnames="${openshift_hostnames},$(hostname 2>&-)"  			# with hostnames
openshift_hostnames="${openshift_hostnames},$(get_local_physical_ips 2>&-)"  	# with local ips
openshift_hostnames="${openshift_hostnames},kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local"
openshift_hostnames="${openshift_hostnames},openshift,openshift.default,openshift.default.svc,openshift.default.svc.cluster.local"

openshift_master_url=$2
if [ -z "${openshift_master_url}" ]; then
    echo "-ERR: require master_url argument for ca cert, eg: https://internal.master.fqdn:8443"
    echo "-ERR: better to keep same as master-config.yaml"
    exit 1
fi

openshift_master_public_url=$3
if [ -z "${openshift_master_public_url}" ]; then
    echo "-ERR: require master_public_url argument for ca cert, eg: https://external.master.fqdn:8443"
    echo "-ERR: better to keep same as master-config.yaml"
    exit 1
fi

echo "+OK: Using parameter openshift_hostnames = ${openshift_hostnames}"
echo "+OK: Using parameter openshift_master_url = ${openshift_master_url}"
echo "+OK: Using parameter openshift_master_public_url = ${openshift_master_public_url}"

mkdir -p -m 700 ${d_generated_master_cfg_base}

echo "00" > ${f_generated_master_ca_serial}

# create openshift ca cert
oc adm ca create-master-certs \
	--hostnames=${openshift_hostnames}  \
	--master=${openshift_master_url} \
	--public-master=${openshift_master_public_url} \
	--cert-dir=${d_generated_master_cfg_base} \
	--expire-days=730 \
	--signer-expire-days=1825 \
	--signer-name=openshift-signer@`date +%s` \
	--overwrite=false 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate origin ca certificate error: $(cat .errmsg)"
	exit 1
fi

# note: the 2 rsa key pair files in using must keep unchanged if previous already exists 
# so we remove these 2 generated files
rm -f ${d_generated_master_cfg_base}/serviceaccounts.public.key
rm -f ${d_generated_master_cfg_base}/serviceaccounts.private.key

# note: the 5 files will be re-generated and replaced by `gen-openshift-master-certificate.sh`
rm -f ${d_generated_master_cfg_base}/master.server.crt
rm -f ${d_generated_master_cfg_base}/master.server.key
rm -f ${d_generated_master_cfg_base}/openshift-master.crt
rm -f ${d_generated_master_cfg_base}/openshift-master.key
rm -f ${d_generated_master_cfg_base}/openshift-master.kubeconfig

# note: the 2 files should be replaced by `gen-etcd-client-certificate.sh` instead of here
rm -f ${d_generated_master_cfg_base}/master.etcd-client.crt
rm -f ${d_generated_master_cfg_base}/master.etcd-client.key

# copy client-ca-bundle.crt
cp -a ${f_generated_master_ca_bundle_crt} ${f_generated_master_client_ca_bundle_crt}
if [ $? -ne 0 ]; then
	echo "-ERR: clone client-ca-bundle.crt error"
	exit 1
fi

echo "+OK: Origin CA Certificates Created!"

echo "+OK: Result @ ${d_generated_master_cfg_base}"
echo "+OK: DONE"
