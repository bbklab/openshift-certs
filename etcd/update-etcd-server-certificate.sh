#!/bin/bash
set -e

d_backup="/etc/etcd/backup-certificates/etcd_server_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/etcd/server"

# ensure our generated etcd cert files exists
files=(
   "peer.crt"
   "peer.csr"
   "peer.key"
   "server.crt"
   "server.csr"
   "server.key"
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
	cp -af /etc/etcd/${file} ${d_backup}/${file}
done
echo "+OK: Backup Original Etcd Server Certificate Files"

# copy our generated etcd server cert files
for file in ${files[*]}; do
	cp -af ${d_generated}/${file} /etc/etcd/${file}
done
echo "+OK: Install New Generated Etcd Server Certificate Files"

# restart the etcd
systemctl restart etcd
echo "+OK: Restart Etcd Server"

# clear our generated etcd server cert files
rm -rf ${d_generated}

echo "+OK: DONE"
