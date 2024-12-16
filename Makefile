.PHONY: help build up down logs restart clean all start test

# Variables
IMAGE := theta-terminal
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# Default target is now help
.DEFAULT_GOAL := help

## Show available commands
help:
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
	docker compose build

## Start containers in detached mode
up:
	docker compose up -d

## Stop and remove containers
down:
	docker compose down

## View container logs
logs:
	docker compose logs -f

## Restart containers
restart: down up

## Clean up containers, images, and volumes
clean:
	docker compose down --rmi all --volumes --remove-orphans

## Build, start and show logs
start: build up logs

## Build and start containers
all: build up

## Test connection to MDDS
test: up
	@echo "Waiting for service to start..."
	@sleep 10
	@echo "Testing connection..."
	@curl -s http://127.0.0.1:25511/v2/system/mdds/status > /tmp/status.txt
	@if [ "$$(cat /tmp/status.txt)" = "CONNECTED" ]; then \
		echo "${GREEN}Connection successful!${RESET}"; \
		rm /tmp/status.txt; \
		exit 0; \
	else \
		echo "${RED}Connection failed with status: $$(cat /tmp/status.txt)${RESET}"; \
		echo "Container logs:"; \
		docker compose logs; \
		rm /tmp/status.txt; \
		exit 1; \
	fi