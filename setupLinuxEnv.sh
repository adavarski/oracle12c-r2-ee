#!/bin/bash

# ------------------------------------------------------------
mkdir -p $ORACLE_BASE/scripts/setup && \
mkdir $ORACLE_BASE/scripts/startup && \
ln -s $ORACLE_BASE/scripts /docker-entrypoint-initdb.d && \
mkdir $ORACLE_BASE/oradata && \
chmod ug+x $ORACLE_BASE/*.sh && \
yum -y install oracle-database-server-12cR2-preinstall unzip tar openssl && \
yum clean all && \
echo oracle:oracle | chpasswd && \
chown -R oracle:dba $ORACLE_BASE
