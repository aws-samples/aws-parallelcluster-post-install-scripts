#!/bin/bash

set -x
set -e

# Copy Slurm REST API configuration files and scripts
tmp_dir=/tmp/slurm_rest_api
mkdir -p $tmp_dir

source_path=https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/rest-api
files=(slurmrestd.service slurm_rest_api.rb nginx.conf)
for file in "${files[@]}"
do
    wget -qO- $source_path/$file > $tmp_dir/$file
done

rotate_jwt_path=/opt/parallelcluster/scripts/rotate_jwt.sh
wget -qO- $source_path/rotate_jwt.sh > $rotate_jwt_path
chmod +x $rotate_jwt_path

# Setup Slurm REST API
sudo cinc-client \
  --local-mode \
  --config /etc/chef/client.rb \
  --log_level auto \
  --force-formatter \
  --chef-zero-port 8889 \
  -j /etc/chef/dna.json \
  -z $tmp_dir/slurm_rest_api.rb

set +e
