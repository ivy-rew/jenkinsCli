#!/bin/bash  

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/jenkinsOp.sh"


function health(){
    BRANCH=$1
    BRANCH_ENCODED=`encodeForDownload $BRANCH`
    local JOBS=( $(getAvailableTestJobs) )
    local STATE=`jobStatus JOBS[@]`
    for S in ${STATE[*]}; do
        printf "${S}\n"
    done
}

function triggerBuilds() {
    BRANCH=$1
    local JOBS=( $(getAvailableTestJobs) )
    
    COLOR_BRANCH=${C_GREEN}${BRANCH}${C_OFF}
    if [ "$HEALTH" == "true" ] ; then
        echo -e "getting health of ${COLOR_BRANCH}"
        watch -d "${DIR}/jenkinsRun.sh health '${BRANCH}'"
    else
        echo -e "triggering builds for ${COLOR_BRANCH}"
        SEL_JOBS=${JOBS[@]}
    fi
    
    HEALTH="false"
    FILTERED="true"

    local PRE_ACTIONS=('!leave:exit' '!health' '!getDesigner' '!getEngine')

    local POST_ACTIONS=('!new_view')
    if ! [ -z "${JOB_FILTER}" ]; then
        POST_ACTIONS+=('...more')
    fi

    select RUN in ${PRE_ACTIONS[@]} ${SEL_JOBS[@]} ${POST_ACTIONS[@]} 
    do
        BRANCH_ENCODED=`encodeForDownload $BRANCH`
        if [ "$RUN" == "!leave:exit" ] ; then
            break
        fi
        if [ "$RUN" == "!health" ] ; then
            HEALTH="true"
            break;
        fi
        if [ "$RUN" == "!getDesigner" ] ; then
            echo $($DIR/newDesigner.sh "$BRANCH_ENCODED")
            break
        fi
        if [ "$RUN" == "!getEngine" ] ; then
            echo $($DIR/newEngine.sh "$BRANCH_ENCODED")
            break
        fi
        if [ "$RUN" == "!new_view" ] ; then
            echo "$(createView $BRANCH)"
            break
        fi
        if [ "$RUN" == "...more" ] ; then
            FILTERED="false"
            export JOB_FILTER=""
            break
        fi

        JOB_RAW=$(sed 's|\.\.\..*||' <<< $RUN )
        echo $(triggerBuild ${JOB_RAW} $BRANCH_ENCODED)
    done
    
    if [ "$HEALTH" == "true" ] ; then
        triggerBuilds $1
    fi
    if [ "$FILTERED" == "false" ] ; then
        triggerBuilds $1
    fi
}

function jobStatus(){
    declare -a JBS=("${!1}")
    local jobState=()
    for JB in ${JBS[*]}; do
        jobState+=("$JB...$(getHealth ${JB} ${BRANCH_ENCODED})")
    done
    echo ${jobState[@]}
}

function noColor(){
  echo -E $1 | sed -E "s/\x1B\[(([0-9]{1,2})?(;)?([0-9]{1,2})?)?[m,K,H,f,J]//g"
}

function goodbye(){
  printf "\nHave a nice day! 👍"
  inspire
}

function inspire(){
  JSON=$(curl -sS https://thatsthespir.it/api)
  QUOTE=$(jsonField "${JSON}" "quote")
  AUTHOR=$(jsonField "${JSON}" "author")
  LINK=$(jsonField "${JSON}" "id" )
  printf "\n\n$(tput bold setaf 4)${QUOTE}${C_OFF}
$(tput setaf 5)${AUTHOR} $(tput setaf 6)https://thatsthespir.it/${LINK}${C_OFF}"
}

function chooseBranch() {
  BRANCHES_RAW=$( getAvailableBranches )
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  BRANCHES_COLORED=$(grep -C 100 --color=always -E "${GIT_BRANCH}" <<< "${BRANCHES_RAW[@]}")
  if [[ -z "$BRANCHES_COLORED" ]]; then
    BRANCHES_COLORED="${BRANCHES_RAW[@]}" #all without highlight: local 'only' branch.
  fi
  OPTIONS=( '!re-scan' '!exit' ${BRANCHES_COLORED[@]} )

  echo "SELECT branch of $(origin)"
  select OPTION in ${OPTIONS[@]}; do
    if [ "$OPTION" == "!re-scan" ]; then
        echo 're-scanning [beta]'
        rescanBranches $URL
        chooseBranch
        break
    fi
    if [ "$OPTION" == "!exit" ]; then
        break
    else
        BRANCH=$(noColor "${OPTION}")
        triggerBuilds ${BRANCH}
        break
    fi
  done
}

if [[ "$1" == "health" ]]; then
  health "$2"
  exit
fi

if [[ "$1" != "test" ]]; then
  trap goodbye EXIT
  chooseBranch
fi

