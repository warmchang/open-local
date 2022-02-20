
# go parameters
GO_CMD=go
GO_BUILD=$(GO_CMD) build
GO_TEST=$(GO_CMD) test -v
GO_PACKAGE=github.com/alibaba/open-local

# build info
NAME=open-local
OUTPUT_DIR=./bin
IMAGE_NAME=ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/${NAME}
MAIN_FILE=./cmd/main.go
LD_FLAGS=-ldflags "-X '${GO_PACKAGE}/pkg/version.GitCommit=$(GIT_COMMIT)' -X '${GO_PACKAGE}/pkg/version.Version=$(VERSION)' -X 'main.VERSION=$(VERSION)' -X 'main.COMMITID=$(GIT_COMMIT)'"
GIT_COMMIT=$(shell git rev-parse HEAD)
VERSION=v0.5.1

CRD_OPTIONS ?= "crd:trivialVersions=true"
CRD_VERSION=v1alpha1

# build binary
all: test fmt vet build

.PHONY: test
test:
	$(GO_TEST) ./...

.PHONY: build
build:
	GO111MODULE=off CGO_ENABLED=0 $(GO_BUILD) $(LD_FLAGS) -v -o $(OUTPUT_DIR)/$(NAME) $(MAIN_FILE)

.PHONY: develop
develop:
	GOARCH=amd64 GOOS=linux GO111MODULE=off CGO_ENABLED=0 $(GO_BUILD) $(LD_FLAGS) -v -o $(OUTPUT_DIR)/$(NAME) $(MAIN_FILE)
	docker build . -t ${IMAGE_NAME}:${VERSION} -f ./Dockerfile.dev

# build image
.PHONY: image
image:
	docker build . -t ${IMAGE_NAME}:${VERSION} -f ./Dockerfile

# build image for arm64
.PHONY: image-arm64
image-arm64:
	docker build . -t ${IMAGE_NAME}:${VERSION}-arm64 -f ./Dockerfile.arm64

# generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	GO111MODULE=off ./hack/update-codegen.sh
	GO111MODULE=off $(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role crd paths="./pkg/apis/storage/$(CRD_VERSION)/..." output:crd:artifacts:config=helm/crds/

.PHONY: fmt
fmt:
	go fmt ./...
.PHONY: vet
vet:
	go vet `go list ./... | grep -v /vendor/`

# find or download controller-gen
# download controller-gen if necessary
controller-gen:
ifeq (, $(shell which controller-gen))
	go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.5.0
CONTROLLER_GEN=$(shell go env GOPATH)/bin/controller-gen
else
CONTROLLER_GEN=$(shell which controller-gen)
endif
