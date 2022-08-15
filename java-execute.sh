#!/bin/bash
export PATH=/home/ubuntu/starcoin-ubuntu-18.04/starcoin-artifacts:$PATH
cd /home/ubuntu/kikoverse/move/kikoverse-contract-move
move clean
echo "excute clean"
move check
echo "excute check"
move publish
echo "excute publish"