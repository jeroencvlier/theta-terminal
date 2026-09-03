.PHONY: help build up down logs restart clean all start test

PROJECT := theta-terminal-v3
IMAGE := theta-terminal-v3
COMPOSE := docker compose -p $(PROJECT)

GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RED    := $(shell tput -Txterm setaf 1)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# Default target is now help
.DEFAULT_GOAL := help

## Show available commands
help:
	@echo ''
	@echo '${GREEN}Project name: $(PROJECT)${RESET}'
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-15s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

## Build the Docker image
build:
	$(COMPOSE) build

## Start containers in detached mode
up:
	$(COMPOSE) up -d

## Stop and remove containers
down:
	$(COMPOSE) down

## View container logs
logs:
	$(COMPOSE) logs -f

## Restart containers
restart: down up

## Start prod + staging containers (staging on :25501)
up-all:
	$(COMPOSE) --profile stage up -d

## Start staging container only (:25501)
up-stage:
	$(COMPOSE) --profile stage up -d theta-terminal-v3-stage

## Stop staging container only
down-stage:
	$(COMPOSE) --profile stage stop theta-terminal-v3-stage

## Stop prod + staging containers
down-all:
	$(COMPOSE) --profile stage down

## Restart prod + staging containers
restart-all: down-all up-all

## Clean up containers, images, and volumes
clean:
	$(COMPOSE) down --rmi all --volumes --remove-orphans

## Build, start and show logs
start: build up logs

## Build and start containers
all: build up

## Test connection to terminal
test-connection: 
	@echo "Waiting for service to start..."
	@sleep 5
	@echo "Testing connection to Theta Terminal v3..."
	@STATUS=$$(curl -s http://127.0.0.1:25500/v3/terminal/mdds/status); \
	if echo "$$STATUS" | grep -q "CONNECTED"; then \
		echo "${GREEN}✓ Connection successful!${RESET}"; \
		echo "Status: $$STATUS"; \
		exit 0; \
	else \
		echo "${RED}✗ Connection failed${RESET}"; \
		echo "Status response: $$STATUS"; \
		echo "\nContainer logs:"; \
		$(COMPOSE) logs --tail=50; \
		exit 1; \
	fi

## Run full test suite
test: up test-connection

## Show terminal version
version:
	@echo "Checking terminal version..."
	@curl -s http://127.0.0.1:25500/v3/system/version || echo "Terminal not running"