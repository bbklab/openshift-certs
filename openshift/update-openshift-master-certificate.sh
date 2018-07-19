#!/bin/bash
set -e

d_backup="/etc/origin/master/backup-certificates/master_$(date +%F_%T)"
d_generated="/etc/openshift-generated-certs/origin/master"

# load utils.sh
source  ../lib/utils.sh

# ensure our generated openshift master cert files exists
files=(
   "master.server.crt"                                  "master.server.crt"
   "master.server.key"                                  "master.server.key"
   "loopback-client/openshift-master.crt"               "openshift-master.crt"
   "loopback-client/openshift-master.key"               "openshift-master.key"
   "loopback-client/openshift-master.kubeconfig"        "openshift-master.kubeconfig"
)
for ((i=0;i<${#files[*]};i++)); do
	if (($i%2==0)); then
		if [ ! -e ${d_generated}/${files[$i]} ]; then
			echo "-ERR: ${d_generated}/${files[$i]} not prepared"
			exit 1
		fi
	fi
done

# backup original openshift master cert files
mkdir -p ${d_backup}  ${d_backup}/loopback-client
for ((i=0;i<${#files[*]};i++)); do
	if (($i%2==1)); then
		file=${files[$i]}
		if [[ $file =~ openshift-master ]]; then
			cp -af /etc/origin/master/${file} ${d_backup}/loopback-client/${file}
		else
			cp -af /etc/origin/master/${file} ${d_backup}/${file}
		fi
	fi
done
echo "+OK: Backup Original Openshift Master & Loopback Client Certificate Files"

# copy our generated cert files
for ((i=0;i<${#files[*]};i++)); do
	if (($i%2==0)); then
		cp -af ${d_generated}/${files[$i]} /etc/origin/master/${files[$(($i+1))]}
	fi
done
echo "+OK: Install New Openshift Master & Loopback Client Certificate Files"

# restart the openshift master
restart_origin_master
echo "+OK: Restart Openshift Master Server"

# clear our generated cert files
rm -rf ${d_generated}

echo "+OK: DONE"
