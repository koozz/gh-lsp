#!/usr/bin/env bash

# This script is used to test the bash-language-server.
# It also depends on the executable `shellcheck`.
set -euo pipefail

# Classic export warning
export MYVAR="test bash-language-server"

# Missing closing 'fi'
if [[ -z "${BASH_VERSION:-}" ]]; then
	echo "This script requires bash to run."
	exit 1
fi

cd "$(dirname "$0")" || exit 1

# Loop without 'do'
for f in `ls`;
	echo $f
done
