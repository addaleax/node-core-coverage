#!/bin/bash
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOGFILE="out/$NOW.log"
JOBS=8

if ./coverage.sh > "$LOGFILE" 2>&1; then
  ./generate-index-html.py
  cp style.css out/style.css
else
  cat "$LOGFILE"
fi
