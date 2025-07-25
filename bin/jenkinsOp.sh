#!/bin/bash  

SELECT=$1

JENKINS="jenkins.ivyteam.io"
if [ -z "${BASE_URL}" ]; then
  BASE_URL="https://${JENKINS}"
fi
DIR="$( cd "$( dirname "$BASH_SOURCE" )" && pwd )"

# ensure dependent binaries exist
if ! [ -x "$(command -v curl)" ]; then
  sudo apt install -y curl
fi

loadJenkinsEnv(){
  ENV="$DIR/.env"
  if [ -f $ENV ]; then
    . $ENV
  else
    echo "'$ENV' file missing. Adapt it form '.env.template' in order to use all features of jenkins CLI"
  fi
  if [ -z ${JENKINS_USER} ]; then
    JENKINS_USER=`whoami`
  fi
}

loadGitEnv(){
  local gitEnv="$DIR/${origin}.git"
  if [ -f "$gitEnv" ]; then
    . ${gitEnv}
  fi
}

getAvailableBranches(){  
  if [ -z "${BRANCH_SCAN_JOB}" ]; then
    BRANCH_SCAN_JOB=$origin # if no gitEnv was present
  fi
  getBranchesForJob $BRANCH_SCAN_JOB
}

getBranchesForJob(){
  local job=$1
  local JSON=$(curl -sS "${BASE_URL}/job/${job}/api/json?tree=jobs\[name\]")
  local BRANCHES="$(jsonField "${JSON}" "name" \
  | sed -e 's|%2F|/|g' \
  )"

  if ! [ -z "${BRANCH_FILTER}" ]; then
    echo "${BRANCHES}" | grep -v -e ${BRANCH_FILTER}
  else
    echo "${BRANCHES}"
  fi
}

getAvailableTestJobs(){
  getAvailableTestJobsOrigin "$(origin)"
}

getAvailableTestJobsOrigin(){
  # asume $gitEnv for origin already loaded
  if [ -z "${JOB_FILTER}" ]; then
    JOB_FILTER="^${origin}\$\|${origin}_" # if no gitEnv was present
  fi
  getJobsSelection "${JOB_FILTER}"
}

getJobsSelection(){
  local SELECT=$1
  local JSON=$(getJobsJson)
  local JOBS="$(jsonField "$JSON" "name" \
   | grep "$SELECT" \
   | sed -e 's|%2F|/|g' )"
  echo ${JOBS}
}

getJobsJson(){
  curl -sS "${BASE_URL}/api/json?tree=jobs\[name\]"
}

getHealth(){
  JOB="$1"
  BRANCH="$2"
  API_URI="${BASE_URL}/job/${JOB}/job/${BRANCH}/api/json?tree=color"
  JSON=$(curl -sS "${API_URI}")
  COLOR=$(jsonField "${JSON}" "color")
  colorToEmo $COLOR
}

colorToEmo(){
  local COLOR=$1
  if [ -z "$COLOR" ]; then
    COLOR="❔"
  fi
  local EMO=$(echo $COLOR \
   | sed 's|yellow|⚠️|' \
   | sed 's|blue|🆗|' \
   | sed 's|red|💔|' \
   | sed 's|disabled|🔧|' \
   | sed 's|_anime|🏃🏃🏃|' \
   | sed 's|notbuilt|💤|'
   )
  echo $EMO
}

jsonField(){
  local FIELD=$2
  echo $1 | grep -o -E "\"${FIELD}\":\"([^\"]*)" | sed -e "s|\"${FIELD}\":\"||g"
}

C_GREEN="$(tput setaf 2)"
C_RED="$(tput setaf 1)"
C_YELLOW="$(tput setaf 3)"
C_OFF="$(tput sgr0)"

statusColor(){
  local STATUS=$1
  if [[ "$STATUS" == "2"* ]] ; then
    echo "${C_GREEN}${STATUS}${C_OFF}"
  elif [[ "$STATUS" == "4"* ]] ; then
    echo "${C_RED}${STATUS}${C_OFF}"
  elif [[ "$STATUS" == "3"* ]] ; then
    echo "${C_YELLOW}${STATUS}${C_OFF}"
  else
    echo -e "$STATUS"
  fi
}

triggerBuild(){
  local RUN_JOB=$1
  local BRANCH=$2

  local JOB_URL="${BASE_URL}/job/${RUN_JOB}/job/${BRANCH}"
  RESPONSE=$( requestBuild ${JOB_URL} ${RUN_JOB} )
  echo -e "[ $( statusColor ${RESPONSE} ) ] @ $JOB_URL"
  
  if [ "$RESPONSE" == 404 ] || [ "$RESPONSE" == 409 ] ; then
      # job may requires a manual rescan to expose our new branch | isolate in sub bash to avoid conflicts!
      SCANNED=$( rescanBranches "${BASE_URL}/job/$RUN_JOB/" 3>&1 1>&2 2>&3 )
      # re-try
      RESPONSE=$( requestBuild ${JOB_URL} ${RUN_JOB} )
      echo -e "[ $( statusColor ${RESPONSE} ) ] @ $JOB_URL"
  fi
}

useToken(){
  if [ -z ${JENKINS_TOKEN+x} ]; then
    echo "Jenkins API token not found as enviroment variable called 'JENKINS_TOKEN'. Therefore password for jenkins must be entered:"
    echo -n "Enter JENKINS password for $JENKINS_USER:" 
    echo -n ""
    read -s JENKINS_TOKEN
    echo ""
    export JENKINS_TOKEN="$JENKINS_TOKEN" #re-use in this cli
  fi
}

useCrumb(){
  # get XSS preventention token
  if [ -z ${CRUMB+x} ]; then
    ISSUER_URI="${BASE_URL}/crumbIssuer/api/xml"
    CRUMB=$(curl -sS --basic -u "${JENKINS_USER}:${JENKINS_TOKEN}" "$ISSUER_URI") \
      | grep -o -E '"crumb":"[^"]*' | sed -e 's|"crumb":"||'
    export CRUMB="$CRUMB" #re-use for follow up requests
  fi
}

requestBuild(){
  local RUN_URL=$1
  local RUN_JOB=$2

  useToken
  useCrumb

  local RUN_PARAMS=(-L -X POST)
  RUN_PARAMS+=(--write-out %{http_code} --silent --output /dev/null)
  local params=${JOB_PARAMS[$RUN_JOB]}
  if ! [ -z "${params}" ]; then
    RUN_PARAMS+=(--form "json={'parameter': ${params} }")
  fi
  RUN_PARAMS+=(-u "$JENKINS_USER:$JENKINS_TOKEN")

  STATUS=$(curl "${RUN_PARAMS[@]}" "$RUN_URL/build?delay=0sec" -H "$CRUMB")
  echo $STATUS
}

rescanBranches(){
  JOB_URL=$1
  if [ -z "$JOB_URL" ]; then
    JOB_URL="${BASE_URL}/job/$BRANCH_SCAN_JOB/"
  fi
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

createView(){
  # prepare a simple view: listing all jobs of my feature branch
  local BRANCH="$1"
  local BRANCH_NAME=$(echo "$BRANCH" | sed -e 's|/|_|')
  local ISSUE_REGEX=$(echo ".*${BRANCH}" | sed -e 's|.*/|\\.*|')
  local MYVIEWS_URL="${BASE_URL}/user/${JENKINS_USER}/my-views"
  local VIEW_URL="${MYVIEWS_URL}/view/${BRANCH_NAME}/"

  # make sure authentication helpers ran
  useToken
  useCrumb

  # attempt to create the view and capture Jenkins response
  local RESPONSE=$(curl -sS -k -X POST -u "$JENKINS_USER:$JENKINS_TOKEN" -H "$CRUMB" \
    --form name="${BRANCH_NAME}" --form mode=hudson.model.ListView \
    --form json="{'name': '${BRANCH_NAME}', 'mode': 'hudson.model.ListView', 'useincluderegex': 'on', 'includeRegex': '${ISSUE_REGEX}', 'recurse': 'true'}" \
    "${MYVIEWS_URL}/createView")

  if echo "$RESPONSE" | grep -qi "view already exists"; then
    echo "View already exists: ${VIEW_URL}"
  else
    echo "View created: ${VIEW_URL}"
  fi
}

encode(){
  echo $1 | sed -e 's|/|%2F|g' 
}

encodeForDownload(){
  echo $1 | sed -e 's|/|%252F|g' 
}

gitOrigin(){
  local uri=$(git remote get-url origin)
  local resource=${uri##*/} #cut host
  echo ${resource%.*} #cut .git
}

origin(){
  origin=$(gitOrigin)
  if [ -z "$origin" ]; then
    origin="core"
  fi
  echo "$origin"
}

origin=$(origin)
loadGitEnv
loadJenkinsEnv
