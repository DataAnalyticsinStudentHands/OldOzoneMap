#!/bin/bash
#
# openconnectstartup script
#
#  Modify from gentoo sample: http://bugs.gentoo.org/show_bug.cgi?id=263097
#

#source /etc/conf.d/openconnect
source /root/openconnect/openconnect.conf
PID="/var/run/openconnect.pid"

set -e

case "$1" in
  start)
        echo "Starting OpenConnect"
        echo $PASSWORD | /usr/local/bin/openconnect --no-dtls --no-cert-check --user=$USERNAME --authgroup=$AUTHGROUP --no-deflate $SERVER --passwd-on-stdin >& /dev/null &
        echo $! > $PID
        sleep 2

        # Setup routing
        for NET in $NETWORKS; do
                /sbin/route add -net $NET netmask 255.255.255.0 dev tun0
        done

	# Setup routing for hosts
        for H in $ROUTE_HOSTS; do
		/sbin/ip route replace $H/32 dev tun0
        done

	/sbin/ip route flush cache

        echo "$0 started"
	;;

  stop)
        echo "Stopping OpenConnect"

        # Teardown routing
        for NET in $NETWORKS; do
                /sbin/route del -net $NET netmask 255.255.255.0 dev tun0
        done

	# Teardown routing for hosts
        for H in $ROUTE_HOSTS; do
                /sbin/route del -host $H dev tun0
        done

	/sbin/ip route flush cache

        kill $(cat $PID)
        echo "$0 Stoped"
  	;;

  *)
	N=$0
	echo "Usage: $N {start|stop}" >&2
	exit 1
	;;
esac

exit 0
