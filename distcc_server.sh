#!/bin/bash
#SBATCH -N3 --exclusive
#SBATCH --job-name=distcc_server
#SBATCH --time=00:30:00

# File to store info about job and available resources
dotfile="${HOME}/.distcc_server"

# Necessary modules, though slurm shouldn't be strictly necessary.
module load slurm
module load modules-nix
module load nix/distcc

# Load in default gcc (otherwise it will use the system gcc/g++)
# Change this if you need
module load gcc

# Cleanup when bash sent SIGTERM.
sig_handler() {
    echo "sig_handler called.  Exiting"
    # do other stuff to cleanup here
    echo "Removing server info: $dotfile"
    rm -f $dotfile
    exit -1
}
trap 'sig_handler' TERM


# We need to prep a server 'dotfile' that contains the environment variables and other
# information necessary to tell distcc what resources are available to it. This requires
# hostnames and the CPUs available to us.

# Get raw host CPU-count string as array
IFS=','
hcpus=($SLURM_JOB_CPUS_PER_NODE)
unset IFS

declare -a njobs
# Expand compressed slurm array into jobs (2*ncpus) per host
for cpu in ${hcpus[@]}; do
    # string looks like 28(x3),40,20(x2) ...
    # if it has parentheses, parse that, otherwise just grab the value
    if [[ $cpu =~ ([0-9]+)\(x([0-9]+)\) ]]; then
	    value=${BASH_REMATCH[1]}
        factor=${BASH_REMATCH[2]}
	    for ((j = 1; j <= factor; j++)); do
	        njobs=( ${njobs[*]} $((value*2)) )
	    done
    else
	    njobs=( ${njobs[*]} $((cpu*2)) )
    fi
done

# Group job numbers with their associated hostnames and dump to string
host_string="--localslots_cpp=24 "
nhost=0
for node in $(scontrol show hostnames $SLURM_JOB_NODELIST); do
    jobspernode=${njobs[$nhost]};
    host_string="$host_string $node/$jobspernode"
    let nhost+=1
done

# Create dotfile
echo "#$SLURM_JOB_ID" > $dotfile
echo "export DISTCC_HOSTS='$host_string'" >> $dotfile

submitting_ip=$(host ${SLURM_SUBMIT_HOST} | awk '{print $4}')
srun --ntasks-per-node=1 distccd --no-detach --daemon --verbose --allow ${submitting_ip} &

wait

# The signal handler should do the cleaning up usually, but if for some reason your distccd
# daemons die...
echo "Cleaning up"
rm -f $dotfile
