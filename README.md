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

Open the **Settings** page of the application, or use the API (see below).

- **Host name (FQDN)** – name of the RADIUS server. The server certificate for
  PEAP/TTLS is the one Traefik holds for this name: request a Let's Encrypt
  certificate with the toggle, or upload one in *Settings > TLS certificates*.
  Until such a certificate exists a self-signed one is used. The container
  image's own test certificate is never used, its private key is public.
- **User domain** – accounts of this NS8 user domain (Samba AD or OpenLDAP,
  internal or external) can log in. See the table for the supported methods.
- **RADIUS clients** – the devices that may send requests (access points,
  switches, VPN gateways): name, IP address or network, shared secret. Enter the
  same secret on the device.

After the settings are saved the service is started. The firewall ports
1812/udp and 1813/udp are opened. Only one instance per node is possible.

### Which login method works with which account

| Method | Local users (`authorize`) | User domain (AD/LDAP) |
|---|---|---|
| PAP (VPN gateway, switch login) | yes | yes |
| EAP-TTLS/PAP (Wi-Fi) | yes | yes |
| PEAP/MSCHAPv2, EAP-TTLS/MSCHAPv2 (Wi-Fi) | yes | **no** |

A domain password is checked with an LDAP bind through the node's Ldapproxy, so
the server has to receive it (inside the TLS tunnel). MSCHAPv2 never sends the
password and needs its NT hash instead, which LDAP does not give away. For Samba
AD that would take a domain member with winbind/`ntlm_auth` next to FreeRADIUS
and `ntlm auth = mschapv2-and-ntlmv2-only` on the domain controller (the
default is `ntlmv2-only`); this module does not do that.

Clients: Android and Windows 10/11 can be set to EAP-TTLS with PAP by hand.
Apple devices choose MSCHAPv2 when a network is joined by hand and need a
configuration profile for TTLS/PAP. Let the clients validate the server
certificate and its name, otherwise a fake access point can collect passwords.

`user`, `user@realm` and `DOMAIN\user` are all looked up as `user`.

### API

    api-cli run module/freeradius1/configure-module --data '{
      "host": "radius.example.org", "lets_encrypt": true, "http2https": true,
      "ldap_domain": "ad.example.org",
      "clients": [{"name": "ap-office", "ipaddr": "192.168.1.10", "secret": "use-a-long-random-string"}]
    }'

`ldap_domain` and `clients` are optional: when missing, the stored value is
kept. `get-configuration` returns the same object, including the secrets.

### Files

Enter the app instance environment, for example freeradius1:

    runagent -m freeradius1

| Path in `state/` | Purpose |
|---|---|
| `config/authorize` | local users, edit by hand |
| `config/clients.conf` | additional RADIUS clients, edit by hand (included after the clients of the settings page) |
| `config/mschap`, `config/ldap` | FreeRADIUS module files, edit by hand |
| `clients.json` | clients of the settings page with their secrets (0600) |
| `certs/` | server certificate and key, written by `get-certificate.service` |
| `generated/` | files rendered at every start (`clients.conf`, `eap`, `ldap`, the two virtual servers): do not edit |

Restart after editing: `systemctl --user restart freeradius-app`. The server
log goes to the journal: `journalctl --user -u freeradius-app` (or the *Logs*
page of cluster-admin).

Secrets (shared secrets, the bind password of the user domain) are kept in
files with mode 0600 and not in `state/environment`, which NS8 mirrors to Redis.

Test basic function with a local user (`bob Cleartext-Password := "test"` in
`config/authorize`) and a client entry for the node itself:

```
[freeradius1@ns8rockytest state]$ podman run --rm --network=host --entrypoint radtest $FREERADIUS_SERVER_IMAGE -t pap bob test 127.0.0.1 0 <shared secret>
Sent Access-Request Id 52 from 0.0.0.0:54694 to 127.0.0.1:1812 length 73
Received Access-Accept Id 52 from 127.0.0.1:1812 to 127.0.0.1:54694 length 38
```

To enter the freeradius container:

    podman exec -ti freeradius-app bash

Docker freeradius container documentation: https://hub.docker.com/r/freeradius/freeradius-server/

### Backup, restore, clone

The backup contains `config/`, `clients.json` and `certs/`. A restored, cloned
or moved instance is bound to the same user domain again. A clone on the same
node cannot start (ports 1812-1813/udp are taken): use *move* or another node.

### Updating from a version without these settings

The Traefik certificate and the user domain need two more authorizations. They
are granted when the update is run from the cluster, not from the module:

    api-cli run update-module --data '{"module_url":"ghcr.io/mrmarkuz/freeradius:latest","instances":["freeradius1"],"force":true}'

Hand-edited files in `config/` are kept. Because the virtual servers are now
generated, changes made inside the container to `sites-enabled/` are not.

## Uninstall

To uninstall the instance:

    remove-module --no-preserve freeradius1
