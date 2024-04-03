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
  branches=$(getAvailableBranches)
  [[ " ${branches[@]} " =~ "master" ]] # contains master
}

@test "loadJobs" {
  jobs=$(getAvailableTestJobs)
  [[ " ${jobs[@]} " =~ "core_test-bpm-exec" ]]
  [[ " ${jobs[@]} " =~ "core_ci-windows" ]]
  [[ " ${jobs[@]} " != *core_techdoc* ]]
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

@test "openDir" {
  skip "avoid opened file browser"
  . ./jenkinsGet.sh
  openDir .
}