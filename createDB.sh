#!/bin/bash

set -e

# Check whether ORACLE_SID is passed on
export ORACLE_SID=${ORACLE_SID:-ORCLCDB}
echo "ORACLE_SID: $ORACLE_SID";


# Check whether ORACLE_PDB is passed on
export ORACLE_PDB=${ORACLE_PDB:-ORCLPDB1}
echo "ORACLE_PDB: $ORACLE_PDB";

# Auto generate ORACLE PWD if not passed on
export ORACLE_PWD=${ORACLE_PWD:-"`openssl rand -base64 8`1"}
echo "ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: $ORACLE_PWD";

# Flag to create database as container database
export ORACLE_CDB=${ORACLE_CDB:-false}
echo "ORACLE_CDB: $ORACLE_CDB";

# Specify the number of pdb to be created (0 to 4094)
export ORACLE_PDB_NUM=${ORACLE_PDB_NUM:-0}
echo "ORACLE_PDB_NUM: $ORACLE_PDB_NUM";

# Total memory in MB to allocate to Oracle
export ORACLE_MEM=${ORACLE_MEM:-2048}
echo "ORACLE_MEM: $ORACLE_MEM";

# Replace place holders in response file
cp $ORACLE_BASE/$CONFIG_RSP $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_SID###|$ORACLE_SID|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PDB###|$ORACLE_PDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_CHARACTERSET###|$ORACLE_CHARACTERSET|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_CDB###|$ORACLE_CDB|g" $ORACLE_BASE/dbca.rsp
sed -i -e "s|###ORACLE_PDB_NUM###|$ORACLE_PDB_NUM|g" $ORACLE_BASE/dbca.rsp

# If there is greater than 8 CPUs default back to dbca memory calculations
# dbca will automatically pick 40% of available memory for Oracle DB
# The minimum of 2G is for small environments to guarantee that Oracle has enough memory to function
# However, bigger environment can and should use more of the available memory
# This is due to Github Issue #307
if [ `nproc` -gt 8 ]; then
  unset ORACLE_MEM
  echo "Number of processors > 8, resetting Oracle memory to 40% of available memory";
fi;
sed -i -e "s|###ORACLE_MEM###|$ORACLE_MEM|g" $ORACLE_BASE/dbca.rsp


# Create network related config files (sqlnet.ora, tnsnames.ora, listener.ora)
mkdir -p $ORACLE_HOME/network/admin
echo "NAME.DIRECTORY_PATH= (TNSNAMES, EZCONNECT, HOSTNAME)" > $ORACLE_HOME/network/admin/sqlnet.ora

# Listener.ora
echo "LISTENER =
(DESCRIPTION_LIST =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1))
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  )
)

DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off
" > $ORACLE_HOME/network/admin/listener.ora

# Start LISTENER and run DBCA
lsnrctl start &&
dbca -silent -createDatabase -responseFile $ORACLE_BASE/dbca.rsp ||
 cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID/$ORACLE_SID.log ||
 cat /opt/oracle/cfgtoollogs/dbca/$ORACLE_SID.log

echo "$ORACLE_SID=localhost:1521/$ORACLE_SID" > $ORACLE_HOME/network/admin/tnsnames.ora
echo "$ORACLE_PDB=
(DESCRIPTION =
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = $ORACLE_PDB)
  )
)" >> $ORACLE_HOME/network/admin/tnsnames.ora

# Remove second control file, make PDB auto open
sqlplus / as sysdba << EOF
   ALTER SYSTEM SET control_files='$ORACLE_BASE/oradata/$ORACLE_SID/control01.ctl' scope=spfile;
   ALTER PLUGGABLE DATABASE $ORACLE_PDB SAVE STATE;
   exit;
EOF

# Remove temporary response file
rm $ORACLE_BASE/dbca.rsp
