#!/bin/bash 
#On client

SECRET_ARN=$1
LDAP_SERVER_IP=$2
AWS_REGION=$3

export DEBIAN_FRONTEND='non-interactive'

apt update && apt-get install -y -qq libnss-ldap libpam-ldap ldap-utils sssd sssd-tools


LDAP_PASSWORD=`aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text --region $AWS_REGION`

#Ldap password 
cat > /etc/ldap.secret << EOF
$LDAP_PASSWORD
EOF

chmod 600 /etc/ldap.secret

cat > /etc/ldap/ldap.conf << EOF
BASE dc=example,dc=com
URI  ldap://$LDAP_SERVER_IP
EOF

cat > /etc/ldap.conf << EOF
# @(#)$Id: ldap.conf,v 1.38 2006/05/15 08:13:31 lukeh Exp $
#
# This is the configuration file for the LDAP nameservice
# switch library and the LDAP PAM module.
#
# PADL Software
# http://www.padl.com
#

# Your LDAP server. Must be resolvable without using LDAP.
# Multiple hosts may be specified, each separated by a
# space. How long nss_ldap takes to failover depends on
# whether your LDAP client library supports configurable
# network or connect timeouts (see bind_timelimit).
#host 127.0.0.1

# The distinguished name of the search base.
base dc=example,dc=com

# Another way to specify your LDAP server is to provide an
uri ldap://$LDAP_SERVER_IP

# Unix Domain Sockets to connect to a local LDAP Server.
#uri ldap://127.0.0.1/
#uri ldaps://127.0.0.1/
#uri ldapi://%2fvar%2frun%2fldapi_sock/
# Note: %2f encodes the '/' used as directory separator

# The LDAP version to use (defaults to 3
# if supported by client library)
ldap_version 3

# The distinguished name to bind to the server with.
# Optional: default is to bind anonymously.
#binddn cn=proxyuser,dc=example,dc=net

# The credentials to bind with.
# Optional: default is no credential.
#bindpw secret

# The distinguished name to bind to the server with
# if the effective user ID is root. Password is
# stored in /etc/ldap.secret (mode 600)
rootbinddn cn=admin,dc=example,dc=com

# Hash password locally; required for University of
# Michigan LDAP server, and works with Netscape
# Directory Server if you're using the UNIX-Crypt
# hash mechanism and not using the NT Synchronization
# service.
pam_password crypt

# SASL mechanism for PAM authentication - use is experimental
# at present and does not support password policy control
#pam_sasl_mech DIGEST-MD5
nss_initgroups_ignoreusers _apt,backup,bin,daemon,ec2-instance-connect,fwupd-refresh,games,gnats,irc,landscape,list,lp,lxd,mail,man,messagebus,news,pollinate,proxy,root,sshd,sync,sys,syslog,systemd-coredump,systemd-network,systemd-resolve,systemd-timesync,tcpdump,tss,uucp,uuidd,www-data
EOF


apt-get install -y sssd sssd-tools

cat > /etc/sssd/sssd.conf << EOF
[sssd]
config_file_version = 2
domains = example.com

[domain/example.com]
id_provider = ldap
auth_provider = ldap
sudo_provider = ldap
ldap_uri = ldap://$LDAP_SERVER_IP
cache_credentials = False
ldap_search_base = dc=example,dc=com
EOF

chmod 600 /etc/sssd/sssd.conf

systemctl restart sssd


#Remove to avoid inteference with sshd
apt remove -y ec2-instance-connect

# sed -i "s%AuthorizedKeysCommand*%AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys%g" /etc/ssh/sshd_config
# sed -i "s%AuthorizedKeysCommandUser*%AuthorizedKeysCommandUser nobody%g" /etc/ssh/sshd_config

echo "AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys" >> /etc/ssh/sshd_config
echo "AuthorizedKeysCommandUser nobody" >> /etc/ssh/sshd_config

systemctl restart sshd

echo "session required        pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session
