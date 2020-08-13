#!/usr/bin/env bash
set -euo pipefail

RELEASE=$1
UMBREL_ROOT=$2

# Only used on Umbrel OS
SD_CARD_UMBREL_ROOT="/sd-root${UMBREL_ROOT}"

echo
echo "======================================="
echo "============= OTA UPDATE =============="
echo "======================================="
echo "=========== Stage: Install ============"
echo "======================================="
echo

[[ -f "/etc/default/umbrel" ]] && source "/etc/default/umbrel"

# Make Umbrel OS specific updates
if [[ ! -z "${UMBREL_OS:-}" ]]; then
    echo 
    echo "============================================="
    echo "Installing on Umbrel OS $UMBREL_OS"
    echo "============================================="
    echo
    
    # Update SD card installation
    if  [[ -f "${SD_CARD_UMBREL_ROOT}/.umbrel" ]]; then
        echo "Replacing ${SD_CARD_UMBREL_ROOT} on SD card with the new release"
        rsync --archive \
            --verbose \
            --include-from="${UMBREL_ROOT}/.umbrel-${RELEASE}/scripts/update/.updateinclude" \
            --exclude-from="${UMBREL_ROOT}/.umbrel-${RELEASE}/scripts/update/.updateignore" \
            --delete \
            "${UMBREL_ROOT}/.umbrel-${RELEASE}/" \
            "${SD_CARD_UMBREL_ROOT}/"

        echo "Fixing permissions"
        chown -R 1000:1000 "${SD_CARD_UMBREL_ROOT}/"
    else
        echo "ERROR: No Umbrel installation found at SD root ${SD_CARD_UMBREL_ROOT}"
        echo "Skipping updating on SD Card..."
    fi
fi

cat <<EOF > "$UMBREL_ROOT"/statuses/update-status.json
{"state": "installing", "progress": 33, "description": "Configuring settings", "updateTo": "$RELEASE"}
EOF

# Checkout to the new release
cd "$UMBREL_ROOT"/.umbrel-"$RELEASE"

# Configure new install
echo "Configuring new release"
cat <<EOF > "$UMBREL_ROOT"/statuses/update-status.json
{"state": "installing", "progress": 40, "description": "Configuring new release", "updateTo": "$RELEASE"}
EOF

BITCOIN_NETWORK="mainnet"
[[ -f "$UMBREL_ROOT/.env" ]] && source "$UMBREL_ROOT/.env"
NETWORK=$BITCOIN_NETWORK ./scripts/configure

# Stop existing containers
echo "Stopping existing containers"
cat <<EOF > "$UMBREL_ROOT"/statuses/update-status.json
{"state": "installing", "progress": 70, "description": "Removing old containers", "updateTo": "$RELEASE"}
EOF
cd "$UMBREL_ROOT"
./scripts/stop

# Overlay home dir structure with new dir tree
echo "Overlaying $UMBREL_ROOT/ with new directory tree"
rsync --archive \
    --verbose \
    --include-from="$UMBREL_ROOT/.umbrel-$RELEASE/scripts/update/.updateinclude" \
    --exclude-from="$UMBREL_ROOT/.umbrel-$RELEASE/scripts/update/.updateignore" \
    --delete \
    "$UMBREL_ROOT"/.umbrel-"$RELEASE"/ \
    "$UMBREL_ROOT"/

# Fix permissions
echo "Fixing permissions"
chown -R 1000:1000 "$UMBREL_ROOT"/
chmod -R 700 "$UMBREL_ROOT"/tor/data/*

# Start updated containers
echo "Starting new containers"
cat <<EOF > "$UMBREL_ROOT"/statuses/update-status.json
{"state": "installing", "progress": 80, "description": "Starting new containers", "updateTo": "$RELEASE"}
EOF
cd "$UMBREL_ROOT"
./scripts/start
