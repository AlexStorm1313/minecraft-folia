.PHONY: build run

NAMESPACE=minecraft-folia
TARGET=release
TAG=latest

build:
	@podman build --ssh default --file Containerfile --tag localhost/$(NAMESPACE):$(TAG)
	@podman image tree localhost/$(NAMESPACE):$(TAG)

run:
	@podman run --rm -it -p 3000:3000 localhost/$(NAMESPACE):$(TAG)