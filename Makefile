.PHONY: help install test

.DEFAULT: help
ifndef TZ
export TZ=Australia/Sydney
endif

SHELL=/bin/bash
DOCKER_IMAGE=psfn/build-agent
AWS_REGION ?= ap-east-1

# default target
#COLORS
GREEN  := $(shell [[ -t 0 ]] && tput -Txterm setaf 2)
WHITE  := $(shell [[ -t 0 ]] && tput -Txterm setaf 7)
YELLOW := $(shell [[ -t 0 ]] && tput -Txterm setaf 3)
RESET  := $(shell [[ -t 0 ]] && tput -Txterm sgr0)

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
# A category can be added with @category
HELP_FUN = \
    %help; \
    while(<>) { push @{$$help{$$2 // 'main'}}, [$$1, $$3] if /^([a-zA-Z0-9\-\_\%]+)\s*:.*\#\#(?:@([a-zA-Z0-9\-\_\%]+))?\s(.*)$$/ }; \
    print "usage: make [target]\n\n"; \
    for (sort keys %help) { \
    print "${WHITE}$$_:${RESET}\n"; \
    for (@{$$help{$$_}}) { \
    $$sep = " " x (60 - length $$_->[0]); \
    print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; \
    }; \
    print "\n"; }

help:  ##@other Show this help.
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

#
## docker targets
#

docker-build: set-docker-build-vars  ##@docker Build Docker image via Dockerfile.
	@docker build \
		-t ${DOCKER_IMAGE} \
    --build-arg AWS_CLI_ZIP=awscli-exe-linux-${OS_ARCH}.zip \
    --build-arg HW_PLATFORM=${HW_PLATFORM} \
    --no-cache .

docker-shell: set-docker-env-vars print-env-vars  ##@docker Run docker container shell.
	@docker run \
		--rm \
    -it \
    ${DOCKER_ENV_VARS} \
    -v $(HOME)/.ssh:/.ssh \
    -v $(HOME)/.aws:/root/.aws \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(CURDIR):/project \
    -w /project \
    --entrypoint /bin/bash \
    ${DOCKER_IMAGE}



#
## helpers
#

set-docker-build-vars:
ifeq ($(shell uname -m),arm64)
    OS_ARCH=aarch64
    HW_PLATFORM=arm64
else
    OS_ARCH=x86_64
    HW_PLATFORM=amd64
endif

set-docker-env-vars:
VARS := AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
ENV_VARS := TZ
DOCKER_ENV_VARS := -e TZ=${TZ}
define add_vars
ifdef ${VAR}
    ENV_VARS := ${ENV_VARS} ${VAR}
    DOCKER_ENV_VARS := ${DOCKER_ENV_VARS} -e ${VAR}=${${VAR}}
endif
endef
$(foreach VAR, ${VARS}, $(eval $(call add_vars, $VAR)))

print-env-vars:
	@echo "Environment variables"
	@echo "----------------------------------"
	@IFS=' ' read -r -a env_vars <<< "${ENV_VARS}"; \
	for var in "$${env_vars[@]}"; do \
		echo "$${var}=$${!var}"; \
	done
