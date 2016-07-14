#!/bin/sh
set -e -x

# Temporary work dir
tmpdir="`mktemp -d`"
cd "$tmpdir"

# Install prerequisites
export DEBIAN_FRONTEND=noninteractive
apt-get update -q --yes
apt-get install -q --yes logrotate vim-nox hardlink wget ca-certificates

# Download and install Chef's packages
aria2c -x5 -j5 --checksum "sha-256=${CHEF_SERVER_SHA256}" "https://packages.chef.io/stable/ubuntu/14.04/chef-server-core_${CHEF_SERVER_VERSION}-1_amd64.deb"
aria2c -x5 -j5 --checksum "sha-256=${CHEF_CLIENT_SHA256}" "https://packages.chef.io/stable/ubuntu/12.04/chef_${CHEF_CLIENT_VERSION}-1_amd64.deb"

dpkg -i "chef-server-core_${CHEF_SERVER_VERSION}-1_amd64.deb" "chef_${CHEF_CLIENT_VERSION}-1_amd64.deb"

# Extra setup
rm -rf /etc/opscode
mkdir -p /etc/cron.hourly
ln -sfv /var/opt/opscode/log /var/log/opscode
ln -sfv /var/opt/opscode/etc /etc/opscode
ln -sfv /opt/opscode/sv/logrotate /opt/opscode/service
ln -sfv /opt/opscode/embedded/bin/sv /opt/opscode/init/logrotate
chef-apply -e 'chef_gem "knife-opc"'

# Cleanup
cd /
rm -rf $tmpdir /tmp/install.sh /var/lib/apt/lists/* /var/cache/apt/archives/*
