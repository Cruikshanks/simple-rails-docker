#!/bin/sh

# Safer shell execution
# -e If a command fails, set -e will make the whole script exit, instead of just
#    resuming on the next line
# -u Treat unset variables as an error, and immediately exit
# -f Disable filename expansion (globbing) upon seeing *, ?, etc
# -x Print each command before executing it (arguments will be expanded)
set -eufx

# Replace the placeholder in the config file with the actual OS Places API key.
# This needs to be passed into the container as an env var at run time.
#
# Because this file will be run as a non-root user we won't be able to make
# changes to our working directory /usr/src/app. That's why we can't use the -i
# flag with sed because what actualy happens is sed tries to create a temporary
# file in the current directory with the new content, before then updating the
# original file.
#
# Our only solution is to stream the result of sed to somewhere we can write to
# as a non-root user, and then when we start the app reference this file rather
# than the template we copied into /usr/src/app.
#
# Note. Unfortunately the addressbase facade was built with the expectation that
# config files would be all that was needed when using the app. They didn't
# account for 12 Factor apps and Docker, and the need to drive configuration,
# especially secrets from env vars. Hence this convulated workaround
sed "s|OS_PLACES_KEY|$OS_PLACES_KEY|" config.json > /tmp/config.json

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
