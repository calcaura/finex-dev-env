#!/bin/bash

if [ -z "$PECUNIA_SRC" ]; then
    echo "PECUNIA_SRC is not set. Please set it to the path of the pecunia src repository."
    exit 1
fi

REBUILD_PECUNIA=${REBUILD_PECUNIA:-1}
PECUNIA_BIN=${PECUNIA_SRC}/target/debug/pecunia_web_server

if [[ ! -f ${PECUNIA_BIN} ]] || [[ "$REBUILD_PECUNIA" == "1" ]]; then
    cargo build -p pecunia_web_server || exit 1
else
    echo "Pecunia is already built. To rebuild it, set REBUILD_PECUNIA=1"
fi


exec $PECUNIA_BIN $@