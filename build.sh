#!/bin/sh

set -e
ROOT=$(pwd)

get_repository() {
	repo=https://github.com/igankevich/bscheduler
	rev=72f9df50ecc493b58e065d424cdc3e560e9deb78
	if ! test -d bscheduler
	then
		echo "Cloning repository..."
		git clone -q $repo bscheduler
	fi
	cd bscheduler
	git checkout master
	git pull
	git checkout -q $rev
	echo "Repository: $(git remote get-url origin)"
	echo "Revision: $(git rev-parse HEAD)"
}

build_bscheduler() {
	dir=$1
	options=$2
	echo "Building with $options ..."
	if ! test -d $dir
	then
		meson --buildtype=release . $dir
	fi
	mesonconf $dir $options
	ninja -C $dir
#	ninja -C $dir test
}

benchmark() {
	nodes=$1
	daemons=$2
	device=$3
	attempt=$4
	fanout=$5
	timeout=$6
	sleep=$7
	hostname=$(hostname)
	cd $ROOT/bscheduler
	$ROOT/node-discovery-generate \
		--device $device \
		--nodes $nodes \
		--daemons $daemons \
		--timeout $timeout \
	   	-- \
		$ROOT/bscheduler/node-discovery/src/bscheduler/daemon/bscheduler servers=@ifaddr@ fanout=$fanout
	set +e
	if test "$nodes" = "1"
	then
		sudo -n ./delete-old-addresses
		sudo -n ./add-1
		cat ./benchmark-1
		./benchmark-1
	else
		echo "Deleting old addresses and copying scripts..." >&2
		for i in $(seq $nodes)
		do
			echo "m$i" >&2
			ssh m$i "
				cp -v $PWD/add-$i $PWD/delete-old-addresses $PWD/benchmark-$i /tmp
				sudo -n /tmp/delete-old-addresses
				sudo -n /tmp/add-$i
				exit 0"
		done
		sleep 1
		echo "Running benchmarks..." >&2
		for i in $(seq $nodes)
		do
			echo "m$i" >&2
			sleep $sleep
			nohup ssh m$i "cd $PWD && /tmp/benchmark-$i" >/dev/null 2>&1 &
		done
		wait
	fi
	# collect logs
	set -e
	outdir=$ROOT/output/$hostname/d$daemons/n$nodes/a$attempt
	mkdir -p $outdir
	mv -v logs-$nodes-$daemons/*.log $outdir/
	cd $ROOT
}

get_repository
#build_bscheduler node-discovery "-Dprofile_node_discovery=true"
#benchmark 1 512 enp2s0 # storm

# ant
timeout_1=10
timeout_8=20
timeout_16=40
timeout_32=80
timeout_64=160
sleep_1=0.1
sleep_8=0.8
sleep_16=1.6
sleep_32=3.2
sleep_64=6.4
fanout=10000
for attempt in $(seq 1 10)
do
	for nodes in $(seq 2 11)
	do
		for daemons in 64
		do
			eval timeout="\$timeout_$daemons"
			eval sleep="\$sleep_$daemons"
			benchmark $nodes $daemons enp5s0f0 $attempt $fanout $timeout $sleep
		done
	done
done
