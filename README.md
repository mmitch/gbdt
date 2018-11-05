gbdt - git based deployment tool
================================

[![Build Status](https://travis-ci.org/mmitch/gbdt.svg?branch=master)](https://travis-ci.org/mmitch/gbdt)
[![GPL 3+](https://img.shields.io/badge/license-GPL%203%2B-blue.svg)](http://www.gnu.org/licenses/gpl-3.0-standalone.html)


usage
-----

    usage:
      gbdt [-v] <env> init           - initialize environment with CURRENT(!) state
      gbdt [-v] <env> deploy <tag>   - deploys tagged state to environment
      gbdt [-v] <env> status         - show status of an environment
      gbdt [-v] <env> tags           - show available <tags> in an environment
    
      gbdt [-v] stage deploy         - deploys CURRENT state to staging
      gbdt [-v] stage stop           - remove staging environment
    
      gbdt [-v] status               - show status of all environments
    
      <env> is an environment, see below
      <tag> is a git tag
  
    environments:  
      prod    - production  
      stage   - staging  


what? why?
----------

I wanted to develop a static website with a separate staging and
production environment.  I sketched out a crude workflow for the
webpage development:

* develop locally
* deploy to staging
* get feedback and review based on the staging version
* either go back to development or deploy the staging version to
  production

As I work on different machines, I needed some kind of source
management.  As I already do everything with it, git was the way to
go.  As I did not find a suitable existing tool after 5 minutes of
searching, I went into "roll your own" mode and gbdt was born to
support the workflow shown above.  Being more of an infrastructure
script, gbdt will propably also work for other things than just
websites.


how?
----

1. Initialize a git repository containg the website (e.g. the full
   webroot with the initial `index.html` as well as all needed
   subfolders).  The production and staging environment access the
   same branch in the repository, normally `master`.

2. Create `~/.gbdt` containing the following: (look out, the file gets
   sourced, so don't put anything like `rm -rf` in it!)

   * `GIT_REPO` - the git repository to use,
     e.g. `ssh://somehost/home/foo/git/website.git`

   * `PRODUCTION_DIR` - the directory where the production
     environment should be checked out, e.g. `/var/www`

   * `STAGING_DIR` - the directory where the staging
     environment should be checked out, e.g. `/var/www/staging`
     (yes, I simply use a subdirectory on the normal production
      server - after testing I can stop the staging environment)

   * `GIT_BRANCH` (optional) - the branch to use for the checkouts to
     both environments (default if unset is `master`)

   * `TAG_REGEXP` (optional) - an extended regular expression that
     filters the tags shown on `gbdt tags' and prevents any tags not
     matching to be deployed to production (deployment to staging is
     still possible) (default if unset is `.`, matching everything)

   * `post_deploy()` (optional) - a shell function to be run after
     every deployment, see below

3. Initialize the production environment with `gbdt prod init`

4. To update production, run `gbdt prod deploy <tag>`, where <tag> is
   a git tag from repository.  Deployments to production need a tag so
   you can't just deploy arbitrary intermediate states of development
   (in fact, you can propably trick gbdt into deploying anything that
   looks like a get rif, e.g. a commit hash, but then that's your
   problem).

5. Likewise, to deploy a tagged version to staging, use ``gbdt stage
   deploy <tag>``.  Unlike production, staging can also be pointed to
   the most current development version with `gbdt stage deploy`.

6. After a review, the staging checkout can be thrown away with
   `gbdt stage stop`.  This is very useful for me, as the staging
   tree is located inside my production webroot and I don't want the
   staging version accessible for everyone at all times.

### post_deploy() power

To run an arbitrary deployment script, define the `post_deploy()`
shell function in your configuration file like this:

```bash

    # post-deployment hook
    # $1: target_dir
    # $2: environment_name
    post_deploy()
    {
        # disable Apache access to the .git subdirectory
        cd "$1"
        chmod 700 .git
    }
	
```

You could also write logfiles, ping Feedburner for an update or send
an email.  Sky's the limit!


future plans
------------

gbdt was specifically designed to support my workflow.  Both the
workflow and gbdt have been conceived in just about 24 hours.
Regarding the proposed workflow gbdt is already feature complete, so
no immediate changes are planned.  Whether my workflow will hold up to
the needs of reality, only time will tell :-) If it does not work out,
gbdt will propably evolve.

### possible functional improvements

* support branch switching for staging
  * As a developer I want to switch branches in the staging
    environment so I can showcase different features.
  * but is it really needed? trying to live without it for now

### possible technical improvements

* switch to getopt option parsing
  * document all options (`-vv` and `-v -v` currently missing)
  * provide -c option to select different configuration files
* remove init command
  * deploy command could initialize automatically
  * this would also prevent initializing production without a proper
    tag


where to get it
---------------

The project is hosted at https://github.com/mmitch/gbdt


copyright
---------

Copyright (C) 2015, 2016, 2018  Christian Garbs <mitch@cgarbs.de>  
Licensed under GNU GPL v3 or later.

gbdt is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

gbdt is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with gbdt.  If not, see <http://www.gnu.org/licenses/>.
