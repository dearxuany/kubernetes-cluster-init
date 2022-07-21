#!/bin/bash

read -p "Please enter the ip address: " New_ip

network_script_path="/etc/sysconfig/network-scripts/ifcfg-ens33"

if [[ $New_ip =~ ([0-9]+\.?){3}([0-9]+)? ]]
then
   sed -ri "s/IPADDR.*/IPADDR=$New_ip/" $network_script_path
   grep 'IPADDR' $network_script_path
   systemctl restart network
else
echo "ip address error,please re-enter"
fi
