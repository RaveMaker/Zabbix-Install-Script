#!/bin/bash

# ZABBIX INSTALL SCRIPT

# VER. 0.7.0 - http://blog.brendon.com
# Copyright (c) 2008-2012 Brendon Baumgartner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#=====================================================================

#
# Updated by RaveMaker - http://ravemaker.net
#

# If necessary, edit these for your system
DBUSER='root'
DBPASS=''
DBHOST='localhost'

echo "Input Zabbix version in this format: 2.0.6"
read ZBX_VER

# DO NOT EDIT BELOW THIS LINE

function checkReturn {
  if [ $1 -ne 0 ]; then
     echo "fail: $2"
     echo "$3"
     exit
  else
     echo "pass: $2"
  fi
  sleep 3
}

cat << "eof"

=== RUN AT YOUR OWN RISK ===

DO NOT RUN ON EXISTING INSTALLATIONS, YOU *WILL* LOSE DATA

This script:
 * Installs Zabbix 2.0.x on CentOS / Red Hat 6
 * Drops an existing database
 * Does not install MySQL; to install type "yum install mysql-server"
 * Assums a vanilla OS install, though it tries to work around it
 * Does not install zabbix packages, it uses source from zabbix.com
 * Disables firewall

eof

read -p 'Type "go" to continue: ' RESP
if [ "$RESP" != "go" ]; then
  echo "Sorry to hear it"
  exit
else
  echo "Lets do this..."
fi

# check selinux
if [ "`sestatus |grep status|awk '{ print $3 }'`" == "enabled" ]; then
   checkReturn 1 "Disable SELinux and then retry"
fi

#disable firewall
chkconfig iptables off
/etc/init.d/iptables stop
  
# Start mysql if its on this box
if [ "`rpm -qa |grep mysql-server`" ]; then
  chkconfig mysqld on
  service mysqld restart
fi

# check mysql
mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS} > /dev/null << eof
status
eof
RETVAL=$?
checkReturn $RETVAL "basic mysql access" "Install mysql server packages or fix mysql permissions"


if [ ! "`rpm -qa|grep fping`" ]; then
  if [ "`uname -m`" == "x86_64" ]; then
     rpm -Uhv http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
  elif [ "`uname -m`" == "i686" ]; then
     rpm -Uhv http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.i686.rpm
  fi
fi

# removed  libidn-devel iksemel-devel 
# dependenices for curl: e2fsprogs-devel zlib-devel libgssapi-devel krb5-devel openssl-devel
yum -y install gcc mysql-devel curl-devel httpd php php-mysql php-bcmath php-gd php-xml php-mbstring net-snmp-devel fping e2fsprogs-devel zlib-devel libgssapi-devel krb5-devel openssl-devel wget libssh2-devel openldap-devel make patch
RETVAL=$?
checkReturn $RETVAL "Package install"

chmod 4755 /usr/sbin/fping

cd /tmp

# jabber packages are incomplete at rpmforge (iksemel)
# BEGIN pkgs for jabber (--with-jabber)
#wget http://dl.atrpms.net/el6-x86_64/atrpms/stable/libiksemel3-1.4-2_2.el6.x86_64.rpm
#rpm -i /tmp/libiksemel3-1.4-2_2.el6.x86_64.rpm
#wget http://dl.atrpms.net/el6-x86_64/atrpms/stable/iksemel-1.4-2_2.el6.x86_64.rpm
#rpm -i /tmp/iksemel-1.4-2_2.el6.x86_64.rpm
#wget http://dl.atrpms.net/el6-x86_64/atrpms/stable/iksemel-devel-1.4-2_2.el6.x86_64.rpm
#rpm -i /tmp/iksemel-devel-1.4-2_2.el6.x86_64.rpm
# END pkgs for jabber


rm -rf /etc/zabbix
rm -rf zabbix-$ZBX_VER
rm zabbix-$ZBX_VER.tar.gz
#wget http://sourceforge.net/projects/zabbix/files/latest/download?source=files
#wget http://downloads.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/$ZBX_VER/zabbix-$ZBX_VER.tar.gz
wget http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/$ZBX_VER/zabbix-$ZBX_VER.tar.gz
RETVAL=$?
checkReturn $RETVAL "downloading source" "check ZBX_VER variable or mirror might be down"
tar xzf zabbix-$ZBX_VER.tar.gz
cd zabbix-$ZBX_VER

./configure --enable-agent  --enable-ipv6  --enable-proxy  --enable-server --with-mysql --with-libcurl --with-net-snmp --with-ssh2 --with-ldap --sysconfdir=/etc/zabbix
RETVAL=$?
checkReturn $RETVAL "Configure"
# --with-jabber
# ipmi
# ldap


make
RETVAL=$?
checkReturn $RETVAL "Compile"

make install
RETVAL=$?
checkReturn $RETVAL "make install"

echo "DROP DATABASE IF EXISTS zabbix;" | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS}

(
echo "CREATE DATABASE zabbix;"
echo "USE zabbix;"
cat /tmp/zabbix-$ZBX_VER/database/mysql/schema.sql
cat /tmp/zabbix-$ZBX_VER/database/mysql/images.sql
cat /tmp/zabbix-$ZBX_VER/database/mysql/data.sql
) | mysql -h${DBHOST} -u${DBUSER} --password=${DBPASS}


#### BEGIN ZABBIX SERVER & AGENT PROCESS INSTALL & START
adduser -r -d /var/run/zabbix-server -s /sbin/nologin zabbix
#mkdir -p /etc/zabbix/alert.d
mkdir -p /var/log/zabbix-server
mkdir -p /var/log/zabbix-agent
mkdir -p /var/run/zabbix-server
mkdir -p /var/run/zabbix-agent
chown zabbix.zabbix /var/run/zabbix*
chown zabbix.zabbix /var/log/zabbix*
#cp /tmp/zabbix-$ZBX_VER/misc/conf/zabbix_server.conf /etc/zabbix
#cp /tmp/zabbix-$ZBX_VER/misc/conf/zabbix_agentd.conf /etc/zabbix

cp /tmp/zabbix-$ZBX_VER/misc/init.d/fedora/core5/zabbix_server /etc/init.d
cp /tmp/zabbix-$ZBX_VER/misc/init.d/fedora/core5/zabbix_agentd /etc/init.d


cd /etc/zabbix
patch -p0 -l << "eof"
--- orig/zabbix_server.conf     2012-07-01 18:30:00.585612301 -0700
+++ zabbix_server.conf  2012-07-01 18:58:15.181605999 -0700
@@ -36,7 +36,7 @@
 # Default:
 # LogFile=

-LogFile=/tmp/zabbix_server.log
+LogFile=/var/log/zabbix-server/zabbix_server.log

 ### Option: LogFileSize
 #      Maximum size of log file in MB.
@@ -65,7 +65,7 @@
 #
 # Mandatory: no
 # Default:
-# PidFile=/tmp/zabbix_server.pid
+PidFile=/var/run/zabbix-server/zabbix_server.pid

 ### Option: DBHost
 #      Database host name.
@@ -100,7 +100,7 @@
 # Default:
 # DBUser=

-DBUser=root
+DBUser=_dbuser_

 ### Option: DBPassword
 #      Database password. Ignored for SQLite.
@@ -109,6 +109,7 @@
 # Mandatory: no
 # Default:
 # DBPassword=
+DBPassword=_dbpass_

 ### Option: DBSocket
 #      Path to MySQL socket.
eof


sed "s/_dbuser_/${DBUSER}/g" /etc/zabbix/zabbix_server.conf > /tmp/mytmp393; mv /tmp/mytmp393 /etc/zabbix/zabbix_server.conf
sed "s/_dbpass_/${DBPASS}/g" /etc/zabbix/zabbix_server.conf > /tmp/mytmp393; mv /tmp/mytmp393 /etc/zabbix/zabbix_server.conf


patch -p0 -l << "eof"
--- orig/zabbix_agentd.conf     2012-07-01 18:30:00.585612301 -0700
+++ zabbix_agentd.conf  2012-07-01 18:55:40.566660188 -0700
@@ -9,6 +9,7 @@
 # Mandatory: no
 # Default:
 # PidFile=/tmp/zabbix_agentd.pid
+PidFile=/var/run/zabbix-agent/zabbix_agentd.pid

 ### Option: LogFile
 #      Name of log file.
@@ -18,7 +19,7 @@
 # Default:
 # LogFile=

-LogFile=/tmp/zabbix_agentd.log
+LogFile=/var/log/zabbix-agent/zabbix_agentd.log

 ### Option: LogFileSize
 #      Maximum size of log file in MB.
@@ -57,6 +58,7 @@
 # Mandatory: no
 # Default:
 # EnableRemoteCommands=0
+EnableRemoteCommands=1

 ### Option: LogRemoteCommands
 #      Enable logging of executed shell commands as warnings.
eof



chkconfig zabbix_server on
chkconfig zabbix_agentd on
chmod +x /etc/init.d/zabbix_server
chmod +x /etc/init.d/zabbix_agentd
service zabbix_server restart
service zabbix_agentd restart

#### END ZABBIX SERVER & AGENT PROCESS INSTALL & START

#### BEGIN WEB

rm -rf /usr/local/share/zabbix
mkdir -p /usr/local/share/zabbix
cp -r /tmp/zabbix-$ZBX_VER/frontends/php/* /usr/local/share/zabbix

echo "Alias /zabbix /usr/local/share/zabbix" > /etc/httpd/conf.d/zabbix.conf

echo "post_max_size = 16M" > /etc/php.d/local_zabbix.ini
echo "max_execution_time = 300" >> /etc/php.d/local_zabbix.ini
echo "max_input_time = 300" >> /etc/php.d/local_zabbix.ini
. /etc/sysconfig/clock
echo "date.timezone = $ZONE" >>  /etc/php.d/local_zabbix.ini

chkconfig httpd on
service httpd restart

#sed "s/max_execution_time = 30/max_execution_time = 300/g" /etc/php.ini > /tmp/mytmp393; mv /tmp/mytmp393 /etc/php.ini

#touch /usr/local/share/zabbix/conf/zabbix.conf.php
#chmod 666 /usr/local/share/zabbix/conf/zabbix.conf.php


cat > /usr/local/share/zabbix/conf/zabbix.conf.php << "eof"
<?php
// Zabbix GUI configuration file
global $DB;

$DB['TYPE']             = "MYSQL";
$DB['SERVER']           = "_dbhost_";
$DB['PORT']             = "0";
$DB['DATABASE']         = "zabbix";
$DB['USER']             = "_dbuser_";
$DB['PASSWORD']         = "_dbpass_";

// SCHEMA is relevant only for IBM_DB2 database
$DB['SCHEMA']                   = '';

$ZBX_SERVER             = "127.0.0.1";
$ZBX_SERVER_PORT        = "10051";
$ZBX_SERVER_NAME	= 'myzabbix';


$IMAGE_FORMAT_DEFAULT   = IMAGE_FORMAT_PNG;
?>
eof

sed "s/_dbhost_/${DBHOST}/g" /usr/local/share/zabbix/conf/zabbix.conf.php > /tmp/mytmp393; mv /tmp/mytmp393 /usr/local/share/zabbix/conf/zabbix.conf.php
sed "s/_dbuser_/${DBUSER}/g" /usr/local/share/zabbix/conf/zabbix.conf.php > /tmp/mytmp393; mv /tmp/mytmp393 /usr/local/share/zabbix/conf/zabbix.conf.php
sed "s/_dbpass_/${DBPASS}/g" /usr/local/share/zabbix/conf/zabbix.conf.php > /tmp/mytmp393; mv /tmp/mytmp393 /usr/local/share/zabbix/conf/zabbix.conf.php


cd 
echo "Load http://localhost/zabbix/"
echo "username: admin"
echo "password: zabbix"

