#!/bin/bash

# Helper script which can be used to interact with docker compose and an
# an environment.

# The problem
# -----------
#
# We want to run our app in a number of different environments
#
# - locally (just running the things we depend on using Docker, but have our app
#   running on the host)
# - development (have our Rails app running in Docker in DEVELOPMENT mode)
# - test (run our automated tests in docker with the app running in TEST mode)
# - production (run the Rails app in PRODUCTION mode, but also mimic production
#   by having multiple versions running behind a load balancer like nginx. Also
#   have assets being served from the load balancer as we would in production)
#
# Unless otherwise noted, we also don't want to build different images and
# containers to support this. We want to keep build and load times down by
# reusing images and Dockers layer cache.
#
# So to allow this we lean into 2 features of Compose. Each are detailed below
# but their use has one other key impact. The length and complexity of the
# command that needs to be entered to run any Compose command goes beyond what
# somone using the project daily would be expected to run.
#
# This is the primary reason for this helper file. It can help those new to
# Docker and Compose, and serve as documentation for those who are familiar with
# it.
#
# Multiple compose files
# ----------------------
#
# https://docs.docker.com/compose/extends/#multiple-compose-files
# https://docs.docker.com/compose/reference/overview/#specifying-multiple-compose-files#specifying-multiple-compose-files
#
# > Using multiple Compose files enables you to customize a Compose application
# > for different environments or different workflows.
#
# > By default, Compose reads two files, a `docker-compose.yml` and an optional
# > `docker-compose.override.yml` file. By convention, the `docker-compose.yml`
# > contains your base configuration. The override file, as its name implies,
# > can contain configuration overrides for existing services or entirely new
# > services.
#
# We leverage this by having the main file contain those services used by all
# environments e.g. the database and address lookup. We then have an override
# file for each environment type. With these in place you then need to ensure
# you reference both when running commands like `docker-compose buid`, `up`,
# `stop` etc.
#
# Project names
# -------------
#
# https://docs.docker.com/compose/reference/overview/#specifying-multiple-compose-files#use--p-to-specify-a-project-name
#
# > Each configuration has a project name. If you supply a -p flag, you can
# > specify a project name. If you don’t specify the flag, Compose uses the
# > current directory name.
#
# What is not immediately clear is that if you ommit the `-p` flag and allow
# Compose to use the default name, you'll start getting warnings about
# existing images and containers already being used. That's because we have
# opted to name things the same across environments, e.g. `db`, `address`, `app`
# etc. The alternate would have been to always override the names in our
# override files.
#
# Using the `-p` though means we can set a project name based on our environment
# and this will be used when creating the containers. No more conflicts or
# warnings, and it helps keep everything distinct.

set_project() {
  local current_dir=${PWD##*/}

  project_name="${current_dir}-${environment}"
  project_cmd="docker-compose -p ${project_name} -f docker-compose.yml"

  if [[ "$environment" != "local" ]]; then
    project_cmd="${project_cmd} -f ${override_file}"
  fi
}

generate_build_cmd() {
  echo "${project_cmd} build"
}

generate_up_cmd() {
  if [[ "$environment" == "prod" ]]; then
    # If we're running in production mode we want to make it more like it would
    # be expected to run, with more than 1 instance of the app running. Hence we
    # start 3 instances so the environment behaves like the app would in
    # production
    echo "${project_cmd} up --scale app=3"
  else
    echo "${project_cmd} up"
  fi
}

generate_down_cmd() {
  echo "${project_cmd} down"
}

generate_stop_cmd() {
  if [[ -z "${service}"  ]]; then
    # If service arg is empty
    echo "${project_cmd} stop"
  else
    echo "${project_cmd} stop ${service} ${cmd}"
  fi
}

generate_restart_cmd() {
  if [[ -z "${service}"  ]]; then
    # If service arg is empty
    echo "${project_cmd} restart"
  else
    echo "${project_cmd} restart ${service} ${cmd}"
  fi
}

generate_ps_cmd() {
  echo "${project_cmd} ps -a"
}

generate_run_cmd() {
  echo "${project_cmd} run ${service} ${cmd}"
}

generate_exec_cmd() {
  echo "${project_cmd} exec --index=1 ${service} ${cmd}"
}

generate_prep_cmd() {
  # As our ruby images are based on alpine bash is not installed so instead we
  # execute everything directly in the shell
  echo "${project_cmd} exec --index=1 app /bin/sh -c \"bundle exec rake db:create && bundle exec rake db:migrate\""
}

generate_dive_cmd() {
  # As our ruby images are based on alpine bash is not installed so instead we
  # open the shell directly in the container
  echo "${project_cmd} exec --index=1 ${service} /bin/sh"
}

# Attempt to run the command if we don't recogise it. When referencing a
# particular environment we need to specify the project name and ovveride file.
# But there are definately commands we have not covered so this allows anyone
# to take advantage of the script to sort out the project and override file args
# but run a command we are not currently setup to handle.
generate_unknown_cmd() {
  echo "${project_cmd} ${action} ${service} ${cmd}"
}

determine_environment() {
  if [[ "$environment" == "local" ]]; then
    # The override files focus mainly on the app. For local that will be running
    # locally so we don't set one
    override_file=""
  elif [[ "$environment" == "dev" ]]; then
    override_file="docker-compose.development.yml"
  elif [[ "$environment" == "test" ]]; then
    override_file="docker-compose.test.yml"
  elif [[ "$environment" == "prod" ]]; then
    override_file="docker-compose.production.yml"
  else
    echo "Don't recognise environment: ${environment}"
    return 1
  fi

  set_project
}

execute_action() {
  if [[ "$action" == "build" ]]; then
    exec_cmd="$(generate_build_cmd)"
  elif [[ "$action" == "ps" ]]; then
    exec_cmd="$(generate_ps_cmd)"
  elif [[ "$action" == "up" ]]; then
    exec_cmd="$(generate_up_cmd)"
  elif [[ "$action" == "down" ]]; then
    exec_cmd="$(generate_down_cmd)"
  elif [[ "$action" == "stop" ]]; then
    exec_cmd="$(generate_stop_cmd)"
  elif [[ "$action" == "restart" ]]; then
    exec_cmd="$(generate_restart_cmd)"
  elif [[ "$action" == "run" ]]; then
    exec_cmd="$(generate_run_cmd)"
  elif [[ "$action" == "exec" ]]; then
    exec_cmd="$(generate_exec_cmd)"
  elif [[ "$action" == "prep" ]]; then
    exec_cmd="$(generate_prep_cmd)"
  elif [[ "$action" == "dive" ]]; then
    exec_cmd="$(generate_dive_cmd)"
  else
    echo "Don't recognise action: ${action}. Will try it anyway!"
    exec_cmd="$(generate_unknown_cmd)"
  fi

  echo "Running: ${exec_cmd}"

  # Run the command we have compiled
  # Note. Everything on the internet will scream at you to avoid `eval` and use
  # `exec` instead (its safer). However so far we have been unable to get my
  # head around how wordsplitting and parameter expansion is messing with our
  # compiled command when we use it.
  # For most of our commands it wasn't an issue. It became a problem when we
  # added `generate_prep_cmd()`. Because we want to create and migrate in one
  # command we need to quote it. But we are already concatenating a values to
  # make a string so there is additional "" going on. Then that's passed to the
  # shell and its automated wordsplitting and parameter expansion rules kick in
  # and things just break. Below are some links that explain how they work but
  # we still couldn't get this one command to pass even with this knowledge
  #
  # http://mywiki.wooledge.org/Arguments
  # https://unix.stackexchange.com/questions/20349/quoting-in-a-function-results-in-error
  # https://unix.stackexchange.com/questions/190008/sh-c-unterminated-quoted-string-error
  eval $exec_cmd
}

# When all else fails, return your Docker environment to a clean slate.
#
# The command will first send kill signals to everything running before
# deleting all containers and images. It will then tell Compose to delete any
# images it has created
#
# NOTE. This should be used with caution as it will remove EVERYTHING, including
# any volumes created that may contain data, such as your databases.
nuke() {
  local args="$(docker ps -a -q)"
  # Trim all leading and trailing whitespace
  args="$(echo -e "${args}" | tr -d '[:space:]')"

  if [[ -n "$args" ]]; then
    echo "The args are[${args}]"
    exec docker kill $args
    exec docker rm $args
  fi

  exec docker system prune -a --volumes
}

# What we display if you pass in less than 2 args (our minimum for nearly all
# commands), and that args is not `nuke`
help_text() {
  echo "Needs at least 2 arguments [environment] [action]"
  echo "Example: ./doc.sh dev up"
  echo "Valid environments are:"
  echo "  local   (will only start services like db, address)"
  echo "  dev     (won't use load balancer, RAILS_ENV is development)"
  echo "  test    (won't use load balancer, RAILS_ENV is test, defaults to running unit tests not the app)"
  echo "  prod    (Uses load balancer, starts multiple app instances, RAILS_ENV is production)"
  echo "Valid actions:"
  echo "  build   (build the images)"
  echo "  ps      (list all containers)"
  echo "  up      (execute the containers)"
  echo "  down    (stop and remove the containers)"
  echo "  stop    (stop the running containers. Add [service] to stop just one)"
  echo "  restart (restart the running container. Add [service] to restart just one)"
  echo "  run     (run one time command against new service. Needs [service] and [cmd] args)"
  echo "  exec    (execute one time command against existing service. Needs [service] and [cmd] args)"
  echo "  prep    (create db and run migrations. * Not a docker command *)"
  echo "  dive    (access a running container. Useful for debug. * Not a docker command *)"
  echo ""
  echo "Note. Exception is when nuking environment. Example: ./doc.sh nuke"
}

if [ $# -lt 2 ]; then
  if [ $1 == "nuke" ]; then
    nuke
  else
    help_text
  fi
else
  environment=$1
  action=$2
  service=$3
  cmd="$(shift 3; echo "$*")"
  determine_environment
  execute_action
fi
