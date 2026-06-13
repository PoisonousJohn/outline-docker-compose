#!/bin/bash

sudo echo "vm.overcommit_memory=0" >> /etc/sysctl.conf
sudo echo "vm.dirty_background_ratio=5" >> /etc/sysctl.conf
sudo echo "vm.dirty_ratio=10" >> /etc/sysctl.conf
sudo echo "vm.overcommit_ratio=80" >> /etc/sysctl.conf
sudo echo "vm.swappiness=10" >> /etc/sysctl.conf
sudo echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
sudo sysctl -p
