# Copyright 2024 Flavien Solt and Matej Bölcskei, ETH Zurich.
# Licensed under the General Public License, Version 3.0, see LICENSE for details.
# SPDX-License-Identifier: GPL-3.0-only

IMAGE_NAME := ethcomsec/encarsia-artifacts:latest
# Ensure the specified path has at least 3TB of available storage for the buggy designs
OUT_DIRECTORY := ./out
ENCORPUS_DIRECTORY := $(OUT_DIRECTORY)/EnCorpus

unpack_encorpus:
	mkdir -p $(ENCORPUS_DIRECTORY)
	tar -xvf EnCorpus_boom.tar.gz -C $(ENCORPUS_DIRECTORY)
	tar -xvf EnCorpus_ibex.tar.gz -C $(ENCORPUS_DIRECTORY)
	tar -xvf EnCorpus_rocket.tar.gz -C $(ENCORPUS_DIRECTORY)

pull:
	docker pull $(IMAGE_NAME)

build:
	docker build -t $(IMAGE_NAME) . 2>&1 | tee build.log

run:
	docker run -it -v $(OUT_DIRECTORY):/encarsia-meta/out $(IMAGE_NAME)

run_temp:
	docker run -it -v $(OUT_DIRECTORY):/encarsia-meta/out --rm $(IMAGE_NAME)

push:
	docker login registry-1.docker.io
	docker push $(IMAGE_NAME)