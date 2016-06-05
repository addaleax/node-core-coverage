#!/bin/bash
set -e
ORIGWD="$(pwd)"
SRCDIR="$(cd $(dirname -- ${0%/*}) && pwd)"

JOBS="${JOBS:-4}"
WORKDIR="${WORKDIR:-$ORIGWD/workdir}"
MAKE="${MAKE:-make -j$JOBS}"

echo "Switching into ${WORKDIR}..." >&2
mkdir -vp "$WORKDIR"
cd "$WORKDIR"

# get node core repo + coverage tools via git
if [ ! -d node ]; then
  git clone --depth=10 --single-branch git://github.com/nodejs/node.git
else
  # reset everything to the current master
  (cd node && \
    git fetch origin && \
    git checkout -- . && git clean -fd . && \
    git reset --hard origin/master)
fi

if [ ! -d gcovr ]; then
  git clone --depth=10 --single-branch git://github.com/gcovr/gcovr.git
  (cd gcovr && patch -p1 < "${SRCDIR}/gcovr-patches.diff")
fi

# first, a semi-normal build without lib/ coverage
cd node

echo "Now in $(pwd)" >&2

# patch things up
patch -p1 < "${SRCDIR}/patches.diff"
export PATH="$(pwd):$PATH"

# if we don't have our npm dependencies available, build node and fetch them
# with npm
if [ ! -x "$SRCDIR/node_modules/.bin/istanbul" ] || \
   [ ! -x "$SRCDIR/node_modules/.bin/istanbul-merge" ]; then
  echo "Building, without lib/ coverage..." >&2
  ./configure
  $MAKE
  ./node -v

  cd "$SRCDIR"

  # get istanbul
  node "$WORKDIR/node/deps/npm" install

  test -x "$SRCDIR/node_modules/.bin/istanbul"
  test -x "$SRCDIR/node_modules/.bin/istanbul-merge"
fi

cd "$WORKDIR/node"

echo "Instrumenting code in lib/..." >&2
"$SRCDIR/node_modules/.bin/istanbul" instrument lib/ -o lib_/
sed -e s~"'"lib/~"'"lib_/~g -i~ node.gyp

echo "Removing old coverage files" >&2
rm -rf out/Release/.coverage
rm -f out/Release/obj.target/node/src/*.gcda

echo "Building, with lib/ coverage..." >&2
./configure
$MAKE

echo "Testing..." >&2
./node -v

# This corresponds to `make test` up to removal of `message`.
python tools/test.py --mode=release -J \
  addon doctool known_issues pseudo-tty parallel sequential

echo "Gathering coverage..." >&2
mkdir -p coverage
"$SRCDIR/node_modules/.bin/istanbul-merge" --out coverage/libcov.json \
  'out/Release/.coverage/coverage-*.json'
"$SRCDIR/node_modules/.bin/istanbul" report --include coverage/libcov.json html
(cd out && "$WORKDIR/gcovr/scripts/gcovr" --gcov-exclude='.*deps' --gcov-exclude='.*usr' -v \
  -r Release/obj.target/node --html --html-detail \
  -o ../coverage/cxxcoverage.html)

OUTDIR="$ORIGWD/out"
COMMIT_ID=$(git rev-parse --short=16 HEAD)

mkdir -p "$OUTDIR"
cp -rv coverage "$OUTDIR/coverage-$COMMIT_ID"

JSCOVERAGE=$(grep -B1 Lines coverage/index.html | \
  head -n1 | grep -o '[0-9\.]*')
CXXCOVERAGE=$(grep -A3 Lines coverage/cxxcoverage.html | \
  grep style|grep -o '[0-9\.]*')

echo "JS Coverage: $JSCOVERAGE %"
echo "C++ Coverage: $CXXCOVERAGE %"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$JSCOVERAGE,$CXXCOVERAGE,$NOW,$COMMIT_ID" >> "$OUTDIR/index.csv"

cd "$ORIGWD"
