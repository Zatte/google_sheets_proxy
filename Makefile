# Google Cloud
GCP_PROJECT?=tbd

# App specific
APP_NAME?=$(notdir $(shell pwd))
GITHUB_NAME?=$(shell cat go.mod | grep module | cut -d" " -f2)

# Docker
IMAGE=$(REGISTRY)/$(GITHUB_NAME)
REGISTRY?=eu.gcr.io/$(GCP_PROJECT)

# Builder settings
USE_DOCKER?=false
BUILD_TOOLS_VERSION=v8.4.3
BUILDER_IMAGE=gobuilder

PROTOC_VERSION_TAG=v1.3.1
GOPATH?=$(go env GOPATH)

GCP_CLUSTER?=standard-cluster-1

SERVICE_ACC_NAME=$(subst _,-,$(APP_NAME))
SERVICE_ACC_EMAIL=$(SERVICE_ACC_NAME)@$(GCP_PROJECT).iam.gserviceaccount.com 

# Build version
SHORT_SHA?=$(shell git rev-parse --short HEAD)
MAYBE_TAG?=$(shell git describe --exact-match --abbrev=0 --tags ${SHORT_SHA} 2> /dev/null|| echo $(SHORT_SHA))
VERSION?=$(MAYBE_TAG)$(shell if [ -n "\\$(git diff --shortstat 2> /dev/null | tail -n1)" ]; then echo "-dirty-$(SHORT_SHA)" ; fi)

# Go configs
ifeq ($(USE_DOCKER),false)
GOCMD=CGO_ENABLED=0 GOOS=linux go
LINTCMDROOT=CGO_ENABLED=0 GOOS=linux
else
GOCMD=docker run -it -e TAG_NAME="$(TAG_NAME)" -e SHORT_SHA="$(SHORT_SHA)"  -e CGO_ENABLED=0 -e GOOS=linux -e APP_NAME="$(APP_NAME)" --rm -w /go/in -v $(CURDIR):/go/in $(BUILDER_IMAGE) go
LINTCMDROOT=docker run -it --rm -w /go/in -v $(CURDIR):/go/in $(BUILDER_IMAGE)
endif

sa:
	$(SERVICE_ACC_NAME)

# Vendoring
# =======================
.PHONY: vendor
vendor: go.mod
	$(GOCMD) mod tidy
	$(GOCMD) mod vendor

.PHONY: vendor
vendor-commit: vendor
	git add ./vendor
	git commit -m "go mod & vendor"

# Testing
# =======================
.PHONY: lint
lint:
	$(LINTCMDROOT) golangci-lint "--config=./build/.golangci.yaml" run --fix

.PHONY: test
test: lint vendor test_all
	pass

.PHONY: test_all
test_all: test_unit test_integration
	pass

test_integration:
	$(GOCMD) test ./... -count=1 -tags=integration

test_unit:
	$(GOCMD) test ./... -count=1

# Building
# =======================
.PHONY: image_repository
image_repository:
	@echo $(IMAGE)

.PHONY: version
version:
	@echo $(VERSION)

.PHONY: build
build:
	$(GOCMD) build -ldflags "-X main.Version=$(VERSION) -X main.Name=$(APP_NAME)" -o ./dist/go-app ./

.PHONY: image
image:
	@echo "Building $(IMAGE):$(VERSION)"
	@docker build --build-arg=VERSION=$(VERSION) -f build/Dockerfile -t $(IMAGE):$(VERSION) .
	@docker tag $(IMAGE):$(VERSION)  $(IMAGE):latest


# Running
# =======================
run:
	$(GOCMD) run -ldflags "-X main.Version=$(VERSION) -X main.Name=$(APP_NAME)" ./

# Release
# =======================
.PHONY: push
push: image
	@echo "Pushing $(IMAGE):$(VERSION)"
	@docker push $(IMAGE):$(VERSION)

# Deploying
# =======================
.PHONY: deploy-gcp-cloud-run
deploy-gcp-cloud-run: #push
	gcloud run deploy $(APP_NAME)k8 --image $(IMAGE):$(VERSION) \
	    --project=$(GCP_PROJECT) \
		--platform managed \
		--max-instances=10 \
		--memory=128Mi \
		--update-env-vars $(shell cat deploy.env | sed 's/export //g' | tr '\n' ',') \
		--service-account  $(SERVICE_ACC_EMAIL) \
		--allow-unauthenticated \
		--region=europe-north1

		# --cluster GCP_CLUSTER \
		# --platform gke

deploy-gcp-cloud-function: 
	gcloud functions deploy GoogleSheetProxy \
		--runtime go113 \
		--trigger-http \
		--allow-unauthenticated \
		--region=europe-west3 \
		--set-env-vars SALT=$(shell cat secretSalt),SVC_ACC_EMAIL=service-$(GCP_PROJECT)@gcf-admin-robot.iam.gserviceaccount.com 
		

# Cleaing
# =======================
clean:
	@$(GOCMD) clean
	@$(GOCMD) clean -modcache
	@rm -rf ./dist/* 2> /dev/null

distclean: clean
	@rm -rf vendor

## Create an service account for this server without any permissions
service-account:
	gcloud iam service-accounts create $(SERVICE_ACC_NAME) \
    --description="service account for the $(APP_NAME) service" \
    --display-name="Service account for $(APP_NAME)" \
	  --project $(GCP_PROJECT)
	

#
# Development env setup
# =======================
dev-builderimg:
	@docker build -t $(BUILDER_IMAGE) -f build/Dockerfile --target BuildEnv .


