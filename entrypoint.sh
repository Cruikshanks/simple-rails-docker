#!/bin/sh

# Safer shell execution
# -e If a command fails, set -e will make the whole script exit, instead of just
#    resuming on the next line
# -u Treat unset variables as an error, and immediately exit
# -f Disable filename expansion (globbing) upon seeing *, ?, etc
# -x Print each command before executing it (arguments will be expanded)
set -eufx

# When the container and environment is first created the database won't exist.
# This means the next step would be to run these db tasks, then kill the
# environment and bring everything back up again, now working.
# If instead we always ensure these commands are run before the app itself, it
# should work whether its the first run or the 100th.
# Once the database is created, you will see an error in the logs, but it is
# something that can be ignored.
bundle exec rake db:create
bundle exec rake db:migrate

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
