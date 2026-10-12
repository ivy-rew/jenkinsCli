#!/bin/bash  
JOB=ivy-core_product
if [ ! -z "$2" ]; then
  JOB=$2
fi

JENKINS=$1
BRANCH=$3
ARTIFACT=$4
ARTIFACT_PATTERN=$5

DATA_DIRECTORY=~/Downloads

DIR="$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )"
ENV="$DIR/.env"
if [ -f $ENV ]; then
  . $ENV
fi

openDir(){
  local UNPACKED="$1"
  if [ -x "$(command -v gtk-launch )" ]; then
    gtk-launch "$(xdg-mime query default inode/directory)" "$UNPACKED" & #DEBIAN
  elif [ -x "$(command -v open )" ]; then
    open "$UNPACKED" & # Mac OSX
  elif [ -x "$(command -v explorer )" ]; then
    WINDIR=$(echo $UNPACKED | sed 's|/c|C:|' | sed 's|/|\\|g')
    explorer "$WINDIR" & # Good old windows
  fi
}

jenkinsSuccessUrl(){
  local job="$1"
  local branch="$2"
  local jenkins="${3:-jenkins.ivyteam.io}"
  printf 'https://%s/job/%s/job/%s/lastSuccessfulBuild' "$jenkins" "$job" "$branch"
}

jenkinsDownload(){
  local url="$1"
  local destination="$2"
  if command -v wget >/dev/null 2>&1; then
    wget "$url" -O "$destination"
  elif command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error "$url" -o "$destination"
  else
    echo 'Error: this script requires wget or curl.' >&2
    return 1
  fi
}

jenkinsGet (){
  SUCCESS_URL=$(jenkinsSuccessUrl "$JOB" "$BRANCH" "$JENKINS")
  JSON=$(curl -s "$SUCCESS_URL/api/json?pretty=true")
  REL_PATH=$(echo $JSON | \
      grep -o '"relativePath" : "[^"]*"' | \
      grep -o "[^\"]*${ARTIFACT_PATTERN}")
  ZIP=$(basename "$REL_PATH")
  REVISION=$(echo $ZIP | grep -o -E '[0-9]{10}')
  echo "found revision $REVISION"

  DL_URL=$SUCCESS_URL/artifact/$REL_PATH

  jenkinsDownload "$DL_URL" "/tmp/$ZIP" || return 1
  echo "Downloaded $ZIP. Enter a description for this $ARTIFACT"
  if [ "$BRANCH" == "master" ]
    then
      read PRODUCT_DESCRIPTOR
    else
      BRANCH_DECODED=$(echo $BRANCH | sed -e 's|%252F|/|g')
      PRODUCT_DESCRIPTOR=$(basename "$BRANCH_DECODED")
  fi

  UNPACKED="${DATA_DIRECTORY}/${ARTIFACT}_$REVISION-$PRODUCT_DESCRIPTOR"
  echo "Extracting to $UNPACKED"
  unzip -q "/tmp/$ZIP" -d "$UNPACKED"

  openDir $UNPACKED
}

