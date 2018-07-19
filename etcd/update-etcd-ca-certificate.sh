#!/bin/bash
set -e

d_backup="/etc/etcd/backup-certificates/etcd_ca_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/etcd/ca"

# load utils.sh
source  ../lib/utils.sh

# ensure our generated etcd cert files exists
files=(
   "ca.crt"
   "ca.key"
   "serial"
   "index.txt"
   "openssl.cnf"
)
for file in ${files[*]}; do
	if [ ! -e ${d_generated}/${file} ]; then
		echo "-ERR: ${d_generated}/${file} not prepared"
		exit 1
	fi
done

# backup original etcd server cert files
mkdir -p ${d_backup}
for file in ${files[*]}; do
	cp -af /etc/etcd/ca/${file} ${d_backup}/${file}
done
echo "+OK: Backup Original Etcd CA Certificate Files"

# copy our generated etcd server cert files
for file in ${files[*]}; do
	cp -af ${d_generated}/${file} /etc/etcd/ca/${file}
done
# copy to parent directory
cp -af ${d_generated}/ca.crt /etc/etcd/ca.crt
# copy to openshift master directory
cp -af ${d_generated}/ca.crt /etc/origin/master/master.etcd-ca.crt
echo "+OK: Install New Generated Etcd CA Certificate Files"

# note: we can't restart etcd until the etcd server certificates updated
# restart the etcd
# systemctl restart etcd
# echo "+OK: Restart Etcd Server"

# clear our generated etcd server cert files
rm -rf ${d_generated}

echo "+OK: DONE"
echo_yellow "Etcd CA Certificates Updated!\n"
echo_yellow "Pls ReGenerate & Update Etcd Server & Client Certificates Immediately!\n"
echo_yellow "1. regenerate & update etcd server certificates\n"
echo_yellow "2. restart etcd server\n"
echo_yellow "3. regenerate & update etcd client certificates\n"
