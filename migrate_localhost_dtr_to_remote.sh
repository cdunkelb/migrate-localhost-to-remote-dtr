#!/usr/bin/env bash
# set -x

## Contributors: jimc, ada, steven.showers@docker.com

REPLICA_ID=$(docker inspect $(docker ps -aq -f name=dtr-registry) | grep DTR_REPLICA_ID | awk -F '=' '{print $2}' | tr -d '",')

# We need to make sure we have jq installed

if [ -z "$(command -v jq)" ]; then
    echo -en "\njq will need to be installed\nPlease navigate to: https://stedolan.github.io/jq/\n"
    exit 1
fi

# We'll need to run as root to build the list.

if [ $EUID != 0 ]; then
    WORKDIR=$(pwd)
    echo -en "\nScript not executed as root.\nRestarting with 'sudo'\n"
    echo -en "\nNote: If this does not work as expected, please execute script as root.\n"
    chmod +x "$0" "$@"
    sudo "PATH=$PATH" bash ${WORKDIR}/"$0" "$@"
    exit $?
fi

# This is only going to work in BASH.
shellcheck(){ ps auxww | grep $$ | grep -wq "bash"; echo $?; }

if [ $(shellcheck) = 1 ]; then
   echo -en "\nThis script must be executed with BASH.\n"
   echo -en "\nPlease run as follows: bash <script-file>\n"
   echo -en "\nExiting...\n"
   exit 1
fi

# Prompt user for DTR URL.
# Would be helpful to automatically remove "https" if provided.
read -p "Enter your DTR URL: " DTR_URL

# Strip http:// or https://
DTR_URL=$(echo $DTR_URL | sed 's~http[s]*://~~g')

# Request username and password for auth token below.
read -p "Enter UCP username: " ADMIN
read -sp "Enter UCP password: " PASSWORD

## If we don't have any dtr-registry containers, then we'll need to grab the replica ID from volumes.
if [ -z $(docker ps -aq -f name=dtr-) ]; then
    echo -en "\nNo DTR containers found.\nSee this article: https://success.docker.com/article/how-do-i-recover-a-dtr-230-node-when-all-containers-have-been-removed\n"
    exit 1
fi

# Building the list we'll need.
build_list() {
    MOUNT=$(docker volume inspect dtr-registry-$REPLICA_ID -f '{{.Mountpoint}}')
    REPO_DIR=${MOUNT}/docker/registry/v2/repositories
    NAMES=$(ls -1 ${MOUNT}/docker/registry/v2/repositories)
    REPO=$(for i in `echo ${NAMES}`; do ls -1 -d ${REPO_DIR}/${i}/*; done)
    for i in `echo ${NAMES}`; do
        ls -1 -d ${REPO_DIR}/${i}/*
    done | awk -F\/ '{print $(NF-1),$(NF)}' | tr ' ' '/' >> create-dtr-repos.list
}

build_list

BEARER_TOKEN=$(curl -kLsS -u $ADMIN:$PASSWORD "https://$DTR_URL/auth/token" | jq -r .token)
CURLOPTS=(-kLsS -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${BEARER_TOKEN}")

# echo $BEARER_TOKEN
for repo in $(cat ./create-dtr-repos.list); do
  echo $repo | awk -F/ '{print $1} {print $2}' | while read -r namespace; do
    read -r name
    echo "creating repo for namespace: $namespace and repo: $name"
    curl "${CURLOPTS[@]}" -X POST "https://${DTR_URL}/api/v0/repositories/${namespace}" -d "{  \"enableManifestLists\": true,  \"immutableTags\": true,  \"longDescription\": \"string\",  \"name\": \"${name}\",  \"scanOnPush\": true,  \"shortDescription\": \"string\",  \"visibility\": \"public\"}"
  done
done




##  jimc's version:

# 1) navigate to the appropriate storage TLD:

# cd /var/lib/docker/volumes/$(docker volume ls -qf name=dtr-registry)/_data/docker/registry/v2/repositories/

# 2) grind on the namespace/repo combinations:
# for NS in $( ls ); do \
# cd $NS \
# for REPO in $( ls ); do \
# curl -k -X POST --user admin:PASSWORD --header "Content-Type: application/json" --header "Accept: application/json" \
# --header "X-Csrf-Token: ###YOUR_API_TOKEN###" -d "{\
# \"name\": \"$REPO\",\
# \"shortDescription\": \"$REPO\",\
# \"longDescription\": \"$REPO\",\
# \"visibility\": \"public\",\
# \"scanOnPush\": true,\
# \"immutableTags\": true,\
# \"enableManifestLists\": true\
# }" "https://##DTR_URL##/api/v0/repositories/$NS"\
# ;done;cd ..;done;
