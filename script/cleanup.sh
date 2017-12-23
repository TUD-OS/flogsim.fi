#!/bin/bash

squeue -u $USER -o "%A %j" | grep faults_server.sh | cut -d' ' -f1 | xargs scancel
