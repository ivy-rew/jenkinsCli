#!/bin/bash

cliDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cat <<EOF | sed "s|cliBin|${cliDir}/bin|g" | tee -a $HOME/.profile

# include jenkinsRun
if [ -d "cliBin" ]; then
    PATH="cliBin:\$PATH"
fi
EOF

envFile="${cliDir}/bin/.env"
if ! [ -f "${envFile}" ]; then
  cp -v "${cliDir}/bin/.env.template" "${envFile}"
fi

echo "DONE: verify your environment in ${envFile}"
