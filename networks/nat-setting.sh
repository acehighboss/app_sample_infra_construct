#!/bin/bash

#Amazon-Linux 기준 설치 파일

#검증 필요
interface=ens5

# 오류시 정지.
set -e

yum install -y iptables-services
systemctl start iptables
systemctl enable iptables

cat << EOF | sudo tee /etc/sysctl.d/ip_forwarding.conf
net.ipv4.ip_forward=1
EOF
sudo sysctl -p /etc/sysctl.d/ip_forwarding.conf

iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE
iptables -F FORWARD
service iptables save