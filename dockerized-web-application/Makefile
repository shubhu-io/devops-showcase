SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help build up down logs test clean config

help: ## Show all targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build the app image
	docker compose build

up: ## Start the full stack in detached mode
	docker compose up -d --build

down: ## Stop and remove containers (keep named volume)
	docker compose down

logs: ## Tail logs from all services
	docker compose logs -f --tail=100

test: ## Run the API test suite
	bash tests/test-api.sh

config: ## Validate and print the compose file
	docker compose config

clean: ## Stop everything and delete the pgdata volume
	docker compose down -v
	docker image rm dockerized-app:latest || true
