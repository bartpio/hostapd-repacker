#!/bin/bash
docker build --secret id=pushkey,src=/home/bellman/.ssh/id_rsa .

