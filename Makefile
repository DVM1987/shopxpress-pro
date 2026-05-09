# ====================================================================
# Makefile — wrap Terraform lifecycle cho mọi sub-comp
# ====================================================================
# Usage:
#   make help                       # show available targets
#   make init     COMPONENT=10-vpc  # init backend cho 10-vpc
#   make plan     COMPONENT=10-vpc
#   make apply    COMPONENT=10-vpc
#   make destroy  COMPONENT=10-vpc
#   make fmt                        # format toàn repo
#   make validate COMPONENT=10-vpc
#
# Convention: COMPONENT = tên folder dưới terraform/
#   (00-bootstrap, 10-vpc, 20-eks, ...)

SHELL          := /usr/bin/env bash
TF_DIR         := terraform
COMPONENT      ?=
TF_COMPONENT   := $(TF_DIR)/$(COMPONENT)

# Colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
RESET  := \033[0m

.DEFAULT_GOAL := help

# Guard: COMPONENT required + folder must exist
define require_component
@if [ -z "$(COMPONENT)" ]; then \
	printf "$(RED)ERROR: COMPONENT required. Example: make $(1) COMPONENT=10-vpc$(RESET)\n"; \
	exit 1; \
fi
@if [ ! -d "$(TF_COMPONENT)" ]; then \
	printf "$(RED)ERROR: Folder $(TF_COMPONENT) không tồn tại$(RESET)\n"; \
	exit 1; \
fi
@printf "$(GREEN)→ COMPONENT: $(COMPONENT) ($(TF_COMPONENT))$(RESET)\n"
endef

.PHONY: help
help: ## Show this help message
	@printf "$(GREEN)Available targets:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-18s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(GREEN)Examples:$(RESET)\n"
	@printf "  make init     COMPONENT=10-vpc\n"
	@printf "  make plan     COMPONENT=10-vpc\n"
	@printf "  make apply    COMPONENT=10-vpc\n"
	@printf "  make destroy  COMPONENT=10-vpc\n"

.PHONY: init
init: ## Init backend partial config (require COMPONENT). Use BACKEND=local to override
	$(call require_component,init)
	@if [ "$(BACKEND)" = "local" ]; then \
		cd $(TF_COMPONENT) && terraform init; \
	else \
		cd $(TF_COMPONENT) && terraform init -backend-config=backend.hcl; \
	fi

.PHONY: plan
plan: ## Plan + save to tfplan (require COMPONENT)
	$(call require_component,plan)
	@cd $(TF_COMPONENT) && terraform plan -out=tfplan

.PHONY: apply
apply: ## Apply saved tfplan (require COMPONENT). Run plan first
	$(call require_component,apply)
	@cd $(TF_COMPONENT) && terraform apply tfplan

.PHONY: apply-auto
apply-auto: ## Apply -auto-approve (DANGEROUS, lab/dev only)
	$(call require_component,apply-auto)
	@cd $(TF_COMPONENT) && terraform apply -auto-approve

.PHONY: destroy
destroy: ## Destroy with manual confirm (require COMPONENT)
	$(call require_component,destroy)
	@printf "$(RED)⚠ Destroy $(COMPONENT)? Enter to continue, Ctrl+C to abort$(RESET) "
	@read _
	@cd $(TF_COMPONENT) && terraform destroy

.PHONY: fmt
fmt: ## terraform fmt -recursive toàn repo
	@terraform fmt -recursive $(TF_DIR)
	@printf "$(GREEN)✓ Formatted$(RESET)\n"

.PHONY: fmt-check
fmt-check: ## Check fmt without modify (CI)
	@terraform fmt -recursive -check -diff $(TF_DIR) || \
		(printf "$(RED)✗ Files not formatted. Run: make fmt$(RESET)\n"; exit 1)

.PHONY: validate
validate: ## terraform validate (require COMPONENT)
	$(call require_component,validate)
	@cd $(TF_COMPONENT) && terraform validate

.PHONY: output
output: ## Show outputs (require COMPONENT)
	$(call require_component,output)
	@cd $(TF_COMPONENT) && terraform output

.PHONY: state-list
state-list: ## List resources in state (require COMPONENT)
	$(call require_component,state-list)
	@cd $(TF_COMPONENT) && terraform state list

.PHONY: clean
clean: ## Remove .terraform cache + tfplan (all sub-comps)
	@find $(TF_DIR) -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find $(TF_DIR) -type f -name "tfplan" -delete 2>/dev/null || true
	@find $(TF_DIR) -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@printf "$(GREEN)✓ Cleaned cache + plan files$(RESET)\n"

.PHONY: list-components
list-components: ## List all sub-component folders
	@ls -d $(TF_DIR)/*/ 2>/dev/null | sed 's|$(TF_DIR)/||;s|/$$||'
