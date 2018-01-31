SHELL := /bin/bash

# Gather Host Information
# {
UNAME := $(shell uname -s)
OS    := UNKNOWN

ifeq ($(UNAME),Linux)
    OS := linux
endif

ifeq ($(UNAME),Darwin)
    OS := macos
endif
# }

# Some useful variables...

ERROR   := "   \033[41;1m error \033[0m "
INFO    := "    \033[34;1m info \033[0m "
OK      := "      \033[32;1m ok \033[0m "
WARNING := " \033[33;1m warning \033[0m "

DOCKER := docker-compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose-dev-$(OS).yml
DOCKER_SYNC := docker-sync


# Task: help | show this help message.
# {
.PHONY: help
help:
	@echo
	@echo -e '\033[33mUsage:\033[0m'
	@echo '  make <target> [--] [<command>...] [options]'
	@echo
	@echo -e '\033[33mTargets:\033[0m'
	@egrep '^# Task: ([a-z-]+) \| (.+)$$' Makefile | awk -F '[:|]' '{print " \033[32m"$$2"\033[0m" "|" $$3}' | column -t -s '|'
	@echo
# }


# Task: build | create the application docker image.
# {
.PHONY: build
build:
	@bash -c 'eval "$$(echo $$(printf "%s " $$(cat docker.env)) $(DOCKER) build --pull)"'
# }


# Task: setup | initial project setup and configuration.
# {
.PHONY: setup
setup: docker-compose.override.yml docker.env build

docker-compose.override.yml:
	@cp docker-compose.override.yml.dist docker-compose.override.yml

docker.env:
	@cp docker.env.dist docker.env
	$(eval GITHUB_TOKEN = $(shell bash -c 'read -p "github-oauth.github.com[token]: " result; echo $$result'))
	$(eval AWS_ACCESS_KEY_ID = $(shell bash -c 'read -p "aws[id]: " result; echo $$result'))
	$(eval AWS_SECRET_ACCESS_KEY = $(shell bash -c 'read -p "aws[key]: " result; echo $$result'))
	$(eval TIDEWAYS_API_KEY = $(shell bash -c 'read -p "tideways.io[key] (optional): " result; echo $$result'))
ifeq ($(OS),macos)
	@sed -i '' 's;GITHUB_TOKEN=;GITHUB_TOKEN=$(GITHUB_TOKEN);g' docker.env
	@sed -i '' 's;AWS_ACCESS_KEY_ID=;AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID);g' docker.env
	@sed -i '' 's;AWS_SECRET_ACCESS_KEY=;AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY);g' docker.env
	@sed -i '' 's;TIDEWAYS_API_KEY=;TIDEWAYS_API_KEY=$(TIDEWAYS_API_KEY);g' docker.env
endif
ifneq ($(OS),macos)
	@sed -i'' 's;GITHUB_TOKEN=;GITHUB_TOKEN=$(GITHUB_TOKEN);g' docker.env
	@sed -i'' 's;AWS_ACCESS_KEY_ID=;AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID);g' docker.env
	@sed -i'' 's;AWS_SECRET_ACCESS_KEY=;AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY);g' docker.env
	@sed -i'' 's;TIDEWAYS_API_KEY=;TIDEWAYS_API_KEY=$(TIDEWAYS_API_KEY);g' docker.env
endif
# }

# Task: composer | alias to run composer within the application container.
# {
ifeq (composer,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

.PHONY: composer
composer:
	@$(DOCKER) exec --user build web composer $(RUN_ARGS); exit 0
# }


# Task: bash | open bash in the given container (default is web)
# {
ifeq (bash,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

.PHONY: bash
bash:
	@echo -e ${INFO} 'opening bash...'
	$(eval CONTAINER_NAME=$(if $(RUN_ARGS),$(RUN_ARGS),web))
	@$(DOCKER) exec --user="build" $(CONTAINER_NAME) bash
# }


# Task: start | start the application and associated containers.
# {
.PHONY: start
start:
	$(DOCKER) up -d --no-build
# }


# Task: stop | stop the application and associated containers.
# {
.PHONY: stop
stop:
	$(DOCKER) stop
# }

# Task: restart | stop and start the application and associated containers.
# {
.PHONY: restart
restart: stop start
# }


# Task: destroy | remove application containers, network and volumes.
# {
.PHONY: destroy
destroy: stop
	$(DOCKER) down --volumes
# }


# Task: reset | alias to destroy, build and start the application.
# {
.PHONY: reset
reset: destroy build start
# }


# Task: ip | retrieve IP of web container
# {
.PHONY: ip
ip:
ifeq ($(OS),linux)
	@docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $$($(DOCKER) ps -q web)
endif
ifneq ($(OS),linux) # Assume docker for mac|windows otherwise
	@echo 127.0.0.1
endif
# }


# Task: test | run tests
# {
.PHONY: test
test: test-phpspec
# }

# Task: test-phpspec | run phpspec examples
# {
.PHONY: test-phpspec
test-phpspec:
	@echo -e ${INFO} 'running phpspec examples...'
	@$(DOCKER) exec --user build web bin/phpspec run
# }

# Task: db-console | open mysql console in the database container
# {
.PHONY: db-console
db-console:
	@echo -e ${INFO} 'opening mysql console...'
	@$(DOCKER) exec mysql mysql -udocker-thunder -pdocker-thunder docker_thunder
# }

# Task: db-dump | create db dump
# {
ifeq (db-dump,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

.PHONY: db-dump
db-dump:
	@echo -e ${INFO} 'creating db dump...'
	$(eval DUMPFILE_NAME=$(if $(RUN_ARGS),$(RUN_ARGS),forcesnetdb))
	$(eval DUMPFILE_NAME="$(DUMPFILE_NAME).sql")
	@$(DOCKER) exec --user build web mysqldump -udocker-thunder -pdocker-thunder -h mysql docker-thunder > $(DUMPFILE_NAME)
	@echo -e ${INFO} 'db dump saved as' $(DUMPFILE_NAME)
# }

# Task: db-restore | restores the database to it's initial development state
# {
.PHONY: db-restore
db-restore:
	@echo -e ${WARNING} 'you are about to restore the database, you will lose data...'; \
	sleep 3; \
	$(DOCKER) exec web bash -c 'FORCE_DATABASE_DROP=true container assets_all'
	@echo -e ${INFO} 'done'
# }
