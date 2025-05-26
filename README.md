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

Test basic function:

```
[freeradius1@ns8rockytest state]$ radtest bob test 192.168.1.10:1812 10 testing123
Sent Access-Request Id 52 from 0.0.0.0:54694 to 192.168.1.10:1812 length 73
	User-Name = "bob"
	User-Password = "test"
	NAS-IP-Address = 127.0.1.1
	NAS-Port = 10
	Cleartext-Password = "test"
Received Access-Accept Id 52 from 192.168.1.10:1812 to 192.168.1.10:54694 length 38
	Message-Authenticator = 0x6638...
```

To enter the freeradius container:

    podman exec -ti freeradius-app bash

Docker freeradius container documentation: https://hub.docker.com/r/freeradius/freeradius-server/

## Uninstall

To uninstall the instance:

    remove-module --no-preserve freeradius1
