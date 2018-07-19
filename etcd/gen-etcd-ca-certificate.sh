#!/bin/bash
#
# this script is responsible for generating etcd ca certificate
#
# requires:
#   - openssl
#
# produces:
#   - /etc/openshift-generated-certs/etcd/ca/ca.crt
#   - /etc/openshift-generated-certs/etcd/ca/ca.key
#   - /etc/openshift-generated-certs/etcd/ca/index.txt
#   - /etc/openshift-generated-certs/etcd/ca/openssl.cnf
#   - /etc/openshift-generated-certs/etcd/ca/serial
#

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
export LANG=en_US

#
# Vars Def
#
d_etcd_cfg_base="/etc/openshift-generated-certs/etcd"
d_etcd_ca="${d_etcd_cfg_base}/ca"

f_etcd_ca_cert="${d_etcd_ca}/ca.crt"
f_etcd_ca_key="${d_etcd_ca}/ca.key"
f_etcd_ca_index="${d_etcd_ca}/index.txt"
f_etcd_ca_serial="${d_etcd_ca}/serial"

d_mutex="/tmp/.openshift_etcd_ca_cert.lock"


#
# Main
#

# load utils.sh
source  ../lib/utils.sh

trap "rm -f .errmsg; rmdir ${d_mutex}" EXIT 2 15

get_mutex_lock ${d_mutex}

if [ -e ${f_etcd_ca_cert} ]; then
	echo "-WARN: etcd ca certificates already generated @ ${f_etcd_ca_cert}, skip"
	exit 0
fi

yum_install_package openssl 5

mkdir -p -m 700 ${d_etcd_ca}/{certs,crl,fragments}
cp -a /etc/pki/tls/openssl.cnf ${d_etcd_ca}/fragments/openssl.cnf
if [ $? -ne 0 ]; then
	echo "-ERR: copy openssl.cnf error"
	exit 1
fi

cp -a ./template/openssl_append.cnf.default ${d_etcd_ca}/fragments/openssl_append.cnf  
if [ $? -ne 0 ]; then
	echo "-ERR: copy ./template/openssl_append.cnf error"
	exit 1
fi

cat ${d_etcd_ca}/fragments/openssl.cnf ${d_etcd_ca}/fragments/openssl_append.cnf > ${d_etcd_ca}/openssl.cnf
if [ $? -ne 0 ]; then
	echo "-ERR: assemble ${d_etcd_ca}/openssl.cnf error"
	exit 1
fi

touch ${f_etcd_ca_index}
echo "01" > ${f_etcd_ca_serial}

env SAN="etcd-signer" openssl req \
	-config ${d_etcd_ca}/openssl.cnf -newkey rsa:4096 \
	-keyout ${f_etcd_ca_key} -new -out ${f_etcd_ca_cert} \
	-x509 -extensions  etcd_v3_ca_self  -batch -nodes \
	-days 1825 \
	-subj /CN=etcd-signer@`date +%s` 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate etcd ca certificate error: $(cat .errmsg)"
	exit 1
fi
echo "+OK: Etcd CA Certificates Created!"

echo "+OK: Result @ ${d_etcd_ca}"
echo "+OK: DONE"
