# Makefile for the Terraform AWS + Docker project.
# Usage: run `make <target>` from the repo root.
# All terraform commands run inside ./terraform and read ./terraform/terraform.tfvars.

TF_DIR       := terraform
TF           := terraform
VAR_FILE     := terraform.tfvars
VAR_PATH     := $(TF_DIR)/$(VAR_FILE)
SSH_KEY_PATH := $(HOME)/.ssh/$(shell grep -E '^\s*key_name' $(VAR_PATH) | awk '{print $$3}' | tr -d '"').pem

.PHONY: help init fmt validate plan apply apply-force output state destroy destroy-force ssh local-test

help:
	@echo "Targets: init | fmt | validate | plan | apply | apply-force | output | state | destroy | destroy-force | ssh | local-test"

guard-vars:
	@test -f $(VAR_PATH) || (echo "ERROR: $(VAR_PATH) not found. Run: cp $(TF_DIR)/terraform.tfvars.example $(VAR_PATH) and fill it in."; exit 1)

init: guard-vars
	cd $(TF_DIR) && $(TF) init

fmt:
	cd $(TF_DIR) && $(TF) fmt -recursive

validate: init
	cd $(TF_DIR) && $(TF) validate

plan: init
	cd $(TF_DIR) && $(TF) plan -var-file=$(VAR_FILE)

apply: init
	cd $(TF_DIR) && $(TF) apply -var-file=$(VAR_FILE)

# Non-interactive variant for CI / scripts
apply-force: init
	cd $(TF_DIR) && $(TF) apply -auto-approve -var-file=$(VAR_FILE)

output:
	cd $(TF_DIR) && $(TF) output

state:
	cd $(TF_DIR) && $(TF) state list

destroy:
	cd $(TF_DIR) && $(TF) destroy -var-file=$(VAR_FILE)

# Non-interactive variant - destroys everything, use with care!
destroy-force:
	cd $(TF_DIR) && $(TF) destroy -auto-approve -var-file=$(VAR_FILE)

ssh:
	@test -f $(SSH_KEY_PATH) || (echo "ERROR: key $(SSH_KEY_PATH) not found."; exit 1)
	ssh -i $(SSH_KEY_PATH) -o StrictHostKeyChecking=no ubuntu@$(shell cd $(TF_DIR) && $(TF) output -raw public_ip)

# Run the app locally with Docker (no AWS involved)
local-test:
	docker build -t terraform-demo-app ./app
	docker run --rm -p 3000:3000 --name terraform-demo-app terraform-demo-app
