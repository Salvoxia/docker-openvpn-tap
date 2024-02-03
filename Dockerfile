# Primary credit: https://github.com/jpetazzo/dockvpn
# Secondary credit: https://github.com/kylemanna/docker-openvpn
# Tertiary credit for TAP/bridge adjusments: https://github.com/aktur/docker-openvpn

# Smallest base image
FROM alpine:3.19.0

LABEL maintainer="Salvoxia <salvoxia@blindfish.info>"

# Testing: pamtester
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk add --update openvpn=2.6.8-r0 iptables curl bash easy-rsa openvpn-auth-pam google-authenticator pamtester libqrencode && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

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
