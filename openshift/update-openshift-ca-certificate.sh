#!/bin/bash
set -e

d_backup="/etc/origin/master/backup-certificates/ca_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/origin/ca"

# load utils.sh
source  ../lib/utils.sh

# ensure our generated openshift ca cert files exists
files=(
  "admin.crt"
  "admin.key"
  "admin.kubeconfig"
  "ca-bundle.crt"
  "ca.crt"  
  "ca.key"
  "ca.serial.txt"
  "client-ca-bundle.crt"
  "etcd.server.crt"
  "etcd.server.key"
  "frontproxy-ca.crt"
  "frontproxy-ca.key"
  "frontproxy-ca.serial.txt"
  "master.kubelet-client.crt"
  "master.kubelet-client.key"
  "master.proxy-client.crt"
  "master.proxy-client.key"
  "openshift-aggregator.crt"
  "openshift-aggregator.key"
  "service-signer.crt"
  "service-signer.key"
)
for file in ${files[*]}; do
	if [ ! -e ${d_generated}/${file} ]; then
		echo "-ERR: ${d_generated}/${file} not prepared"
		exit 1
	fi
done

# backup original openshift ca cert files
mkdir -p ${d_backup}
for file in ${files[*]}; do
	cp -af /etc/origin/master/${file} ${d_backup}/${file}
done
echo "+OK: Backup Original Openshift CA & Other Certificate Files"

# copy our generated cert files
for file in ${files[*]}; do
	cp -af ${d_generated}/${file} /etc/origin/master/${file}
done
echo "+OK: Install New Openshift CA & Other Certificate Files"

# update ~/.kube/config, so the `oc` work correctly
cp -af /etc/origin/master/admin.kubeconfig /root/.kube/config
chmod 0700 /root/.kube/config
echo "+OK: Update Openshift Client Config CA"

# update system CA trust 
cp -af /etc/origin/master/ca.crt  /etc/pki/ca-trust/source/anchors/openshift-ca.crt
echo "+OK: Update System CA Trust"

# note: we can't restart origin-master until the master certificates updated
#
# restart_origin_master
# echo "+OK: Restart Openshift Master Server"

# clear our generated cert files
rm -rf ${d_generated}

echo "+OK: DONE"
echo_yellow "Openshift CA Certificates Updated!\n"
echo_yellow "Pls ReGenerate & Update Other Certificates Immediately!\n"
