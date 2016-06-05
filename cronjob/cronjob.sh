#!/bin/bash
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOGFILE="out/$NOW.log"
export JOBS=8

mkdir -p out
if ./coverage.sh > "$LOGFILE" 2>&1; then
  ./generate-index-html.py
  cp style.css out/style.css
else
  cat "$LOGFILE"
fi
