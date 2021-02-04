#!/bin/bash

set -ex

# Configure the PF on the smartnic host
if [[ "$(hostname -s)" == "OVS_HOST" ]] ; then
    ip link set dev DEV_PF0 promisc off
    ip link set dev DEV_PF0 down
    ip addr flush dev DEV_PF0
    ip link set dev DEV_PF0 up
    ip addr add dev DEV_PF0 OVS_HOST1_l/21
    # Below is due to SWNETLINUX-4048/4050
    ip link set dev DEV_PF0 mtu 1574
fi

# Set MAC address on VF
if [[ "$(hostname -s)" == "HOST1" ]]; then
    ip link set DEV_PF0_VF0 down
    ip addr flush dev DEV_PF0_VF0
    
    if [[ HOST_ID -eq 1 ]]
    then
	if ip netns ls | grep -q server
	then
	    ip netns del server
	fi
	ip netns add server
	sleep 1s
	ip link set dev DEV_PF0_VF0 netns server
	ip netns exec server ip link set dev DEV_PF0_VF0 address DEV_PF0_VF0_MAC
	ip netns exec server ip addr add dev DEV_PF0_VF0 192.168.0.1/16
	ip netns exec server ip link set dev DEV_PF0_VF0 up
    else
	OVS_CTL='/usr/share/openvswitch/scripts/ovs-ctl'

	${OVS_CTL} --system-id=HOST1 --no-monitor stop
	${OVS_CTL} --system-id=HOST1 --delete-bridges --no-monitor start

	ovs-vsctl set Open_vSwitch . other_config:tc-policy=none
	ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
	ovs-vsctl set Open_vSwitch . other_config:max-idle=10000

	${OVS_CTL} --system-id=HOST1 --no-monitor restart

	ip link set dev DEV_PF0_VF0 address DEV_PF0_VF0_MAC
	ip link set dev DEV_PF0_VF0 up
    fi
fi

# Configure OVS_HOST which may be the same host as HOST1 or the ARM SoC
if [[ "$(hostname -s)" == "OVS_HOST" ]]; then

    OVS_CTL='/usr/share/openvswitch/scripts/ovs-ctl'

    # General cleanup
    ip link del dev vxlan0 || true
    ip link del dev geneve0 || true

    ${OVS_CTL} --system-id=OVS_HOST --no-monitor stop
    ${OVS_CTL} --system-id=OVS_HOST --delete-bridges --no-monitor start

    ovs-vsctl set Open_vSwitch . other_config:tc-policy=none
    ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
    ovs-vsctl set Open_vSwitch . other_config:max-idle=10000

    ${OVS_CTL} --system-id=OVS_HOST --no-monitor restart

    # Clear and configure VF REPs
    ip link set dev DEV_PF0_VF0_REP down
    ip addr flush dev DEV_PF0_VF0_REP
    ip link set dev DEV_PF0_VF0_REP address DEV_PF0_VF0_REP_MAC
    ip link set dev DEV_PF0_VF0_REP up

    ovs-vsctl add-br br0
    ovs-vsctl add-port br0 vxlan0 -- set interface vxlan0 type=vxlan options:local_ip=OVS_HOST1_l options:remote_ip=OVS_HOST2_l options:key=1000 options:tos=0
    ovs-vsctl add-port br0 DEV_PF0_VF0_REP

fi

