# Primary credit: https://github.com/jpetazzo/dockvpn
# Secondary credit: https://github.com/kylemanna/docker-openvpn
# Tertiary credit for TAP/bridge adjusments: https://github.com/aktur/docker-openvpn

# Smallest base image
FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

LABEL maintainer="Salvoxia <salvoxia@blindfish.info>"

# Testing: pamtester
RUN <<EOT
    echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
    apk add --update openvpn=2.7.7-r0
    apk add --update iptables=1.8.13-r0
    apk add --update curl=8.23.0-r0
    apk add --update bash=5.3.9-r1
    apk add --update easy-rsa=3.2.5-r0
    apk add --update openvpn-auth-pam=2.7.7-r0
    apk add --update google-authenticator=1.11-r0
    apk add --update libqrencode=4.1.1-r3
    apk add --update pamtester
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*
EOT

# Needed by scripts
ENV OPENVPN=/etc/openvpn
ENV EASYRSA=/usr/share/easy-rsa \
    EASYRSA_CRL_DAYS=3650 \
    EASYRSA_PKI=$OPENVPN/pki \
    EASYRSA_VARS_FILE=$OPENVPN/vars

VOLUME ["/etc/openvpn"]

# Removed EXPOSE command, since the new configuration will let openVPN server listen on any port, and 
# NAT for UDP might be problematic and not work in some environments. Not required at all for bridged setup,
# since the container needs to run in host mode anyway. Use the -p argument for publishing the correct port mapping.

CMD ["ovpn_run"]

ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*

# Add support for OTP authentication using a PAM module
ADD ./otp/openvpn /etc/pam.d/
