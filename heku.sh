#!/usr/bin/env bash
# Copyright 2015 Ben Lopatin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This script controls the app environment for Heroku commands
#
# Usage:
# > heku <environment> <some command>
#
# Example:
# > heku staging config:set MY_ENV_VAR=something

SCRIPT_NAME="heku"

usage()
{
cat << EOF

I don't understand what you want me to do.

usage:
> heku <environment_name> deploy
> heku <environment_name> dj <django command> <django args>
> heku <environment_name> <heroku command> <args> <options>
> heku feature deploy
> heku feature dj <django command> <django args>
> heku feature <heroku command> <args> <options>
> heku promote
> heku dbcopy

This script wraps calls to the Heroku toolbelt, allowing for simple access to
multiple app environments, including feature deployments, without recourse to
verbose app name arguments.

Specify an active environment name, either 'staging' or 'production'; use the
'feature' command to specify the current feature branch environment; or a pan-
environment command like 'promote'
EOF
}

if ! type "jq" > /dev/null 2>&1; then
    echo ""
    echo "Install jq first!"
    echo ""
    echo "For Mac OS, try 'brew install jq'"
    exit
fi

WORKING_DIR="`pwd`"

PROJECT_ROOT=$(pwd -P 2>/dev/null || command pwd)
while [ ! -e "$PROJECT_ROOT/heku.json" ]; do
    PROJECT_ROOT=${PROJECT_ROOT%/*}
    if [ "$PROJECT_ROOT" = "" ]; then break; fi
done


WORKING_DIR="`pwd`"
CONFIG_JSON=`cat $PROJECT_ROOT/heku.json`
MANAGEPATH=`echo $CONFIG_JSON | jq -r .APP_MANAGE_PATH`
HEROKU_APP_PREFIX=`echo $CONFIG_JSON | jq -r .HEROKU_APP_PREFIX`

DEV_APP_NAME=`echo $CONFIG_JSON | jq -r .ENVS.DEV.APP`
STAGING_APP_NAME=`echo $CONFIG_JSON | jq -r .ENVS.STAGING.APP`
PRODUCTION_APP_NAME=`echo $CONFIG_JSON | jq -r .ENVS.PRODUCTION.APP`

DEV_REMOTE=`echo $CONFIG_JSON | jq -r .ENVS.DEV.REMOTE`
STAGING_REMOTE=`echo $CONFIG_JSON | jq -r .ENVS.STAGING.REMOTE`
PRODUCTION_REMOTE=`echo $CONFIG_JSON | jq -r .ENVS.PRODUCTION.REMOTE`

INSTALL_LOCATION="/usr/local/bin/heku"
MAN_LOCATION="/usr/local/share/man/man1"


########################################################
# Set the environment or perform a top-level action

case "$1" in
  install)
    cp $PWD/heku.sh $INSTALL_LOCATION >> /dev/null
    cp "$PWD/man/heku.1" "$MAN_LOCATION/heku.1"
    gzip "$MAN_LOCATION/heku.1"
    PATH_TO_SCRIPT=$(cd ${0%/*} && echo $PWD/${0##*/})
    echo "Linked $PATH_TO_SCRIPT to $INSTALL_LOCATION"
    exit
    ;;
  uninstall)
    rm $INSTALL_LOCATION >> /dev/null
    rm "$MAN_LOCATION/heku.1"
    echo "Removed $INSTALL_LOCATION"
    exit
    ;;
  dev)
    APPNAME=${DEV_APP_NAME}
    DEPLOY_BRANCH="master"
    REMOTE_NAME=$DEV_REMOTE
    ;;
  staging)
    APPNAME=${STAGING_APP_NAME}}
    DEPLOY_BRANCH="master"
    REMOTE_NAME=$STAGING_REMOTE
    ;;
  production)
    APPNAME=${PRODUCTION_APP_NAME}}
    DEPLOY_BRANCH="master"
    REMOTE_NAME=$PRODUCTION_REMOTE
    ;;
  feature)
    FEATURE_BRANCH=$(git symbolic-ref --short HEAD)
    DEPLOY_BRANCH=$FEATURE_BRANCH
    # TODO check that this is not master branch
    APPNAME="$HEROKU_APP_PREFIX-${FEATURE_BRANCH//\//-}"
    REMOTE_NAME=$APPNAME
    if ! git remote -v | grep $REMOTE_NAME >> /dev/null; then
        # TODO separate checking app existence vs. remote existence
        echo "Forking from $DEV_APP_NAME to $APPNAME..."
        heroku fork --from $DEV_APP_NAME --to $APPNAME
        git remote add $REMOTE_NAME "git@heroku.com:$APPNAME.git"
        #git push $APPNAME $FEATURE_BRANCH:master
    fi
    ;;
  promote)
    heroku pipeline:diff --app="$STAGING_APP_NAME"
    read -p "Is this ready to promote to production? (y/n) " CONFIRM

    case "$CONFIRM" in
      y)
        ;;
      Y)
        ;;
      *)
        echo "Aborting"
        exit
        ;;
    esac

    printf "Promoting to production...\n"
    heroku pipeline:promote --app="$STAGING_APP_NAME"
    heroku run python ${MANAGEPATH} syncdb --noinput --app=${PRODUCTION_APP_NAME}
    heroku run python ${MANAGEPATH} migrate --app=${PRODUCTION_APP_NAME}}
    exit
    ;;
  dbcopy)
    read -p "Backup production DB, overwrite staging DB with it? (y/n)" CONFIRM

    case "$CONFIRM" in
      y)
        ;;
      Y)
        ;;
      *)
        exit
        ;;
    esac

    BACKUP_URL=`heroku pgbackups:url --app=${PRODUCTION_APP_NAME}}`
    heroku pgbackups:restore DATABASE_URL "$BACKUP_URL" --app ${STAGING_APP_NAME}}  --confirm ${STAGING}

    exit
    ;;
  *)
    usage
    exit
    ;;
esac


########################################################
# Environment specific actions

case "$2" in
  apps)
    exit
    ;;
  destroy)
    if [ -z "$FEATURE_BRANCH" ]; then
      echo "Sorry, I can only destroy feature deploys"
    else
      echo $FEATURE_BRANCH
      echo "Do you want to irrevocably destroy the '$APPNAME' app?"
        select yn in "Yes" "No"; do
        case $yn in
            Yes ) heroku apps:destroy --app $APPNAME; break;;
            No ) exit;;
        esac
      done
    fi
    exit
    ;;
  push)
    git push ${REMOTE_NAME} $DEPLOY_BRANCH:master
    exit
    ;;
  deploy)
    git push ${REMOTE_NAME} $DEPLOY_BRANCH:master
    heroku run python ${MANAGEPATH} syncdb --noinput --app=${APPNAME}
    heroku run python ${MANAGEPATH} migrate --app=${APPNAME}
    exit
    ;;
  cmd|dj)
    heroku run python ${MANAGEPATH} "${@:3}" --app=${APPNAME}
    exit
    ;;
esac


########################################################
# Environment specific actions with Heroku toolbelt commands

printf "\nExecuting in the $1 environment\n"
printf "heroku ${@:2} --app=$APPNAME\n\n"

heroku "${@:2}" --app="$APPNAME"
