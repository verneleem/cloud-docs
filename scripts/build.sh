#!/bin/bash
# This script runs in a loop (configurable with LOOP), checks for updates to the
# Hugo docs theme or to the docs on certain branches and rebuilds the public
# folder for them. It has be made more generalized, so that we don't have to
# hardcode versions.

# Warning - Changes should not be made on the server on which this script is running
# becauses this script does git checkout and merge.

set -e

# Important for clean builds on Netlify
if ! git remote | grep -q origin ; then
    git remote add origin https://github.com/verneleem/cloud-docs.git
    git fetch --all
fi

GREEN='\033[32;1m'
BLUE='\034[32;1m'
RESET='\033[0m'
HOST="${HOST:-https://dgraph.io/docs/slash-graphql}"
# Name of output public directory
PUBLIC="${PUBLIC:-public}"
# LOOP true makes this script run in a loop to check for updates
LOOP="${LOOP:-true}"
# Binary of hugo command to run.
HUGO="${HUGO:-hugo}"
THEME_BRANCH="${THEME_BRANCH:-master}"

# TODO - Maybe get list of released versions from Github API and filter
# those which have docs.

# Place the latest version at the beginning so that version selector can
# append '(latest)' to the version string, followed by the master version,
# and then the older versions in descending order, such that the
# build script can place the artifact in an appropriate location.
VERSIONS_ARRAY=(
	'master'
)

joinVersions() {
	versions=$(printf ",%s" "${VERSIONS_ARRAY[@]}")
	echo "${versions:1}"
}

function version { echo "$@" | gawk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }'; }

rebuild() {
	echo -e "$(date) $GREEN Updating docs for branch: $1.$RESET"

	# The latest documentation is generated in the root of /public dir
	# Older documentations are generated in their respective `/public/vx.x.x` dirs
	dir=''
	if [[ $2 != "${VERSIONS_ARRAY[0]}" ]]; then
		dir=$2
	fi
	echo -e "$BLUE dir: $dir $RESET"

	VERSION_STRING=$(joinVersions)
	# In Unix environments, env variables should also be exported to be seen by Hugo
	export CURRENT_BRANCH=${1}
	export CURRENT_VERSION=${2}
	export VERSIONS=${VERSION_STRING}
	
	HUGO_TITLE="Dgraph Doc ${2}"\
		VERSIONS=${VERSION_STRING}\
		CURRENT_BRANCH=${1}\
		CURRENT_VERSION=${2} ${HUGO} \
		--destination="${PUBLIC}"/"$dir"\
		--baseURL="$HOST"/"$dir" 1> /dev/null

	echo -e "$BLUE VERSION_STRING: $VERSION_STRING $RESET"
	echo -e "$BLUE CURRENT_BRANCH: $CURRENT_BRANCH $RESET"
	echo -e "$BLUE CURRENT_VERSION: $CURRENT_VERSION $RESET"
	echo -e "$BLUE VERSIONS: $VERSIONS $RESET"
	echo -e "$BLUE HUGO_TITLE: $HUGO_TITLE $RESET"
	echo -e "$BLUE destination: $PUBLIC/$dir $RESET"
	echo -e "$BLUE baseURL: $HOST/$dir $RESET"
}

branchUpdated()
{
	echo -e "$BLUE branch: $1 $RESET"
	echo -e "$BLUE UPSTREAM: $(git rev-parse '@{u}') $RESET"
	echo -e "$BLUE LOCAL: $(git rev-parse '@') $RESET"
	local branch="$1"
	git checkout -q "$1"
	UPSTREAM=$(git rev-parse "@{u}")
	LOCAL=$(git rev-parse "@")

	if [ "$LOCAL" != "$UPSTREAM" ] ; then
		git merge -q origin/"$branch"
		return 0
	else
		return 1
	fi
}

publicFolder()
{
	dir=''
	if [[ $1 == "${VERSIONS_ARRAY[0]}" ]]; then
		echo "${PUBLIC}"
	else
		echo "${PUBLIC}/$1"
	fi
}

checkAndUpdate()
{
	local version="$1"
	local branch=""
	echo -e "$BLUE version: $1 $version"
	echo -e "$BLUE branch: $1 $branch"

	branch="master"

	if branchUpdated "master" ; then
		git merge -q origin/"$branch"
		rebuild "master" "$version"
	fi

	folder=$(publicFolder "$version")
	if [ "$firstRun" = 1 ] || [ "$themeUpdated" = 0 ] || [ ! -d "$folder" ] ; then
		rebuild "$branch" "$version"
	fi
}


firstRun=1
while true; do
	# Lets move to the docs directory.
	pushd "$(dirname "$0")/.." > /dev/null

	currentBranch=$(git rev-parse --abbrev-ref HEAD)
	echo -e "$BLUE currentBranch: $currentBranch $RESET"

	if [ "$firstRun" = 1 ];
	then
		# clone the hugo-docs theme if not already there
		[ ! -d 'themes/hugo-docs' ] && git clone https://github.com/verneleem/hugo-docs themes/hugo-docs
	  echo -e "$BLUE Cloned verneleem/hugo-docs repo into themes/hugo-docs $RESET"
	fi

	# Lets check if the theme was updated.
	pushd themes/hugo-docs > /dev/null
	git remote update > /dev/null
	themeUpdated=1
	if branchUpdated "master" ; then
		echo -e "$GREEN Theme has been updated. Now will update the docs.$RESET"
		themeUpdated=0
	fi
	popd > /dev/null

	echo -e "$(date)  Starting to check master branch."
	git remote update > /dev/null

	checkAndUpdate "master"

	echo -e "$(date)  Done checking master branch.\n"

	git checkout -q "$currentBranch"
	popd > /dev/null

	firstRun=0
  if ! $LOOP; then
    exit
  fi
	sleep 60
done