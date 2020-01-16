#!/bin/bash
#SBATCH -N3 --exclusive
#SBATCH --job-name=distcc_server
#SBATCH --time=00:30:00

module load gcc
module load modules-nix
module load nix/distcc

srun distccd --daemon --verbose --no-detach --allow ${HOST}
