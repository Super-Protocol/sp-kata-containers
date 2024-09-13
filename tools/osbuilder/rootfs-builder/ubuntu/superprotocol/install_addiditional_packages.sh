#!/bin/bash

apt update

DEBIAN_FRONTEND=noninteractive apt install $1 --no-install-recommends -y
