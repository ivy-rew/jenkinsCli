#!/bin/bash  

SELECT=$1

JOB=ivy-core_ci
if [ ! -z "$3" ]
  then
    JOB=$3
fi

JENKINS="jenkins.ivyteam.io"
URL="https://${JENKINS}/job/$JOB/"
JENKINS_USER=`whoami`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ENV="$DIR/.env"
if [ -f $ENV ]; then
    source $ENV
else
    echo "'$ENV' file missing. Adapt it form '.env.template' in order to use all features of jenkins CLI"
fi


# ensure dependent binaries exist
if ! [ -x "$(command -v curl)" ]; then
  sudo apt install -y curl
fi

function getAvailableBranches()
{
  JSON=`curl -s "$URL/api/json?tree=jobs[name]"`
  BRANCHES=$(echo $JSON \
   | grep -o -E '"name":"([^"]*)' \
   | sed -e 's|"name":"||g' \
   | sed -e 's|%2F|/|' \
   | sed -e 's|"||g')
  echo "$BRANCHES"
}

function getAvailableTestJobs()
{
  JSON=`curl -s "https://$JENKINS/api/json?tree=jobs[name]"`
  JOBS=`echo $JSON \
   | grep -o -E '"name":"([^"]*)' | sed -e 's|"name":"||g' \
   | grep 'ivy-core_test' \
   | sed -e 's|%2F|/|' \
   | sed -e 's|"||g' `
  echo $JOBS
}

function statusColor()
{
  STATUS=$1
  if [[ "$STATUS" == "2"* ]] ; then #GREEN
    echo "$(tput setaf 2)${STATUS}$(tput sgr0)"
  elif [[ "$STATUS" == "4"* ]] ; then #RED
    echo "$(tput setaf 1)${STATUS}$(tput sgr0)"
  elif [[ "$STATUS" == "3"* ]] ; then #YELLOW
    echo "$(tput setaf 3)${STATUS}$(tput sgr0)"
  else
    echo -e "$STATUS"
  fi
}

function triggerBuild()
{
  RUN_JOB=$1
  BRANCH=$2

  JOB_URL="https://$JENKINS/job/${RUN_JOB}/job/${BRANCH}"
  RESPONSE=$( requestBuild ${JOB_URL} )
  echo -e "[ $( statusColor ${RESPONSE} ) ] @ $JOB_URL"
  
  if [ "$RESPONSE" == 404 ] ; then
      # job may requires a manual rescan to expose our new branch | isolate in sub bash to avoid conflicts!
      SCANNED=$( rescanBranches "https://$JENKINS/job/$RUN_JOB/" 3>&1 1>&2 2>&3 )
      # re-try
      RESPONSE=$( requestBuild ${JOB_URL} )
      echo -e "[ $( statusColor ${RESPONSE} ) ] @ $JOB_URL"
  fi
}

function requestBuild()
{
  RUN_URL=$1
  if [ -z ${JENKINS_TOKEN+x} ]; then
      echo "Jenkins API token not found as enviroment variable called 'JENKINS_TOKEN'. Therefore password for jenkins must be entered:"
      echo -n "Enter JENKINS password for $JENKINS_USER:" 
      echo -n ""
      read -s JENKINS_TOKEN
      echo ""
      export JENKINS_TOKEN="$JENKINS_TOKEN" #re-use in this cli
  fi

  # get XSS preventention token
  if [ -z ${CRUMB+x} ]; then
    ISSUER_URI="https://${JENKINS}/crumbIssuer/api/xml"
    CRUMB=$(curl --silent --basic -u "${JENKINS_USER}:${JENKINS_TOKEN}" "$ISSUER_URI") \
      | grep -o -E '"crumb":"[^"]*' | sed -e 's|"crumb":"||'
    export CRUMB="$CRUMB" #re-use for follow up requests
  fi

  STATUS=$(curl --write-out %{http_code} --silent --output /dev/null -L -I -X POST \
    -u "$JENKINS_USER:$JENKINS_TOKEN" \
    "$RUN_URL/build?delay=0sec" -H "$CRUMB")
  echo $STATUS
}

function rescanBranches()
{
  JOB_URL=$1
  ACTION="build?delay=0"
  SCAN_URL="$JOB_URL$ACTION"
  HTTP_STATUS=`curl --write-out %{http_code} --silent --output /dev/null -I -L -X POST -u "$JENKINS_USER:$JENKINS_TOKEN" "$SCAN_URL"`
  echo "triggered rescan triggered for $SCAN_URL"
  
  if [[ $HTTP_STATUS == *"200"* ]]; then
    echo "jenkins returned status $HTTP_STATUS. Waiting for index job to finish"
    ACTION="indexing/consoleText"
    until [[ $(curl --write-out --output /dev/null --silent $JOB_URL$ACTION) == *"Finished:"* ]]; do
      printf "."
      sleep 1
    done
  else
    echo "failed: Jenkins returned $( statusColor $HTTP_STATUS )"
  fi
  printf "\n"
}

function createView()
{
  # prepare a simple view: listing all jobs of my feature branch
  BRANCH=$1
  BRANCH_ENCODED=`encode $BRANCH`
  MYVIEWS_URL="https://$JENKINS/user/${JENKINS_USER}/my-views"
  curl -s -k -X POST -u "$JENKINS_USER:$JENKINS_TOKEN" -H "$CRUMB" --form name=test --form   mode=hudson.model.ListView --form json="{'name': '${BRANCH}', 'mode': 'hudson.model.ListView', 'useincluderegex': 'on'}" "${MYVIEWS_URL}/createView"
  CONFIG_URL="${MYVIEWS_URL}/view/${BRANCH_ENCODED}/config.xml"
  curl -k -s -X GET "${CONFIG_URL}" -o viewConf.xml
  ISSUE_REGEX=$( echo $BRANCH | sed -e 's|.*/|\.*|')
  sed -e "s|<recurse>false</recurse>|<includeRegex>${ISSUE_REGEX}</includeRegex><recurse>true></recurse>|" viewConf.xml > viewConf2.xml
  curl -k -s -X POST "${CONFIG_URL}" -u "$JENKINS_USER:$JENKINS_TOKEN" -H "$CRUMB" -H "Content-Type:text/xml" --data-binary "@viewConf2.xml"
  rm viewConf*.xml
  echo "View created: ${MYVIEWS_URL}/view/${BRANCH_ENCODED}/"
}

function encode()
{
  echo $1 | sed -e 's|/|%2F|' 
}

function encodeForDownload()
{
  echo $1 | sed -e 's|/|%252F|' 
}
