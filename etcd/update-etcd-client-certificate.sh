#!/bin/bash
set -e

d_backup="/etc/origin/master/backup-certificates/etcd_client_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/etcd/client"

# load utils.sh
source  ../lib/utils.sh

# ensure our generated etcd cert files exists
files=(
   "ca.crt"           "master.etcd-ca.crt"
   "client.crt"       "master.etcd-client.crt"
   "client.csr"       "master.etcd-client.csr"
   "client.key"       "master.etcd-client.key"
)
for file in ${files[*]}; do
	if [[ $file =~ master.etcd ]]; then
		continue
	fi
	if [ ! -e ${d_generated}/${file} ]; then
		echo "-ERR: ${d_generated}/${file} not prepared"
		exit 1
	fi
done

# backup original etcd server cert files
mkdir -p ${d_backup}
for file in ${files[*]}; do
	if [[ $file =~ master.etcd ]]; then
		cp -af /etc/origin/master/${file} ${d_backup}/${file}
	fi
done
echo "+OK: Backup Original Etcd Server Certificate Files"

# copy our generated etcd server cert files
for ((i=0;i<${#files[*]};i++)); do
	if (($i%2==0)); then
		cp -af ${d_generated}/${files[$i]} /etc/origin/master/${files[$(($i+1))]}
	fi
done
echo "+OK: Install New Generated Etcd Server Certificate Files"

# restart the openshift master
restart_origin_master
echo "+OK: Restart Openshift Master Server"

# clear our generated etcd client cert files
rm -rf ${d_generated}

echo "+OK: DONE"
