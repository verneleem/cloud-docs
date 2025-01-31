#!/bin/bash

set -e

GREEN='\033[32;1m'
RESET='\033[0m'

run() {
  export CURRENT_BRANCH="master"
  export CURRENT_VERSION="preview"
  export HUGO_TITLE="Dgrah Doc - Preview"
  export VERSIONS="preview"
  export DGRAPH_ENDPOINT=${DGRAPH_ENDPOINT:-"https://play.dgraph.io/query?latency=true"}

  pushd "$(dirname "$0")/.." > /dev/null
  pushd themes > /dev/null

  if [ ! -d "hugo-docs" ]; then
    echo -e "$(date) $GREEN Hugo-docs repository not found. Cloning the repo. $RESET"
    git clone https://github.com/verneleem/hugo-docs.git
  else
    echo -e "$(date) $GREEN Hugo-docs repository found. Pulling the latest version from master. $RESET"
    pushd hugo-docs > /dev/null
    git checkout master
    git pull
    popd > /dev/null
  fi
  popd > /dev/null

  if [[ $1 == "-p" || $1 == "--preview" ]]; then
    echo -e "$(date) $GREEN Generating documentation static pages in the public folder. $RESET"
    hugo --destination=public --baseURL="$2" 1> /dev/null
    echo -e "$(date) $GREEN Done building. $RESET"
  else
    hugo server -w --baseURL=http://localhost:1313
  fi
  popd > /dev/null
}

run "$1" "$2"
