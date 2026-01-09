SCRIPTS_DIR := scripts
BUILD_SCRIPT := $(SCRIPTS_DIR)/build-images.sh
DISCOVER_SCRIPT := $(SCRIPTS_DIR)/discover-images.sh

RESET := \033[0m
GREEN := \033[0;32m
YELLOW := \033[0;33m

.DEFAULT_GOAL := help

.PHONY: discover
discover: ## List all Docker images found in the repository
	@chmod +x $(DISCOVER_SCRIPT)
	@$(DISCOVER_SCRIPT) --format=readable

.PHONY: discover-json
discover-json: ## Output Docker images list as JSON
	@chmod +x $(DISCOVER_SCRIPT)
	@$(DISCOVER_SCRIPT) --format=json

.PHONY: lint
lint: ## Lint all Dockerfiles
	@echo "Linting Dockerfiles..."
	@find images -name Dockerfile -exec sh -c 'echo "=== {} ===" && docker run --rm -i hadolint/hadolint < "{}"' \;

.PHONY: build-all
build-all: lint ## Build all discovered Docker images locally
	@chmod +x $(BUILD_SCRIPT)
	$(BUILD_SCRIPT)

.PHONY: help
help:  ## Display this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "$$(printf '$(GREEN)')General$$(printf '$(RESET)')"
	@grep -E '^(help):.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*? ## "}; {printf "$(YELLOW)%-25s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$$(printf '$(GREEN)')Discovery$$(printf '$(RESET)')"
	@grep -E '^(discover|discover-json):.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-25s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$$(printf '$(GREEN)')Linting$$(printf '$(RESET)')"
	@grep -E '^(lint):.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-25s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$$(printf '$(GREEN)')Build$$(printf '$(RESET)')"
	@grep -E '^(build.*):.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-25s$(RESET) %s\n", $$1, $$2}'
