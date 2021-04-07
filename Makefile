################
# Build targets
################

.PHONY: build
build: ## Build docker image
	bin/ci.sh build

.PHONY: push 
push: ## Build and push docker image
	bin/ci.sh build-and-push

########
# Tests
########

.PHONY: test-unit
test-unit:
	@echo "+ $@"
	python3 -m pytest tests/configuration.py  -s

.PHONY: test
test: build ## Run airflow tests
	@docker-compose -f docker-compose.yml up --abort-on-container-exit --exit-code-from test

############
# Utilities
############

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

