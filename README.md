# ns8-freeradius

## WARNING! This is a first draft of ns8-freeradius. Do NOT use in production.

[Freeradius](https://www.freeradius.org/) is an open source RADIUS server.

## Install

Install on CLI:

    add-module ghcr.io/mrmarkuz/freeradius:latest

The output of the command will return the instance name.
Output example:

    {"module_id": "freeradius1", "image_name": "freeradius", "image_url": "ghcr.io/nethserver/freeradius:latest"}

## Force update

As the latest tag is used, we need To force the update from the repo to not reuse the local image.

    api-cli run update-module --data '{"module_url":"ghcr.io/mrmarkuz/freeradius:latest","instances":["freeradius1"],"force":true}'

## Configure

Set up any FQDN, as there's no web interface now it doesn't matter. After the settings are saved, the service is started.
The firewall ports 1812/udp and 1813/udp are opened.

Enter the app instance environment, for example freeradius1:

    runagent -m freeradius1 

The config files are available in the config `config` directory:

- authorize
- clients.conf
- mschap

To enter the freeradius container:

    podman exec -ti freeradius-app bash

Docker container documentation: https://hub.docker.com/r/freeradius/freeradius-server/

## Uninstall

To uninstall the instance:

    remove-module --no-preserve freeradius1
