
# distributed algorithms, n.dulay, 11 feb 19
# coursework 2, multi-paxos

# make options for Multipaxos

CLEAN UP
--------
make clean	- remove compiled code

SINGLE NODE EXECUTION
---------------------
make compile	- compile for single node execution
make run	- run in a single node 
make run SERVERS=n CLIENTS=m CONFIG=name
                - run with different numbers of servers, clients and 
                - version of configuration to use (see lib/configuration.ex)

DOCKER EXECUTION
----------------
make dcompile   - compile for docker / alpine
make drun	- clean, compile, gen docker-compose.yml and run under docker
make drun SERVERS=<n> CLIENTS=<m> CONFIG=<p> 

make down	- bring down docker network
make kill	- use instead of make down or if make down fails

make up		- make gen, then run in a docker network 
make up SERVERS=<n> CLIENTS=<m> CONFIG=<p> 

make show	- list docker containers and networks

make gen	- generate docker-compose.yml file


