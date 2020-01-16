#!/usr/bin/env bash

# Detect which nodes distcc daemon running on
raw_servers=$(squeue --format=%N --noheader -u $USER -n distcc_server)
if [[ -z "$raw_servers" ]]; then
    echo "distcc_server seemingly not running"
    exit
fi
server_state=$(squeue --format=%t --noheader -u $USER -n distcc_server)
if [[ "R" != "$server_state" ]]; then
    echo "distcc_server not in run state. Wait until running and try again"
    exit
fi
servers=$(scontrol show hostnames $raw_servers)

# Format DISTCC_HOSTS environment variable to use 2x number of available cores for each node
# and 24 localhost precompilation processes
DISTCC_HOSTS="--localslots_cpp=24 "
for i in $servers ; do
    hostname=$(sinfo --noheader --nodes=${i} --format=%N)
    nprocs=$(sinfo --noheader --nodes=${i} --format=%c)
    njobs=$(expr 2 \* $nprocs)
    DISTCC_HOSTS="$DISTCC_HOSTS $hostname/$njobs"
done

export DISTCC_HOSTS
echo "Set distcc hosts to '$DISTCC_HOSTS'"

# Don't use NFS mounts for '$DISTCC_DIR', which defaults to '$HOME'. distcc uses file locks and
# other state data in '$DISTCC_DIR/.distcc', which should be on a fast drive with proper
# locking of some kind.
export DISTCC_DIR=/dev/shm

# Set default compiler to gnu suite if unset
[ ! -z "$CC" ] || export CC='distcc gcc'
[ ! -z "$CXX" ] || export CXX='distcc g++'

# Wrap input compilers if supplied without prepending distcc
case "$CC" in
    distcc* ) ;;
    * ) export CC="distcc $CC";;
esac
case "$CXX" in
    distcc* ) ;;
    * ) export CXX="distcc $CXX";;
esac
echo "CC set to '$CC'"
echo "CXX set to '$CXX'"

# Pass the buck :)
eval $@
