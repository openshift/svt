
IMAGE_NAME = s2i-stac-builder
#STAC_CONFIG = https://github.com/<github-username>/<stac-config-repo-name>.git 

.PHONY: build
build:
	docker build -q --build-arg github_url_stac_config=$(STAC_CONFIG) -t $(IMAGE_NAME) .

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
