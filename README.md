Strings Deploy Toolkit
=======================

This is a framework built for handling application deployment and orchestration within the Bitlancer Strings PaaS. It is currently only used for application deployment but it was built to be generic enough to handle orchestration tasks such as managing online configurations for a number of services.

This framework contains enough boilerplate code to deploy a generic web application from git. To try it out, visit the [Give it a try](#give-it-a-try) section.

## Give it a try

*Before you can deploy an application, make sure you have completed the steps within the [Prep for Application Deployment](https://github.com/Bitlancer/strings-documentation) guide. Note that this may have been completed for you by a Bitlancer staff member.*

* Setup an application if you have not done so already.
* Associate the appropriate formations with this application.
* Grant the remoteexec team login and sudo privileges, and add the `remoteexec` sudo role.
* Add a new deploy script and enter the values as they appear in the below screen shot. If you would like to deploy your own application code, replace the repo parameter value with your own repository url.
* Run the new deploy script

![Test](https://raw.github.com/Bitlancer/strings-documentation/master/assets/deploy-script-example.png)

## How it works

*This section is focused on how this framework works. For a high-level description on how application deployment works within Strings, visit the [Strings documentation repository](https://github.com/Bitlancer/strings-documentation).*

1) Strings executes `remoteexec.sh` on one of your Jump servers passing it a series of parameters about the the application. `remoteexec.sh` will load some shared code, parse the parameters, acquire the deploy lock, and pass control off to the application deploy logic in `app.inc`.


2) `app.inc` contains the orchestration logic for application deployments. This includes mapping an application name to a deployment type, building a deploy package which includes code and other data, distributing the deploy package to the appropriate servers, launching the foreign `remoteexec.sh` script on the appropriate endpoint servers, and handling errors.

3) The foreign `remoteexec.sh` script and accompanying `app.inc` handle setting up the application on the endpoint servers. This typically involves putting code in place, updating schemas, etc, based on the role or profiles of the servers.

## Running Deploy from the CLI

You can manually run the deploy script from the CLI. This has the advantage of providing instanteous feedback and can be helpful when debugging a deploy issue.

To execute the deploy script from the CLI:

* SSH to the jump server that resides in the region where your servers are located
* Switch to the remoteexec user (sudo su - remoteexec)
* cd /home/remoteexec
* Pull down the deploy code (git clone git@github.com...)
* Execute the deploy script (./remoteexec) and pass it the required params (see below)

Strings passes the deploy script a number of parameters automatically when executed via the control panel. When you're running the deploy script via the CLI you need to pass the same parameters. The easiest way to get these parameters is to run the deploy through Strings control panel with the verbosity turned all the way up (--verbosity 4). The first line of output will contain the parameter list. Note that --exec-id has to be changed to prevent conflicts with existing and future deploys. When executed via the CLI --exec-id should be set to 'c' + the current time as a unix timestamp. The example below includes this change.

Ex: 

```
./remoteexec.sh --exec-id c$(date +%s) --type Application --name test --server-list trenton.dfw01.int.example-infra.net,exampleorg::role::mysql_server,stringed::profile::mysql;harrisburg.dfw01.int.example-infra.net,exampleorg::role::php_app_server,stringed::profile::apache_phpfpm,strings::profile::cloudfuse --verbosity 4 --repo git@github.com:Example/wordpress.git --branch master
```

## Components

### remoteexec.sh

This script is responsible for orchestrating the deployment process. It is called
directly by Strings with several parameters including the application name and
server list. Its direct responsibilities include:

* Locking to prevent deployment collisions
* Building deployment packages, containing code and other data, and distributing
them to the appropriate servers
* Launching the client remote exec script on each server in the req'd order
* Error handling

### org-vars.inc

Contains any organization specific variables.

### app.inc

Contains any organization specific code related to applicaton deployment.

### git-wrapper.sh

A wrapper script that supports setting custom SSH options, such as an alternate
key file or disabling strict key checking, when executing git commands.

### libs/

Contains a number of shared "libraries" to assist with deployments.

### foreign/

Contains a separate remotexec.sh and associated includes for handling
deployments on each of the endpoint servers.

