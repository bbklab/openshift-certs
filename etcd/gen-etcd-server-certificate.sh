#!/bin/bash
#
# this script is responsible for generating etcd server & peer certificate
#
# requires:
#   - etcd (indeed not required)
#   - /etc/etcd/ca/openssl.cnf
#   - /etc/etcd/ca/ca.crt
#
# produces:
#   - /etc/openshift-generated-certs/etcd/peer.crt 
#   - /etc/openshift-generated-certs/etcd/peer.key
#   - /etc/openshift-generated-certs/etcd/peer.csr (no use)
#   - /etc/openshift-generated-certs/etcd/server.crt
#   - /etc/openshift-generated-certs/etcd/server.key
#   - /etc/openshift-generated-certs/etcd/server.csr (no use)
#   - /etc/openshift-generated-certs/etcd/ca.crt  (indeed clone of /etc/etcd/ca/ca.crt)
#
# note: the produced cert files will be used by etcd server
# /etc/etcd/etcd.conf
# ETCD_TRUSTED_CA_FILE=/etc/etcd/ca.crt
# ETCD_CLIENT_CERT_AUTH=true
# ETCD_CERT_FILE=/etc/etcd/server.crt
# ETCD_KEY_FILE=/etc/etcd/server.key
# ETCD_PEER_TRUSTED_CA_FILE=/etc/etcd/ca.crt
# ETCD_PEER_CLIENT_CERT_AUTH=true
# ETCD_PEER_CERT_FILE=/etc/etcd/peer.crt
# ETCD_PEER_KEY_FILE=/etc/etcd/peer.key

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
export LANG=en_US

#
# Vars Def
#
d_etcd_cfg_base="/etc/etcd"
d_etcd_ca="${d_etcd_cfg_base}/ca"
f_etcd_ca_cert="${d_etcd_ca}/ca.crt"
f_ca_openssl_conf="${d_etcd_ca}/openssl.cnf"

d_generated_etcd_cfg_base="/etc/openshift-generated-certs/etcd/server"
f_generated_etcd_server_cert="${d_generated_etcd_cfg_base}/server.crt"
f_generated_etcd_server_key="${d_generated_etcd_cfg_base}/server.key"
f_generated_etcd_server_csr="${d_generated_etcd_cfg_base}/server.csr"
f_generated_etcd_peer_cert="${d_generated_etcd_cfg_base}/peer.crt"
f_generated_etcd_peer_key="${d_generated_etcd_cfg_base}/peer.key"
f_generated_etcd_peer_csr="${d_generated_etcd_cfg_base}/peer.csr"
_f_generated_etcd_ca_cert="${d_generated_etcd_cfg_base}/ca.crt" # clone of ${f_etcd_ca_cert} but in different directory

d_mutex="/tmp/.openshift_etcd_server_cert.lock"


#
# Main
#

# load utils.sh
source  ../lib/utils.sh

trap "rm -f .errmsg; rmdir ${d_mutex}" EXIT 2 15

get_mutex_lock ${d_mutex}

mkdir -p -m 700 ${d_generated_etcd_cfg_base}

# Ensure CA certificate exists on etcd_ca_host
if [ ! -e "${f_etcd_ca_cert}" ]; then
    echo "-ERR: CA certificate ${f_etcd_ca_cert} doesn't exist on etcd CA host"
    exit 1
fi

# Set Arguments etcd_hostname & etcd_ip
etcd_hostname=$1
etcd_ip=$2
# set default
if [ -z "${etcd_hostname}" ]; then
	etcd_hostname=$(hostname 2>&-)
fi
if [ -z "${etcd_ip}" ]; then
	etcd_ip=$(get_local_physical_ips | awk -F"," '{print $1}') # note: we only pick up the first physical ip address
fi
# if still empty,  ask for from user 
if [ -z "${etcd_hostname}" ]; then
	echo "-ERR: etcd_hostname parameter required"
	exit 1
fi
if [ -z "${etcd_ip}" ]; then
	echo "-ERR: etcd_ip parameter required"
	exit 1
fi

echo "+OK: Using parameter etcd_hostname = ${etcd_hostname}"
echo "+OK: Using parameter etcd_ip = ${etcd_ip}"

yum_install_package etcd 5

# Create the server csr and sign it
env SAN="IP:${etcd_ip},DNS:${etcd_hostname}" openssl req \
	-new -keyout ${f_generated_etcd_server_key} \
	-config ${f_ca_openssl_conf} \
	-out ${f_generated_etcd_server_csr} \
	-reqexts etcd_v3_req -batch -nodes \
	-subj /CN=${etcd_hostname} 2>.errmsg 
if [ $? -ne 0 ]; then
	echo "-ERR: generate etcd server key & csr error: $(cat .errmsg)"
	exit 1
fi
env SAN="IP:${etcd_ip}" openssl ca \
	-name etcd_ca \
	-config ${f_ca_openssl_conf} \
	-out ${f_generated_etcd_server_cert} \
	-in ${f_generated_etcd_server_csr} \
	-extensions etcd_v3_ca_server  -batch 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: sign etcd server crt error: $(cat .errmsg)"
	exit 1
fi
echo "+OK: Etcd Server Certificates Created!"

# Create the peer csr and sign it
env SAN="IP:${etcd_ip},DNS:${etcd_hostname}" openssl req \
	-new -keyout ${f_generated_etcd_peer_key} \
	-config ${f_ca_openssl_conf} \
	-out ${f_generated_etcd_peer_csr} \
	-reqexts etcd_v3_req -batch -nodes \
	-subj /CN=${etcd_hostname} 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: generate etcd peer key & csr error: $(cat .errmsg)"
	exit 1
fi
env SAN="IP:${etcd_ip}" openssl ca \
	-name etcd_ca \
	-config ${f_ca_openssl_conf} \
	-out ${f_generated_etcd_peer_cert} \
	-in ${f_generated_etcd_peer_csr} \
	-extensions etcd_v3_ca_peer  -batch 2>.errmsg
if [ $? -ne 0 ]; then
	echo "-ERR: sign etcd peer crt error: $(cat .errmsg)"
	exit 1
fi
echo "+OK: Etcd Peer Certificates Created!"

# Copy the ca/ca.crt to parent directory
cp -a ${f_etcd_ca_cert} ${_f_generated_etcd_ca_cert}
if [ $? -ne 0 ]; then
	echo "-ERR: copy etcd ca crt error"
	exit 1
fi
echo "+OK: Etcd CA Certificate Copied!"

echo "+OK: Result @ ${d_generated_etcd_cfg_base}"
echo "+OK: DONE"
