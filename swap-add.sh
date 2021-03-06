# author: nanqinlang
## based on swap.sh

check_system(){
	while true
	do
		if cat /proc/version | grep fedora >/dev/null 2>&1
		then
			os_release=fedora
			echo "$os_release"
			SUDO="sudo"
			break
		fi
		if cat /proc/version | grep centos >/dev/null 2>&1
		then
			os_release=centos
			echo "$os_release"
			SUDO="sudo"
			break
		fi
		if cat /proc/version | grep ubuntu >/dev/null 2>&1
		then
			os_release=ubuntu
			echo "$os_release"
			SUDO="sudo"
			break
		fi
		if cat /proc/version | grep -i debian >/dev/null 2>&1
		then
			os_release=debian
			echo "$os_release"
			SUDO="sudo"
			break
		fi
		break
	done
}

check_root(){
	[[ "`id -u`" != "0" ]] && echo -e "must be root user !" && exit 1
}

check_zram() {
	if ${SUDO} swapon | grep "zram" >/dev/null 2>&1
	then
		echo -e "\033[1;40;31mYour system is using SwapOnZRAM.\n\033[0m"
		rm -rf $LOCKfile
		exit
	fi
}

check_memory_and_swap(){
	mem_count=$(free -m | grep Mem | awk '{print $2}')
	swap_count=$(free -m|grep Swap|awk '{print $2}')
	if [ "$mem_count" -ge 15000 ]  && [ "$mem_count" -le 32768 ]
	then
		if [ "$swap_count" -ge 8000 ]
		then
			echo -e "\033[1;40;31mAlready enough swap space, no need to add swap. Script will exit.\n\033[0m"
			rm -rf $LOCKfile
			exit 1
		elif [ "$swap_count" -ne 0 ]
		then
			echo -e "\033[40;32mNot enough swap space, adding swap.\n\033[40;37m"
			remove_old_swap
			create_swap 8192
		else
			echo -e "\033[40;32mNot enough swap space, adding swap.\n\033[40;37m"
			create_swap 8192
		fi
	elif [ "$mem_count" -ge 3900 ] && [ "$mem_count" -lt 15000 ]
	then
		if [ "$swap_count" -ge 3900 ]
		then
			echo -e "\033[1;40;31mAlready enough swap space, no need to add swap. Script will exit.\n\033[0m"
			rm -rf $LOCKfile
			exit 1
		elif [ "$swap_count" -ne 0 ]
		then
			echo -e "\033[40;32mNot enough swap space, adding swap.\n\033[40;37m"
			remove_old_swap
			create_swap 4096
		else
			echo -e "\033[40;32mNot enough swap space, adding swap.\n\033[40;37m"
			create_swap 4096
		fi
	else
		if [ "$swap_count" -ge 2000 ]
		then
			echo -e "\033[1;40;31mAlready enough swap space, no need to add swap. Script will exit.\n\033[0m"
			rm -rf $LOCKfile
			exit 1
		elif [ "$swap_count" -ne 0 ]
		then
			echo -e "\033[40;32mNot enough swap space, adding swap.\n\033[40;37m"
			remove_old_swap
			create_swap 2048
		else
			echo -e "\033[40;32mNot enough swap space, adding swap.\n\033[40;37m"
			create_swap 2048
		fi
	fi
}

create_swap(){
	root_disk_size=$(df -m|grep -w "/"|awk '{print $4}')
	if [ "$1" -gt "${root_disk_size-1024}" ]
	then
		echo -e "\033[1;40;31mThe root disk partition has no space for $1M swap file. Script will exit.\n\033[0m"
		rm -rf $LOCKfile
		exit 1
	fi
	if [ -e $swapfile ]
	then
		echo -e "\033[1;40;31mThe /var/swap_file already exists. Removing.\n\033[0m"
		remove_old_swap
	fi
	if [ ! -e $swapfile ]
	then
		dd if=/dev/zero of=$swapfile bs=1M count=$1
		chmod 600 $swapfile
		${SUDO} mkswap $swapfile
		${SUDO} swapon $swapfile
		${SUDO} swapon -s
		echo -e "\033[40;32mStep 3. Successfully added swap partition.\n\033[40;37m"
	# else
	# 	echo -e "\033[1;40;31mThe /var/swap_file already exists.Will exit.\n\033[0m"
	# 	rm -rf $LOCKfile
	# 	exit 1
	fi
}

remove_old_swap()
{
	old_swap_file=$(grep swap $fstab|grep -v "#"|awk '{print $1}')
	${SUDO} swapoff $old_swap_file
	cp -f $fstab ${fstab}_bak
	sed -i '/swap/d' $fstab
}

config_rhel_fstab()
{
	if ! grep $swapfile $fstab >/dev/null 2>&1
	then
		echo -e "\033[40;32mBegin to modify $fstab.\n\033[40;37m"
		echo "$swapfile	 swap	 swap defaults 0 0" >>$fstab
	else
		echo -e "\033[1;40;31m/etc/fstab is already configured.\n\033[0m"
		rm -rf $LOCKfile
		exit 1
	fi
}

config_debian_fstab()
{
	if ! grep $swapfile $fstab >/dev/null 2>&1
	then
		echo -e "\033[40;32mBegin to modify $fstab.\n\033[40;37m"
		echo "$swapfile	 none	 swap sw 0 0" >>$fstab
	else
		echo -e "\033[1;40;31m/etc/fstab is already configured.\n\033[0m"
		rm -rf $LOCKfile
		exit 1
	fi
}



#########################################################
## the following is the main :
#########################################################

lockfile(){
#check lock file ,one time only let the script run one time
LOCKfile=/tmp/.`basename $0`
if [ -f "$LOCKfile" ]
then
	echo -e "\033[1;40;31mThe script already exist, please exit before you run this script again.\n\033[0m"
	exit
else
	echo -e "\033[40;32mStep 1. No lock file, creating lock file...\n\033[40;37m"
	touch $LOCKfile
fi
}

run(){
swapfile=/swapfile
fstab=/etc/fstab
check_zram
echo -e "\033[40;32mStep 3. Checking memory and swap.\n\033[40;37m"
check_memory_and_swap

echo -e "\033[40;32mStep 4. Begin to modify $fstab.\n\033[40;37m"
case "$os_release" in
fedora|centos)
	config_rhel_fstab
	;;
ubuntu|debian)
	config_debian_fstab
	;;
esac
}


## there is the runner :
check_root
check_system
lockfile
run
echo -e "\033[40;32mAll the operations were completed.\n\033[40;37m"
rm -rf $LOCKfile
echo "finished !"
