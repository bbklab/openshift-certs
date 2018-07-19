#!/bin/bash

function restart_origin_master() {
	systemctl restart origin-master-api
	if [ $? -ne 0 ]; then
		return $?
	fi
	systemctl restart origin-master-controllers
	if [ $? -ne 0 ]; then
		return $?
	fi
	return 0
}

function yum_install_package() {
	local pkgname=$1
	local retry=0 maxretry=$2

        while !(rpm -qi $pkgname >/dev/null 2>&1); do
                yum -y -q install $pkgname
                ((retry++))
                if [ $retry -gt $maxretry ]; then
                        echo "-ERR: $pkgname packages install error"
                        exit 1
                fi
        done
}

function get_mutex_lock() {
	local d_mutex=$1

	while :; do
		if mkdir "${d_mutex}" > /dev/null 2>&1; then
			break # we got the lock
		else
			echo "waitting for a mutex lock ... "
			sleep 1
		fi
	done
}

function get_active_physical_inetdevs() {
	# get active inet devs
	actives=$( cat /proc/net/dev 2>/dev/null | awk '($1~/:/ && $2 > 0 && $10 > 0){gsub(":","",$1); print $1}' )
	if [ -z "${actives}" ]; then
		return
	fi

	# get physical inet devs
	for dev in `echo ${actives}`; do
		if [ ! -d "/sys/devices/virtual/net/$dev" ]; then
			echo "$dev"
		fi
	done
}


function get_local_physical_ips() {
	inetdevs=$( get_active_physical_inetdevs )
	if [ -z "${inetdevs}" ]; then
		return
	fi

	local ips= ip=
	for dev in `echo "${inetdevs}"`
	do
		ip=$( ifconfig ${dev} 2>&- | awk '($1=="inet"){print $2;exit}' )
		if [ -z "${ip}" ]; then
			continue
		fi
		if [ -z "${ips}" ]; then
			ips=${ip}
		else
			ips=${ips},${ip}
		fi
	done
	echo $ips
}

# terminal color
echo_green() {
  local content=$*
  echo -e "\033[1;32m${content}\033[0m\c "
}

echo_yellow() {
  local content=$*
  echo -e "\033[1;33m${content}\033[0m\c "
}

echo_red() {
  local content=$*
  echo -e "\033[1;31m${content}\033[0m\c "
}

# TODO
# check_cert_expire_days check if given x509 certificate file  will be expired within given days
# return: 
#   - unkn
#   - yes
#   - no
function check_cert_expire_days() {
	local fcert=$1  days=$2
	# openssl x509  -in ${fcert} -noout -serial -startdate -enddate   -subject -issuer
}
