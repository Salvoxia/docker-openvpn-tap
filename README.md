# OpenVPN for Docker

OpenVPN server in a Docker container complete with an EasyRSA PKI CA, modified for TAP and bridge support

## Disclaimer
* Primary credit: [jpetazzo/dockvpn](https://github.com/jpetazzo/dockvpn)
* Secondary credit (on which this is a fork): [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn)
* Tertiary credit (tap and bridge support principles): [https://github.com/aktur/docker-openvpn](aktur/docker-openvpn)

This image was modified for my own private use with my homelab. 
It was modified to support tap mode and network bridging out-of-the-box without the need of any additional or manual modifications.
Unlike the image this is image is based on, it is not tested extensively with different network setups, host architectures or VPN configurations. It works the way I use it. 


#### Cheat Sheet
 * __Build:__ docker build -t salvoxia/openvpn-tap:latest .
 * __Build Multi-Arch (buildx)__ docker build --platform linux/arm/v7,linux/arm64/v8,linux/amd64 -t salvoxia/openvpn-tap:latest .

#### Environment Variables
| Environment varible     | Description                                                                                                                 |
| :------------------- | :--------------------------------------------------------------------------------------------------------------------------- |
| DEBUG               | Set to 1 to enable debugging output                                                                                         |
| NFT_TABLES          | Set to 1 to use `iptables-nft` command instead of legacy `iptables` command for setting up ACCEPT and FORWARD rules <br> Use this if you intend to set up a bridge and your host uses the new iptables-nft. |


#### Upstream Links

* Docker Registry @ [salvoxia/openvpn-tap](https://hub.docker.com/r/salvoxia/openvpn-tap/)
* GitHub @ [salvoxia/docker-openvpn-tap](https://github.com/salvoxia/docker-openvpn-tap)


## Quick Start

* Pick a name for the `$OVPN_DATA` data volume container. It's recommended to
  use the `ovpn-data-` prefix to operate seamlessly with the reference systemd
  service.  Users are encourage to replace `example` with a descriptive name of
  their choosing.

      OVPN_DATA="ovpn-data-example"

* Initialize the `$OVPN_DATA` container that will hold the configuration files
  and certificates.  The container will prompt for a passphrase to protect the
  private key used by the newly generated certificate authority.

      docker volume create --name $OVPN_DATA
      docker run -v $OVPN_DATA:/etc/openvpn --rm salvoxia/openvpn-tap ovpn_genconfig -u udp://VPN.SERVERNAME.COM
      docker run -v $OVPN_DATA:/etc/openvpn --rm -it salvoxia/openvpn-tap ovpn_initpki

* Start OpenVPN server process

      docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN salvoxia/openvpn-tap

* Generate a client certificate without a passphrase

      docker run -v $OVPN_DATA:/etc/openvpn --rm -it salvoxia/openvpn-tap easyrsa build-client-full CLIENTNAME nopass

* Retrieve the client configuration with embedded certificates

      docker run -v $OVPN_DATA:/etc/openvpn --rm salvoxia/openvpn-tap ovpn_getclient CLIENTNAME > CLIENTNAME.ovpn

## TAP and bridge support

This image has been modified to work with tap mode and support network bridging out-of-the-box.
You must start the container with host networking mode.

To set up a server using tap and bridging, use the `-B` argument when creating the configuration. You must supply all bridge-related arguments as well:

      docker run -v $OVPN_DATA:/etc/openvpn --rm salvoxia/openvpn-tap \
        ovpn_genconfig \
            -u udp://VPN.SERVERNAME.COM:PORT \
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

Then start the server with host networking mode:
      
      docker run -v $OVPN_DATA:/etc/openvpn -d --network host --cap-add=NET_ADMIN salvoxia/openvpn-tap

Make sure to set choose the correct `iptables` command, otherwise routing might not work (refer to [Environment Variables](#environment-variables).
To use `iptables-nft`, start the container like this:

      docker run -v $OVPN_DATA:/etc/openvpn -d --network host --cap-add=NET_ADMIN -e NFT_TABLES=1 salvoxia/openvpn-tap
      
⚠️ __Attention__: Choosing the wrong bridge argument values may render your host machine unreachable over the network! Make sure to have direct access or choose wisely!

## Next Steps

### More Reading

Miscellaneous write-ups for advanced configurations are available in the
[docs](docs) folder.

### Systemd Init Scripts

A `systemd` init script is available to manage the OpenVPN container.  It will
start the container on system boot, restart the container if it exits
unexpectedly, and pull updates from Docker Hub to keep itself up to date.

Please refer to the [systemd documentation](docs/systemd.md) to learn more.

### Docker Compose

If you prefer to use `docker-compose` please refer to the [documentation](docs/docker-compose.md).

## Debugging Tips

* Create an environment variable with the name DEBUG and value of 1 to enable debug output (using "docker -e").

        docker run -v $OVPN_DATA:/etc/openvpn -p 1194:1194/udp --cap-add=NET_ADMIN -e DEBUG=1 salvoxia/openvpn-tap

* Test using a client that has openvpn installed correctly

        $ openvpn --config CLIENTNAME.ovpn

* Run through a barrage of debugging checks on the client if things don't just work

        $ ping 8.8.8.8    # checks connectivity without touching name resolution
        $ dig google.com  # won't use the search directives in resolv.conf
        $ nslookup google.com # will use search

* Consider setting up a [systemd service](/docs/systemd.md) for automatic
  start-up at boot time and restart in the event the OpenVPN daemon or Docker
  crashes.

## How Does It Work?

Initialize the volume container using the `salvoxia/openvpn-tap` image with the
included scripts to automatically generate:

- Diffie-Hellman parameters
- a private key
- a self-certificate matching the private key for the OpenVPN server
- an EasyRSA CA key and certificate
- a TLS auth key from HMAC security

The OpenVPN server is started with the default run cmd of `ovpn_run`

The configuration is located in `/etc/openvpn`, and the Dockerfile
declares that directory as a volume. It means that you can start another
container with the `-v` argument, and access the configuration.
The volume also holds the PKI keys and certs so that it could be backed up.

To generate a client certificate, `salvoxia/openvpn-tap` uses EasyRSA via the
`easyrsa` command in the container's path.  The `EASYRSA_*` environmental
variables place the PKI CA under `/etc/openvpn/pki`.

Conveniently, `salvoxia/openvpn-tap` comes with a script called `ovpn_getclient`,
which dumps an inline OpenVPN client configuration file.  This single file can
then be given to a client for access to the VPN.

To enable Two Factor Authentication for clients (a.k.a. OTP) see [this document](/docs/otp.md).

## OpenVPN Details

You can choose between `tun` and `tap` mode when generating the OpenVPN server configuration by (not) setting the `-t` flag when running `ovpn_genconfig`.

The UDP server uses`192.168.255.0/24` for dynamic clients by default.

The client profile specifies `redirect-gateway def1`, meaning that after
establishing the VPN connection, all traffic will go through the VPN.
This might cause problems if you use local DNS recursors which are not
directly reachable, since you will try to reach them through the VPN
and they might not answer to you. If that happens, use public DNS
resolvers like those of Google (8.8.4.4 and 8.8.8.8) or OpenDNS
(208.67.222.222 and 208.67.220.220).


## Security Discussion

The Docker container runs its own EasyRSA PKI Certificate Authority.  This was
chosen as a good way to compromise on security and convenience.  The container
runs under the assumption that the OpenVPN container is running on a secure
host, that is to say that an adversary does not have access to the PKI files
under `/etc/openvpn/pki`.  This is a fairly reasonable compromise because if an
adversary had access to these files, the adversary could manipulate the
function of the OpenVPN server itself (sniff packets, create a new PKI CA, MITM
packets, etc).

* The certificate authority key is kept in the container by default for
  simplicity.  It's highly recommended to secure the CA key with some
  passphrase to protect against a filesystem compromise.  A more secure system
  would put the EasyRSA PKI CA on an offline system (can use the same Docker
  image and the script [`ovpn_copy_server_files`](/docs/paranoid.md) to accomplish this).
* It would be impossible for an adversary to sign bad or forged certificates
  without first cracking the key's passphase should the adversary have root
  access to the filesystem.
* The EasyRSA `build-client-full` command will generate and leave keys on the
  server, again possible to compromise and steal the keys.  The keys generated
  need to be signed by the CA which the user hopefully configured with a passphrase
  as described above.
* Assuming the rest of the Docker container's filesystem is secure, TLS + PKI
  security should prevent any malicious host from using the VPN.


## Benefits of Running Inside a Docker Container

### The Entire Daemon and Dependencies are in the Docker Image

This means that it will function correctly (after Docker itself is setup) on
all distributions Linux distributions such as: Ubuntu, Arch, Debian, Fedora,
etc.  Furthermore, an old stable server can run a bleeding edge OpenVPN server
without having to install/muck with library dependencies (i.e. run latest
OpenVPN with latest OpenSSL on Ubuntu 12.04 LTS).

### It Doesn't Stomp All Over the Server's Filesystem

Everything for the Docker container is contained in two images: the ephemeral
run time image (salvoxia/openvpn-tap) and the `$OVPN_DATA` data volume. To remove
it, remove the corresponding containers, `$OVPN_DATA` data volume and Docker
image and it's completely removed.  This also makes it easier to run multiple
servers since each lives in the bubble of the container (of course multiple IPs
or separate ports are needed to communicate with the world).

### Some (arguable) Security Benefits

At the simplest level compromising the container may prevent additional
compromise of the server.  There are many arguments surrounding this, but the
take away is that it certainly makes it more difficult to break out of the
container.  People are actively working on Linux containers to make this more
of a guarantee in the future.

## Differences from jpetazzo/dockvpn

* No longer uses serveconfig to distribute the configuration via https
* Proper PKI support integrated into image
* OpenVPN config files, PKI keys and certs are stored on a storage
  volume for re-use across containers
* Addition of tls-auth for HMAC security

## Originally Tested On

* Docker hosts:
  * RaspberryPI 3B+ running Raspbian arm64 with kernel 5.15.61
* Clients
  * Windows OpenVPN Client 2.5.7 (64bit) 
  * Android App VPN Client Pro (supports TAP with rooting the device)


## Original License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fkylemanna%2Fdocker-openvpn.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fkylemanna%2Fdocker-openvpn?ref=badge_large)
