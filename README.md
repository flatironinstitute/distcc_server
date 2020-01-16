# Overview
This is a two part template package designed to use `distcc` on cluster resources at Flatiron
Institute. `distcc` allows a user to compile software packages across multiple nodes without
requiring a shared drive or uniform environment. While FI has shared drives for cluster
resources, often it's worthwile to do development on local drives or even shared memory
(`/dev/shm`), since the latency on the shared mounts can cause significant performance
degradation when dealing with lots of small files.

# Why you should bother
The Rosetta package, compiled on a shared drive ($HOME or ceph) will take several hours for a
full compile on a standard workstation. On `/dev/shm` this is reduced roughly an hour. `distcc`
called from `/dev/shm` with three compile nodes builds in just under 10 minutes.

# Getting it to work
While this should work out nearly out of the box for most basic needs, use of special compilers
or build systems (such as `scons`) might require additional modification.

There are two parts to the package. The first is an `sbatch` script to run the `distccd` daemon
on the cluster nodes. The second is a wrapper script which detects the running daemons, preps
your environment to use `distcc`, and then calls your build program.

## distcc_server.sh
To run the server, from any directory,
```
module load slurm
sbatch --output=${HOME}/distcc_server_%j.log /path/to/distcc_server.sh
```

The output argument is only strictly necessary when running the server from a path that isn't
on the shared file system. Note that both of these arguments are trivially hardcoded into the
server script itself to save yourself the annoying headache

```
#SBATCH --output=/path/to/logs/distcc_server_%j.log

HOST=XXX.XXX.XXX.XXX
```
where `HOST` is the ip address of the machine starting the compilation (`hostname -i`).


By default the server uses the `gcc` package to know which `gcc` to use. To use alternative
compilers, either load the appropriate module in the server, or supply the absolute path to the
compiler to `run_dist.sh`. Other than the compiler path, the server does not need detailed
knowledge of your environment, such as include paths, executable paths, and other things. All
of the environment dependent work is done in the local environment before being dispatched to
the `distccd` clients.

### Performance notes
Note that I only use three nodes to compile. This is because with `Rosetta`, the local
precompilation could not precompile fast enough to saturate more than three nodes with the
actual compilation. There is another mode for `distcc` called `pump` that would allow for
compilation on more nodes by moving precompilation from `localhost` to the nodes, but it does
not work with heavy precompilation steps, as those necessary with packages such as
`boost`. Adding more nodes is unlikely to increase performance.

In theory the `localhost` role could be moved to a node as well, which would more than double
the precompilation speed, but would require syncing the source to the server as a preliminary
first step, creating a bottleneck and increasing the complexity of the package.

## run_dist.sh
Once the server is running (in 'R' state), building your package is as simple as building prepending
`run_dist.sh` to your normal build command. For example, with `Rosetta` that I've synced to
`/dev/shm`,

```
cd /dev/shm/Rosetta/main/source
/path/to/run_dist.sh ./ninja_build.py r -remake -j200
```

If you'd like to change the compilers provided to `run_dist.sh`, use a compiler that the server
is unaware of, oruse another build system (such as `make`)

```
cd /path/to/build_directory
CC=/path/to/cc CXX=/path/to/c++ /path/to/run_dist.sh make -j200
```

