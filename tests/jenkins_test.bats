#!/usr/bin/env bats

setup(){
  DIR=`pwd`
  if ! [ -f "${DIR}/../bin/.env" ]; then
    touch "${DIR}/../bin/.env"
  fi
  source "${DIR}/../bin/jenkinsOp.sh"
}

@test "parseJson" {
  response='{"_class":"org.jenkinsci.plugins.workflow.job.WorkflowJob","color":"blue"}'
  val=$(jsonField "$response" "color")
  [ "$val" == "blue" ]
}

@test "loadBranches" {
  branches=$(getBranchesForJob "core_ci")
  [[ " ${branches[@]} " =~ "master" ]] # contains master
}

@test "loadBranches_scanConfigAware" {
  export BRANCH_SCAN_JOB=process-editor-client
  branches=$(getAvailableBranches)
  [[ " ${branches[@]} " =~ "multiple-role-select" ]]
}

@test "loadJobs" {
  export JOB_FILTER="core_test\|core_ci"
  jobs=$(getAvailableTestJobsOrigin "core")
  [[ " ${jobs[@]} " =~ "core_test-bpm-exec" ]]
  [[ " ${jobs[@]} " =~ "core_ci-windows" ]]
  [[ " ${jobs[@]} " != *core_sonar* ]]
}

@test "connectability" {
  BASE_URL="http://jenkins.ivyteam.oblivion"
  rm -f /tmp/stderr
  getAvailableBranches 2> /tmp/stderr
  grep "Could not resolve host" /tmp/stderr
}

@test "health emoji" {
  state=$(getHealth "core_ci" "master")
  [[ "$state" == 🆗* ]]
}

@test "color emo" {
  [ "$(colorToEmo 'blue')" == 🆗 ]
  [ "$(colorToEmo 'red')" == 💔 ]
  [ "$(colorToEmo 'yellow_anime')" == ⚠️🏃🏃🏃 ]
  [ "$(colorToEmo)" == ❔ ]
}

@test "http status color" {
  echo "$(statusColor '201')"
  [ "$(statusColor '201')" == "${C_GREEN}201${C_OFF}" ]
  [ "$(statusColor '404')" == "${C_RED}404${C_OFF}" ]
  [ "$(statusColor '301')" == "${C_YELLOW}301${C_OFF}" ]
}

@test "parse origin" {
  [ "$(gitOrigin)" == "jenkinsCli" ]
}

@test "openDir" {
  skip "avoid opened file browser"
  . ./jenkinsGet.sh
  openDir .
}