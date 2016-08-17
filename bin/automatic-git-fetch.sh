#! /bin/sh

logFile=/home/coates/automatic-git-fetch.log

for repo in /home/coates/source/fm-src.bare /home/coates/source/libraries-shared.bare; do
    echo >> $logFile
    date --iso-8601=seconds >> $logFile
    echo $repo >> $logFile
    cd $repo && git fetch --prune --all 2>&1 >> $logFile 
done

