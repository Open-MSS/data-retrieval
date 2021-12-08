pathadd() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="${PATH:+"$PATH:"}$1"
    fi
}

pathadd /usr/local/apps/cdo/1.9.8/bin
pathadd /usr/local/apps/nco/4.9.7/bin
pathadd /usr/local/apps/python3/3.8.8-01/bin
pathadd /usr/local/apps/cdo/1.9.5/deps/bin
