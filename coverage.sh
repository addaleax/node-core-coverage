#!/bin/bash
set -e
ORIGWD="$(pwd)"
SRCDIR="$(cd $(dirname -- ${0%/*}) && pwd)"

WORKDIR="${WORKDIR:-$ORIGWD/workdir}"

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
  ./node -v
  ./configure
  make -j8

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

echo "Building, with lib/ coverage..." >&2
./configure
make -j8

echo "Testing..." >&2
./node -v

# This corresponds to `make test` up to addition of `internet` and removal
# of `message`.
python tools/test.py --mode=release -J \
  addon doctool known_issues internet parallel sequential

echo "Gathering coverage..." >&2
mkdir -p coverage
"$SRCDIR/node_modules/.bin/istanbul-merge" --out coverage/libcov.json \
  'out/Release/.coverage/coverage-*.json'
"$SRCDIR/node_modules/.bin/istanbul" report --include coverage/libcov.json html
(cd out && "$WORKDIR/gcovr/scripts/gcovr" --gcov-exclude='.*deps' --gcov-exclude='.*usr' -v \
  -r Release/obj.target/node --html --html-detail \
  -o ../coverage/cxxcoverage.html)

COMMIT_ID=$(git rev-parse --short=12 HEAD)
OUTFILE="$ORIGWD/coverage-$COMMIT_ID.tar.xz"
tar cJvvf "$OUTFILE" coverage/

cd "$ORIGWD"

echo "$OUTFILE"
