#! /bin/sh

logFile=/home/coates/automatic-git-fetch.log

for repo in /home/coates/source/qps-dev.git; do
    echo >> $logFile
    date --iso-8601=seconds >> $logFile
    echo $repo >> $logFile
    cd $repo && git fetch --prune --all >> $logFile 2>&1
done

