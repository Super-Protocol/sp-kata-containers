#!/bin/bash
apt-get update

DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends skopeo umoci jq