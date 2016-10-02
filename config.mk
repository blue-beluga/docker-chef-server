# encoding: UTF-8

GIT_REVISION=$(shell git rev-parse --short HEAD)

FROM = ubuntu:14.04
REGISTRY = docker.io
REPOSITORY = bluebeluga/chef-server

PUSH_REGISTRIES = $(REGISTRY)
