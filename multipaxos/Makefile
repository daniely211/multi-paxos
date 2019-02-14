
# distributed algorithms, n.dulay, 11 feb 19
# coursework 2, paxos made moderately complex
# Makefile, v3 

CONFIG  = default

SERVERS = 3
CLIENTS = 2

# ----------------------------------------------------------------------

MAIN         = Multipaxos.main
SINGLE_SETUP = single
DOCKER_SETUP = docker

PROJECT      = da347
NETWORK      = $(PROJECT)_network
 
# run all clients, servers and main component in a single node
SINGLE	 = mix run --no-halt -e $(MAIN) $(CONFIG) $(SINGLE_SETUP) \
       	   $(SERVERS) $(CLIENTS) 

# run each client, server and main component in its own docker container
DOCKER   = docker-compose -p $(PROJECT)
GEN_YML	 = ./gen_yml.sh $(MAIN) $(CONFIG) $(DOCKER_SETUP) $(SERVERS) \
           $(CLIENTS) 

# non-docker compile and run
compile:
	mix compile

run:
	$(SINGLE)
	@echo ----------------------

clean:
	mix clean


# docker compile and run
dcompile dockercompile:
	mix clean
	docker run -it --rm -v "$(PWD)":/project -w /project elixir:alpine mix compile

drun dockerrun:
	@make dockercompile
	@make up
	@echo ----------------------

gen:
	$(GEN_YML)

up:	
	@make gen
	$(DOCKER) up 

down:
	$(DOCKER) down
	make show

kill:  
	docker rm -f `docker ps -a -q`
	docker network rm $(NETWORK)

# more docker commands
show:
	@echo ----------------------
	@make ps
	@echo ----------------------
	@make network 

show2:
	@echo ----------------------
	@make ps2
	@echo ----------------------
	@make network 

ps:
	docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

ps2:
	docker ps -a -s

network net:
	docker network ls

inspect:
	docker network inspect $(NETWORK)

netrm:
	docker network rm $(NETWORK) 
conrm:
	docker rm $(ID)


