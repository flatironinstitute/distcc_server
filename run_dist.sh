#!/usr/bin/env bash

dotfile="$HOME/.distcc_server"

if [ -f "$dotfile" ]; then
    jobid="$(head -n1 $dotfile)"
    jobid="${jobid//#}"
    . $dotfile
    jobname=$(squeue --noheader -j $jobid --format=%j)
    if [[ "$jobname" != "distcc_server" ]]; then
        echo "No distcc server found at jobid=$jobid, likely a stale dotfile=$dotfile"
        exit 1
    fi
else
    echo "No distcc server found at '$dotfile', have you started distcc_server.sh?"
    exit 1
fi

echo "DISTCC_HOSTS set to '$DISTCC_HOSTS'"

# Don't use NFS mounts for '$DISTCC_DIR', which defaults to '$HOME'. distcc uses file locks and
# other state data in '$DISTCC_DIR/.distcc', which should be on a fast drive with proper
# locking of some kind.
export DISTCC_DIR=/dev/shm

# Set default compiler to gnu suite if unset
[ ! -z "$CC" ] || export CC='gcc'
[ ! -z "$CXX" ] || export CXX='g++'

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
eval "$@"
