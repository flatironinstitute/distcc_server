#!/bin/bash
#SBATCH -N3 --exclusive
#SBATCH --job-name=distcc_server
#SBATCH --time=00:30:00

module load gcc
module load modules-nix
module load nix/distcc

submitting_ip=$(dig +short ${SLURM_SUBMIT_HOST}.flatironinstitute.org)
srun --ntasks-per-node=1 distccd --daemon --verbose --no-detach --allow ${submitting_ip}
