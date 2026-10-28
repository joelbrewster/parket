#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

toolchain="$HOME/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin"
if [[ -x "$toolchain/swift" ]]; then
  export PATH="$toolchain:$PATH"
fi

stop_parket() {
  pkill -9 -x parket 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x parket >/dev/null || return 0
    sleep 0.1
  done
}

stop_parket
make install
stop_parket
open /Applications/parket.app
