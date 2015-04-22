#!/bin/bash
set -e -x

if [ ! -d "/tmp/fleet/" ]; then
	exit 0
fi
cd /tmp/fleet/

# Ensure etcd/fleet are running
systemctl start etcd fleet

# Destroy services
for s in *; do
	fleetctl destroy "$s"
done
