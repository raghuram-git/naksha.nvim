# Makefile
all: build

build:
	cd backend && go build -o ../bin/db_server .

clean:
	rm -rf bin/
