#!/bin/bash
consul="10.53.15.219"

consul_url="http://$consul:8500/v1/kv/hypervisors"
hostfile_dir="./host"

conf_dir="./conf"

Vagrantfile_base="./service"
host_keydir="/data/var/vagrant"

sudo rm -Rf $Vagrantfile_base/*/Vagrantfile

Conf_create() {
	input_type=$1

	if [[ $input_type == "file" ]]; then
		host_list=$(ls $hostfile_dir | sed -e 's#\.list##g')
	elif [[ $input_type == "consul" ]]; then
		host_list_json=$(curl -sL http://10.53.15.219:8500/v1/kv/hypervisors?keys)
		host_list=($(echo "$host_list_json" | sed -e 's/\[\(.*\)\]/\1/g' -e 's/,/ /g' -e 's/"//g'))
		Hcount=0
		while [ $Hcount -lt ${#host_list[@]} ]; do
			host_list[$Hcount]=$(echo "${host_list[$Hcount]}" | awk -F '/' '{print $(NF-1)}')
			let Hcount=$Hcount+1
		done
		host_list=($(echo "${host_list[@]}" | sed -e 's/hypervisors//g' | xargs -n1 | sort -u | xargs))
	fi

	Count=0
	#	while [ $Count -lt ${#host_list[@]} ];do
	for i in $host_list; do
		mkdir -p $Vagrantfile_base/$i
		output_file="$Vagrantfile_base/$i/vagrant.out"
		result_file="$Vagrantfile_base/$i/Vagrantfile"

		## IP range listup by each hosts
		if [[ $input_type == "file" ]]; then
			echo "#!/bin/bash" >$output_file
			cat $hostfile_dir/$i.list | sed -e 's/[0-9]x/&{i}/g' -e 's/x{/#{/g' >>$output_file
		elif [[ $input_type == "consul" ]]; then
			echo "#!/bin/bash" >$output_file
			checkdata=$(curl -s "$consul_url/$i/data?raw" | sed -e 's/[0-9]x/&{i}/g' -e 's/x{/#{/g')
			if [[ $checkdata == "" ]]; then
				remove_target_dir="$Vagrantfile_base/$i"
			fi
			curl -s "$consul_url/$i/data?raw" | sed -e 's/[0-9]x/&{i}/g' -e 's/x{/#{/g' >>$output_file
			sudo mkdir -p $host_keydir
			sudo curl -s "$consul_url/$i/ssh-key?raw" -o $host_keydir/$i.key
			if [[ $( (whoami)) == "root" ]]; then
				chmod 600 $host_keydir/$i.key
				chown root.wheel $host_keydir/$i.key
			else
				sudo chmod 640 $host_keydir/$i.key
				sudo chown root.wheel $host_keydir/$i.key
			fi
		fi

		## Start to stamping for vagrant export
		echo "" >>$output_file

		cat <<EOF >>$output_file
zinst_repo_ip=$(grep "zinst_repo_ip" $hostfile_dir/$i.list | tail -1 | awk -F'=' '{print $2}' | sed -e 's/"//g')
zinst_repo_host=$(grep "zinst_repo_host" $hostfile_dir/$i.list | tail -1 | awk -F'=' '{print $2}' | sed -e 's/"//g')
	if [[ \$zinst_repo_ip = "" ]];then
		zinst_repo_ip="13.124.6.97"
	fi
	if [[ \$zinst_repo_host = "" ]];then
		zinst_repo_host="zinst.hcdd.kr"
	fi
EOF

		echo "cat << EOF > $result_file" >>$output_file

		cat <<EOF >>$output_file
# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.a

#VAGRANTFILE_API_VERSION = "2"
#NODE_COUNT = 10
#Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
#  config.vm.provision "shell", path: "../../provisioning/default_setting.sh", args: "type=$input_type ip=\$zinst_repo_ip host=\$zinst_repo_host dns=\$domain_server http_proxy=10.53.15.219:3128"

###############################
EOF

		provider=$(grep "provider" $hostfile_dir/$i.list | tail -1 | awk -F'=' '{print $2}' | sed -e 's/"//g')
		provider_dir="./provider"
		## Insert as the provider select
		case $provider in
		vsphere)
			## Each configuration export
			cat $conf_dir/vsphere.conf >>$output_file
			provider_conf="$provider_dir/vsphere"
			;;
		kvm)
			## Each configuration export
			cat $conf_dir/kvm.conf >>$output_file
			provider_conf="$provider_dir/kvm"
			;;
		*)
			## Each configuration export
			cat $conf_dir/default.conf >>$output_file
			provider_conf="$provider_dir/virtualbox"
			;;
		esac

		cat $provider_conf >>$output_file

		## Close export script
		echo "EOF" >>$output_file
		sudo chmod 755 $output_file

		./$output_file
		sudo rm -f $output_file

		#		cat $result_file

		let Count=$Count+1
		rm -Rf $remove_target_dir
	done
}

function get_compose_list() {

	IMAGE_LIST_ARRAY[0]=""
	IMAGE_COUNT=1
	DIALOG=dialog
	curl -s https://git.hcdd.kr/DDB/ddb_bakery/src/master/docker-composes -o ./docker-compose.img &
	{
		i=0
		while (true); do
			proc=$(pgrep curl)
			if [[ $proc == "" ]]; then
				break
			fi
			sleep 1
			echo $i
			i=$(expr $i + $(( ($RANDOM % 12) )) )
			if [[ $i -gt "98" ]]; then
				i=99
			fi
		done
		echo 100
		sleep 2
	} | $DIALOG --backtitle "docker-compose " --title "Docker-Compose Image Check" --gauge "Loading Docker Compose List..." 6 80 0
	for i in $(cat ./docker-compose.img | grep "<a href=" | awk -F\"\> '{print $NF}' | grep ^[a-z][0-9] | sed -e 's/<\/a>//g'); do
		IMAGE_LIST_ARRAY[$IMAGE_COUNT]="$i $IMAGE_COUNT off"
		let IMAGE_COUNT=$IMAGE_COUNT+1
	done
}

Conf_create file
Conf_create consul
get_compose_list
$DIALOG --backtitle "docker-compose Loader" \
	--title "Select Docker-compose file" --clear \
	--radiolist "Select Docker-compose file" 30 80 12 \
	${IMAGE_LIST_ARRAY[@]} 2>./selected_img.list

selected_compose_file=$(cat ./selected_img.list)

cp ./provisioning/template_setting.sh ./provisioning/default_setting.sh
sed -i 's/TEMPLATE_DOCKER_COMPOSE_YAML/'$selected_compose_file'/' ./provisioning/default_setting.sh

echo "  --- Vagrantfile has been created in each service directory. \"$Vagrantfile_base\" as below ---"
rm -rf ./selected_img.list
rm -rf ./docker-compose.img
tree $Vagrantfile_base
