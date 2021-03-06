#!/bin/bash
# opentsdb MapR-DB script
# this scripts makes the necessary arrangements to run opentsdb on MapR-DB
#
# opentsdb must be installed, either using .rpm or "make install" after building it

# Go with the first hadoop found in /opt/mapr/hadoop
HADOOP_HOME=$(find /opt/mapr/hadoop -maxdepth 1 -type d -name "hadoop-*" | head -1)

OPENTSDB_HOME=''

if [[ -d "/usr/share/opentsdb" ]]
then
    OPENTSDB_HOME=/usr/share/opentsdb
elif [[ -d "/usr/local/share/opentsdb" ]]
then
    OPENTSDB_HOME=/usr/local/share/opentsdb
fi

if [[ $OPENTSDB_HOME -eq '' ]]
then
    echo "OpenTSDB not found on this host please edit this script and set it."
    exit 1
fi

#******************************************
# first check if required folders are available
echo "Check if required folders exist..."

test -d "$HADOOP_HOME" || {
  echo >&2 "'$HADOOP_HOME' doesn't exist, is mapr-client installed ?"
  exit 1
}
test -d "$OPENTSDB_HOME" || {
  echo >&2 "'$OPENTSDB_HOME' doesn't exist, is openTSDB installed?"
  exit 1
}

echo "Using Hadoop libraries found in ${HADOOP_HOME}"
#******************************************
# link the necessary jars from $HADOOP_HOME to OPENTSDB_HOME/lib
# Base of MapR installation

case $(basename $HADOOP_HOME) in
    hadoop-0*)
      HADOOP_LIB_DIR="$HADOOP_HOME"/lib
      ;;
    hadoop-2*)
      HADOOP_LIB_DIR="$HADOOP_HOME"/share/hadoop/common
      ;;
esac

for jar in $(find $HADOOP_LIB_DIR -name "*.jar"); do
  if [ "`echo $jar | grep slf4j`" != "" ] || [ "`echo $jar | grep netty`" != "" ]; then
    continue
  fi
  echo "linking $jar..."
  ln -s "$jar" "$OPENTSDB_HOME/lib/"
done


#******************************************
# download 'asynchbase-*-mapr.jar' into OPENTSDB_HOME
#
# A support matrix for version of mapr and the asynchbase library - http://doc.mapr.com/display/MapR/Ecosystem+Support+Matrix
#

VERSION=`cat /opt/mapr/MapRBuildVersion`

if [[ $VERSION == 5.* ]]; then
  echo "MapR 5.x installed. Downloading asynchbase 1.6.0"
  async_link=http://repository.mapr.com/nexus/content/groups/mapr-public/org/hbase/asynchbase/1.6.0-mapr-1503/asynchbase-1.6.0-mapr-1503.jar
elif [[ $VERSION == 4.1.* ]]; then
  echo "MapR 4.1.x installed. Downloading asynchbase 1.6.0"
  async_link=http://repository.mapr.com/nexus/content/groups/mapr-public/org/hbase/asynchbase/1.6.0-mapr-1503/asynchbase-1.6.0-mapr-1503.jar
elif [[ $VERSION == 4.0.* ]]; then
  echo "MapR 4.0.x installed. Downloading asynchbase 1.5.0"
  async_link=http://repository.mapr.com/nexus/content/groups/mapr-public/org/hbase/asynchbase/1.5.0-mapr-1501/asynchbase-1.5.0-mapr-1501.jar
elif [[ $VERSION == 3.* ]]; then 
  echo "MapR 3.x installed. Downloading asynchbase 1.4.1"
  async_link=http://repository.mapr.com/nexus/content/groups/mapr-public/org/hbase/asynchbase/1.4.1-mapr-1501/asynchbase-1.4.1-mapr-1501.jar
else
  echo "Unknown version of MapR! This script needs to be updated!"
  exit 1
fi

async_file=`basename "$async_link"`

# but first check if it isn't already downloaded
test -f "$OPENTSDB_HOME/lib/$async_file" && {
  echo >&2 "'$async_file' found, no need to download it again"
  exit 0
}

wget $async_link -O "./$async_file-t"

#TODO we should probably checksum the file to make sure it downloaded correctly

# we need to replace the existing asynchbase jar by the one we will download from mapr
if ls $OPENTSDB_HOME/lib/asynchbase* &> /dev/null; then
  old_async=$(ls $OPENTSDB_HOME/lib/asynchbase*)
  mv $old_async "$old_async-old"
fi

mv "./$async_file-t" "$OPENTSDB_HOME/lib/$async_file"
