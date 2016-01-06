====
Heku
====

A tool for working with multiple [He]ro[ku] environments.

Held:

- Remembering and typing app names for specific application environments is
  annoying and error prone
- Developers need to be able to move things from environment to environment
- Developers and clients need to be able to see features in-development

Install
=======

Execute the script with the `install` command.::

    ./heku.sh install

This will copy the script to your `/usr/local/bin` directory which should be
only your `PATH`. From this point on you can use the `heku` command by itself.

If you do not have `[jq](https://stedolan.github.io/jq/)` installed heku will
let you know and will not work until it is installed. On Mac OS the easiest way
to install jq is with [Homebrew](http://brew.sh/)::

    brew install jq

Usage
=====

::

    heku <environment> <action>

For most purposes, heku just knows which of your Heroku apps refer to named
environments and lets you forget the `--app myapp-name-dev` stuff.


It knows a few useful commands::

    heku promote
    heku dj shell_plus

Otherwise just wraps the Heroku toolbelt with the app name included::

    heku staging config:set ENV=staging


Configuration
=============

You must configure the base environment names, remotes, and app prefix in a
JSON file named `heku.json` in the root of your project.::

    {
      "HEROKU_APP_PREFIX": "myapp-dev",
      "APP_MANAGE_PATH": "myapp/manage.py",
      "ENVS": {
          "DEV": {
              "APP": "myapp-dev",
              "REMOTE": "heroku-myapp-dev"
          },
          "STAGING": {
              "APP": "myapp-staging",
              "REMOTE": "heroku-myapp-staging"
          },
          "PRODUCTION": {
              "APP": "myapp",
              "REMOTE": "heroku-myapp"
          }
      }
    }

Uninstall
=========

heku can uninstall itself::

    heku uninstall

