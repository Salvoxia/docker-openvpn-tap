# Quick Start with docker-compose

* Add a new service in docker-compose.yml

__TUN__
```yaml
version: '2'
services:
  openvpn:
    cap_add:
     - NET_ADMIN
    image: salvoxia/openvpn-tap
    container_name: openvpn
    ports:
     - "1194:1194/udp"
    restart: always
    volumes:
     - ./openvpn-data/conf:/etc/openvpn
```

__TAP with bridging__

Make sure to select the correct `iptables` command. Use host networking.
```yaml
version: '2'
services:
  openvpn:
    cap_add:
     - NET_ADMIN
    image: salvoxia/openvpn-tap
    container_name: openvpn
    network_mode: host
    restart: always
    volumes:
     - ./openvpn-data/conf:/etc/openvpn
     environment:
          - NFT_TABLES={$NFT_TABLES:-1}
```
* Initialize the configuration files

__TUN__
```bash
docker-compose run --rm openvpn ovpn_genconfig -u udp://VPN.SERVERNAME.COM
```

__TAP with bridging__
```bash
docker-compose run --rm openvpn ovpn_genconfig -u udp://VPN.SERVERNAME.COM:PORT \
    -t
    -B
    --bridge-name 'br0' \
    --bridge-eth-if 'eth0' \
    --bridge-eth-ip '192.168.0.199' \
    --bridge-eth-subnet '255.255.255.0' \
    --bridge-eth-broadcast '192.168.0.255' \
    --bridge-eth-gateway '192.168.0.1' \
    --bridge-eth-mac 'b8:32:ac:8b:17:2e' \
    --bridge-dhcp-start '192.168.0.200' \
    --bridge-dhcp-end '192.168.0.220'
```

* Initialize certificates
```bash
docker-compose run --rm openvpn ovpn_initpki
```

* Fix ownership (depending on how to handle your backups, this may not be needed)

```bash
sudo chown -R $(whoami): ./openvpn-data
```

* Start OpenVPN server process

```bash
docker-compose up -d openvpn
```

* You can access the container logs with

```bash
docker-compose logs -f
```

* Generate a client certificate

```bash
export CLIENTNAME="your_client_name"
# with a passphrase (recommended)
docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME
# without a passphrase (not recommended)
docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME nopass
```

* Retrieve the client configuration with embedded certificates

```bash
docker-compose run --rm openvpn ovpn_getclient $CLIENTNAME > $CLIENTNAME.ovpn
```

* Revoke a client certificate

```bash
# Keep the corresponding crt, key and req files.
docker-compose run --rm openvpn ovpn_revokeclient $CLIENTNAME
# Remove the corresponding crt, key and req files.
docker-compose run --rm openvpn ovpn_revokeclient $CLIENTNAME remove
```

## Debugging Tips

* Create an environment variable with the name DEBUG and value of 1 to enable debug output (using "docker -e").

```bash
docker-compose run -e DEBUG=1 -p 1194:1194/udp openvpn
```
