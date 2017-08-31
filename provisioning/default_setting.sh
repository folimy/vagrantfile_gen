#!/bin/bash
BARR="##################################"
echo "$BARR$BARR"
echo "$BARR$BARR"
Target_compose="c7_ng-1.10.4__c7_keydb_mysql_default-0.0.1-0.0.1__c7_to-8.5.162_jd-1.8.133"
#Target_compose="c7_jd-1.8.133_ds_servicepack-0.0.11"
Target_address="https://git.hcdd.kr/DDB/ddb_bakery/raw/master/docker-composes"
input_arry=($@)
        Countx=0
        while [ $Countx -lt  ${#input_arry[@]} ] ;do
                case "${input_arry[$Countx]}" in
                type*)
                        type=`echo "${input_arry[$Countx]}" | awk -F'=' '{print $2}'`
                        ;;
                ip*)
                        ip=`echo "${input_arry[$Countx]}" | awk -F'=' '{print $2}'`
                        ;;
                host*)
                        host=`echo "${input_arry[$Countx]}" | awk -F'=' '{print $2}'`
                        ;;
                dns*)
                        dns=`echo "${input_arry[$Countx]}" | awk -F'=' '{print $2}'`
                        ;;
#                http_proxy*)
#                        http_proxy=`echo "${input_arry[$Countx]}" | awk -F'=' '{print $2}'`
#                        ;;
                esac
        let Countx=$Countx+1
        done

# CentOS(RHEL) Network Manager stop
systemctl stop NetworkManager
systemctl disable NetworkManager

LANG=en_US.UTF-8
sed -i '/^LANG=/d' /etc/sysconfig/i18n
echo 'LANG=en_US.UTF-8' >> /etc/sysconfig/i18n
sed -i 's/=enforcing/=disabled/g' /etc/selinux/config

        if [[ $dns != "" ]];then
                cat <<EOF > /etc/resolv.conf
nameserver $dns
EOF
        fi

setenforce 0

echo "$BARR zinst $BARR"
curl -sL bit.ly/online-install |bash
	if [[ $type == "file" ]];then
                /usr/bin/zinst self-conf ip=$ip host=$host
        fi
zinst self-update
zinst i server_default_setting -stable -same

echo "$BARR zinst $BARR"
#        if [[ $http_proxy != "" ]];then
#                /usr/bin/zinst i proxyctl -stable
#                 /usr/bin/zinst set proxyctl.HTTP="$http_proxy" -set proxyctl.HTTPS="$http_proxy"
#                /data/z/etc/init.d/proxyctl start
#                bash -l
#        fi
#
        if [[ $dns != "" ]];then
                zinst set server_default_setting.name1=$dns
                /data/bin/nameserver.sh
        fi
echo "$BARR docker $BARR"
curl -sL bit.ly/startdocker |bash
echo "$BARR docker $BARR"
mkdir -p /data/src/bin
cd /data/src/bin
wget $Target_address/$Target_compose/service_restart.sh
wget $Target_address/$Target_compose/docker-compose.yml;docker-compose up -d
chmod 755 *.sh 2> /dev/null
echo "$BARR  done  $BARR"
