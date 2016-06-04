#!/bin/bash
set -e
ORIGWD="$(pwd)"
SRCDIR="$(cd $(dirname -- ${0%/*}) && pwd)"

WORKDIR="$(mktemp -d)"

echo "Switching into ${WORKDIR}..." >&2
cd "$WORKDIR"

# get node core repo + coverage tools via git
git clone --depth=10 --single-branch git://github.com/nodejs/node.git
git clone --depth=10 --single-branch git://github.com/gcovr/gcovr.git

(cd gcovr && patch -p1 < "${SRCDIR}/gcovr-patches.diff")

# first, a semi-normal build without lib/ coverage
cd node

echo "Now in $(pwd)" >&2

# patch things up
patch -p1 < "${SRCDIR}/patches.diff"

echo "Building, without lib/ coverage..." >&2
./configure
make -j8

export PATH="$(pwd):$PATH"

cd "$WORKDIR"

# get istanbul
cp "$SRCDIR/package.json" package.json
node "$WORKDIR/node/deps/npm" install
test -x node_modules/.bin/istanbul
test -x node_modules/.bin/istanbul-merge

cd node

echo "Instrumenting code in lib/..." >&2
"$WORKDIR/node_modules/.bin/istanbul" instrument lib/ -o lib_/
sed -e s~"'"lib/~"'"lib_/~g -i node.gyp

echo "Building, with lib/ coverage..." >&2
./configure
make -j8

echo "Testing..." >&2
./node -v

# This corresponds to `make test` up to addition of `internet` and removal
# of `message`.
python tools/test.py --mode=release -J \
  addon doctool known_issues internet parallel pummel sequential

echo "Gathering coverage..." >&2
mkdir -p coverage
"$WORKDIR/node_modules/.bin/istanbul-merge" --out coverage/libcov.json \
  'out/Release/.coverage/coverage-*.json'
"$WORKDIR/node_modules/.bin/istanbul" report --include coverage/libcov.json html
(cd out && "$WORKDIR/gcovr/scripts/gcovr" --gcov-exclude='.*deps' --gcov-exclude='.*usr' -v \
  -r Release/obj.target/node --html --html-detail \
  -o ../coverage/cxxcoverage.html)

COMMIT_ID=$(git rev-parse --short=12 HEAD)
OUTFILE="$ORIGWD/coverage-$COMMIT_ID.tar.xz"
tar cJvvf "$OUTFILE" coverage/

cd "$ORIGWD"
rm -rf "$WORKDIR"

echo "$OUTFILE"
