#!/bin/bash  

DIR="$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )"

source $DIR/jenkinsGet.sh

BRANCH=master
if [ ! -z "$1" ]; then
  BRANCH=$1
fi

JOB=core_product
if [[ "$OSTYPE" == "darwin"* ]]; then
  JOB="core_product-mac"
fi
if [ ! -z "$2" ]; then
  JOB=$2
fi

JENKINS="jenkins.ivyteam.io"
ARTIFACT=designer
ARTIFACT_PATTERN=${DESIGNER_PATTERN}

jenkinsGet $JENKINS $JOB $BRANCH $ARTIFACT $ARTIFACT_PATTERN
