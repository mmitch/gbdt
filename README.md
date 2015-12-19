gbdt - git based deployment tool
================================

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
   subfolders).  The repository should have separate branches for the
   production environment and the staging environment.

2. Create `~/.gbdt` containing the following five keys:

   * `GIT_REPO` - the git repository to use,
     e.g. `ssh://somehost/home/foo/git/website.git`

   * `PRODUCTION_DIR` - the directory where the production
     environment should be checked out, e.g. `/var/www`

   * `PRODUCTION_BRANCH` - the branch to use for the production
     environment checkout, e.g. `master`

   * `STAGING_DIR` - the directory where the staging
     environment should be checked out, e.g. `/var/www/staging`
     (yes, I simply use a subdirectory on the normal production
      server - after testing I can stop the staging environment)

   * `STAGING_BRANCH` - the branch to use for the staging
     environment checkout, e.g. `staging`

3. Initialize the production environment with `gbdt prod init`

4. To update production, run `gbdt prod deploy <tag>`, where <tag>
   is a git tag from the production environment's branch.  Deployments
   to production need a tag so you can't just deploy arbitrary
   intermediate states of development (in fact, you can propably trick
   gbdt into deploying anything that looks like a get ref, e.g. a
   commit hash, but then that's your problem).

5. Likewise, to deploy a tagged version to staging, use ``gbdt stage
   deploy <tag>``.  Unlike production, staging can also be pointed to
   the most current development version with `gbdt stage deploy`.

6. After a review, the staging checkout can be thrown away with
   `gbdt stage stop`.  This is very useful for me, as the staging
   tree is located inside my production webroot and I don't want the
   staging version accessible for everyone at all times.


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
  * As a developer I want so switch branches in the staging
    environment so I can showcase different features.
  * this can already manually be done in multiple steps:
    * `gbdt stage stop`
    * switch STAGING_BRANCH in configuration
    * `gbdt stage init`
  * but is it really needed? trying to live without it for now

### possible technical improvements

* support simple post-deployment scripting
  * e.g. for hiding .git directory in a checkout
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

Copyright (C) 2015  Christian Garbs <mitch@cgarbs.de>  
Licensed under GNU GPL v3 or later.
