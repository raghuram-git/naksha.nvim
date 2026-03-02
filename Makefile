# Makefile
PROTO_DIR=backend/proto
GEN_DIR=backend/generated

all: build

build:
	cd backend && go build -o ../bin/db_server .
