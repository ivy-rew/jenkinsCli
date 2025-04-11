# Jenkins CLI

Jenkins CLI tooling for the ivy-core developer team.
Giving you speed in daily repetitive work.

This is a [debianDevSystem](https://github.com/ivy-rew/debianDevSystem) sub-project of old, now living in its own dedicated repo.

[![CI Build](https://github.com/ivy-rew/jenkinsCli/actions/workflows/ci.yml/badge.svg)](https://github.com/ivy-rew/jenkinsCli/actions/workflows/ci.yml)

## Setup

### Environment

1. clone this repo to a location of your choice
2. run the `install.sh` script within in a terminal
3. define your environment: in `bin/.env`
4. use the cli: start with `jenkinsRun.sh`

### Repos

The script can be customized by providing text file like the `bin/core.git`.
You may customize this existing or add/contribute similar files.

- The name `core.git` must match the last part of the remote URI `git@github.com:axonivy/core.git`

## Features

Branch focused CLI actions:

![cli-branchSelect.png](doc/img/cli-branchSelect.png)

Trigger builds fast with zero clicking:

![cli-runBuilds.png](doc/img/cli-runBuilds.png)

Download products and unpack

![cli-download.png](doc/img/cli-download.png)
