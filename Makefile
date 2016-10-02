# encoding: UTF-8

# Determines whether the output is in color or not. To disable, set this to 0.
USE_COLOR = 1

ifeq ($(CURDIR),)
  CURDIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
endif

ifndef PLATFORM
  PLATFORM := $(shell uname | tr A-Z a-z)
endif

# Load the latest tag, and set a default for TAG. The goal here is to ensure
# TAG is set as early possible, considering it's usually provided as an input
# anyway, but we want running "make" to *just work*.
include latest.mk

ifndef LATEST_TAG
	$(error LATEST_TAG *must* be set in latest.mk)
endif

ifeq "$(TAG)" "latest"
  override TAG = $(LATEST_TAG)
endif

TAG ?= $(LATEST_TAG)

# Import configuration. config.mk must set the variables REGISTRY and
# REPOSITORY so the Makefile knows what to call your image. You can also set
# PUSH_REGISTRIES and PUSH_TAGS to customize what will be pushed. Finally, you
# can set any variable that'll be used by your build process, but make sure you
# export them so they're visible in build programs!
include config.mk

ifndef REGISTRY
	$(error REGISTRY *must* be set in config.mk)
endif

ifndef REPOSITORY
	$(error REPOSITORY *must* be set in config.mk)
endif

# Create $(TAG)/config.mk if you need to e.g. set environment variables
# depending on the tag being built. This is typically useful for things
# constants like a point version, a sha1sum, etc. (note that $(TAG)/config.mk
# is entirely optional).
-include versions/$(TAG)/config.mk

# By default, we'll push the tag we're building, and the 'latest' tag if said
# tag is indeed the latest one. Set PUSH_TAGS in config.mk (or $(TAG)/config.mk)
# to override that behavior (note: you can't override the 'latest' tag).
PUSH_TAGS ?= $(TAG)

ifeq "$(TAG)" "$(LATEST_TAG)"
  PUSH_TAGS += latest
endif

# By default, we'll push the registry we're naming the image after. You can
# override this in config.mk (or $(TAG)/config.mk)
PUSH_REGISTRIES ?= $(REGISTRY)

# Export what we're building for e.g. test scripts to use. Exporting other
# variables is the responsibility of config.mk and $(TAG)/config.mk.
export GIT_REVISION := $(shell git rev-parse --short HEAD)
export REPOSITORY
export REGISTRY
export FROM
export TAG

ifneq ($(USE_COLOR),0)
  YL = \033[0;33m
  GR = \033[0;32m
  RD = \033[0;31m
  MG = \033[0;35m
  CY = \033[0;36m
  NC = \033[0m
endif

HELP_FMT := 'make $(YL)%-15s $(NC)\# %s\n'

# Provide a way to shorten build arguments below.
IMAGE_NAME = $(REPOSITORY):$(TAG)
REPO = $(REPOSITORY)
REG  = $(REGISTRY)
#
# ******************************************************************************
# Define the actual usable targets.
#
help::
	@printf $(HELP_FMT) 'task' 'Shows the current task info.'
task::
	@printf "$(YL)-----------------------------------------------------------\n"
	@printf "$(CY)%14s $(YL): $(GR)%-15s $(CY)%8s $(YL): $(GR)%-14s\n" \
							"Repository" $(REPOSITORY) "Tag" $(TAG)
	@printf "$(CY)%14s $(YL): $(GR)%-15s $(CY)%8s $(YL): $(GR)%-14s\n" \
							"Registry" $(REGISTRY) "Target" $(MAKECMDGOALS)
	@printf "$(YL)-----------------------------------------------------------\n"
.PHONY:: task

help::
	@printf $(HELP_FMT) 'push' 'Push image or a repository to the registry'
push:: task build test
	for registry in $(PUSH_REGISTRIES); do \
		for tag in $(PUSH_TAGS); do \
			docker tag "$(REG)/$(REPO):$(TAG)" "$${registry}/$(REPO):$${tag}"; \
			docker push "$${registry}/$(REPO):$${tag}"; \
		done \
	done
.PHONY:: push

help::
	printf $(HELP_FMT) 'test' 'Run automated tests on one or more instances'
test:: task build
	set -e; if [ -f 'test/run.bats' ]; then bats -t test/run.bats; break; fi
.PHONY:: test

help::
	printf $(HELP_FMT) 'build' 'Build an image from a Dockerfile'
build:: task stop .render .build
.PHONY:: build .build

.build:: . $(DEPS)
	docker pull $(FROM)
	docker build -t "$(REG)/$(REPO):$(TAG)" -f "versions/$(TAG)/Dockerfile" .
	docker inspect -f '{{.Id}}' $(REG)/$(REPO):$(TAG) > "versions/$(TAG)/.build"
ifeq "$(TAG)" "$(LATEST_TAG)"
	docker tag "$(REG)/$(REPO):$(TAG)" "$(REG)/$(REPO):latest"
endif

help::
	printf $(HELP_FMT) 'stop' 'Gracefully stop a running container'
stop:: task
ifneq ($(strip $(shell docker ps -aqf ancestor=$(IMAGE_NAME))),)
	docker ps -aqf ancestor=$(IMAGE_NAME) | xargs docker stop
endif
.PHONY:: stop

help::
	printf $(HELP_FMT) 'clean' 'Stop and remove build artifacts and images'
clean:: task stop
	rm -f .render .build Dockerfile
	docker images -qa "$(REPO):$(TAG)" | xargs docker rmi -f
	docker images -qa "$(REPO):latest" | xargs docker rmi -f

# Per-tag Dockerfile target. Look for Dockerfile or Dockerfile.erb in the root,
# and use it for $(TAG). We prioritize Dockerfile.erb over Dockerfile if both
# are present.
.render: $(TAG) Dockerfile.erb Dockerfile
ifneq (,$(wildcard Dockerfile.erb))
	erb "Dockerfile.erb" > "versions/$(TAG)/Dockerfile"
else
	cp "Dockerfile" > "versions/$(TAG)/Dockerfile"
endif

# Pseudo targets for Dockerfile and Dockerfile.erb. They don't technically
# create anything, but each warn if the other file is missing (meaning both
# files are missing).
Dockerfile.erb:
ifneq (,$(wildcard Dockerfile.erb))
	$(warning You must create a Dockerfile.erb or Dockerfile)
endif

Dockerfile:
ifneq (,$(wildcard Dockerfile))
	$(warning You must create a Dockerfile.erb or Dockerfile)
endif

$(TAG):
	mkdir -p "versions/$(TAG)"

# list of dependancies in the build context
DEPS = $(shell find versions/$(TAG) -type f -print)

.PHONY:: push test build stop
.DEFAULT_GOAL := test
