#!/bin/bash
set -e -x

NUM_INSTANCES=$1

if [ ! -d "/tmp/fleet/" ]; then
	exit 0
fi
cd /tmp/fleet/

# Ensure etcd/fleet are running
systemctl start etcd fleet

# Wait for cluster to form
while true; do
	if [ "`fleetctl list-machines | wc -l`" -gt "$NUM_INSTANCES" ]; then
		break
	fi

	sleep 1
done

# Deploy service and wait for etcd to consolidate
fleetctl submit *
sleep 5

SERVICES=""
for s in *; do
	# Non-replicated services
	SERVICES="$SERVICES $s"
done
fleetctl start -no-block=true $SERVICES
