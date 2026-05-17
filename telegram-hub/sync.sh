#!/bin/sh
# Синхронизация HANDOVER.md / CONTEXT.md / USER.md с GitHub
# Использование: sh telegram-hub/sync.sh [-v]
# Работает в Alpine/BusyBox (sh, не bash)

VERBOSE=0
if [ "$1" = "-v" ]; then VERBOSE=1; fi

REPO_URL="https://github.com/ninamc4e/my_ai_opencode_server.git"
BRANCH="main"
NODE_NAME="server"

# Determine project root (parent of telegram-hub)
SCRIPT_DIR=$(dirname "$0")
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

[ "$VERBOSE" = "1" ] && echo "=== Sync [$NODE_NAME] ==="

# Create temp dir
SYNC_DIR=$(mktemp -d /tmp/opencode_sync.XXXXXX)

# Clone
[ "$VERBOSE" = "1" ] && echo "Cloning $REPO_URL ($BRANCH)..."
git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$SYNC_DIR" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: git clone failed"
    rm -rf "$SYNC_DIR"
    exit 1
fi

# Get remote HANDOVER.md
REMOTE_FILE="$SYNC_DIR/HANDOVER.md"
LOCAL_FILE="$PROJECT_DIR/HANDOVER.md"
DIRTY=0

if [ -f "$LOCAL_FILE" ] && [ -f "$REMOTE_FILE" ]; then
    if ! diff -q "$LOCAL_FILE" "$REMOTE_FILE" >/dev/null 2>&1; then
        [ "$VERBOSE" = "1" ] && echo "Merging HANDOVER.md..."
        # Compare first 200 chars to see relationship
        LOCAL_FIRST=$(head -c 200 "$LOCAL_FILE" 2>/dev/null || echo "")
        REMOTE_FIRST=$(head -c 200 "$REMOTE_FILE" 2>/dev/null || echo "")
        LOCAL_LAST_LINE=$(tail -1 "$LOCAL_FILE" 2>/dev/null || echo "")
        REMOTE_LAST_LINE=$(tail -1 "$REMOTE_FILE" 2>/dev/null || echo "")

        # Check if last line of remote exists in local
        if grep -qF "$REMOTE_LAST_LINE" "$LOCAL_FILE" 2>/dev/null; then
            # Local has remote's last line: local is ahead, push local
            [ "$VERBOSE" = "1" ] && echo "  Local is newer: pushing local version"
            cp "$LOCAL_FILE" "$REMOTE_FILE"
            DIRTY=1
        elif grep -qF "$LOCAL_LAST_LINE" "$REMOTE_FILE" 2>/dev/null; then
            # Remote has local's last line: remote is ahead, append local suffix
            [ "$VERBOSE" = "1" ] && echo "  Remote is newer: keeping remote + appending local diff"
            # Find unique lines in local not in remote
            tail -n +2 "$LOCAL_FILE" | while IFS= read -r line; do
                if ! grep -qFx "$line" "$REMOTE_FILE" 2>/dev/null; then
                    echo "$line"
                fi
            done > /tmp/sync_new_lines.txt
            if [ -s /tmp/sync_new_lines.txt ]; then
                printf "\n" >> "$REMOTE_FILE"
                cat /tmp/sync_new_lines.txt >> "$REMOTE_FILE"
                DIRTY=1
            fi
        else
            # Completely different: take local
            [ "$VERBOSE" = "1" ] && echo "  Content differs: taking local version"
            cp "$LOCAL_FILE" "$REMOTE_FILE"
            DIRTY=1
        fi
    fi
elif [ -f "$LOCAL_FILE" ]; then
    cp "$LOCAL_FILE" "$REMOTE_FILE"
    DIRTY=1
fi

# Copy CONTEXT.md and USER.md
for f in CONTEXT.md USER.md; do
    if [ -f "$PROJECT_DIR/$f" ]; then
        if [ ! -f "$SYNC_DIR/$f" ] || [ "$PROJECT_DIR/$f" -nt "$SYNC_DIR/$f" ] 2>/dev/null; then
            cp "$PROJECT_DIR/$f" "$SYNC_DIR/$f"
            DIRTY=1
            [ "$VERBOSE" = "1" ] && echo "  Updated $f"
        fi
    fi
done

# Push if changed
if [ "$DIRTY" = "1" ]; then
    cd "$SYNC_DIR"
    COMMIT_MSG="sync [$NODE_NAME] $(date '+%Y-%m-%d %H:%M')"
    git add -A >/dev/null 2>&1
    git diff --cached --quiet >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        git commit -m "$COMMIT_MSG" >/dev/null 2>&1
        [ "$VERBOSE" = "1" ] && echo "Pushing... $COMMIT_MSG"
        git push origin "$BRANCH" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            [ "$VERBOSE" = "1" ] && echo "Sync OK: pushed to $BRANCH"
            echo "Триедино Синхронизирован"
            echo "Дата: $(date '+%Y-%m-%d %H:%M')"
        else
            echo "ERROR: push failed (check auth)"
        fi
    else
        [ "$VERBOSE" = "1" ] && echo "No changes to push"
        echo "Триедино Синхронизирован"
        echo "Дата: $(date '+%Y-%m-%d %H:%M')"
    fi
else
    [ "$VERBOSE" = "1" ] && echo "Already in sync"
    echo "Триедино Синхронизирован"
    echo "Дата: $(date '+%Y-%m-%d %H:%M')"
fi

# 7. Check test_opencode archive for newer AGENTS.md/sync.sh
[ "$VERBOSE" = "1" ] && echo "Checking archive for updates..."
TCLONE_DIR=$(mktemp -d /tmp/opencode_tc.XXXXXX)
git clone --depth 1 https://github.com/alexsmy/test_opencode.git "$TCLONE_DIR" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    # Find latest archive by name (sorted: YYYY-MM-DD_HHMMSS)
    LATEST=$(ls "$TCLONE_DIR/migrate/"*.zip 2>/dev/null | sort -r | head -1)
    if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
        EXTRACT_DIR=$(mktemp -d /tmp/opencode_extract.XXXXXX)
        unzip -o "$LATEST" "AGENTS.md" "telegram-hub/sync.sh" -d "$EXTRACT_DIR" >/dev/null 2>&1

        # Update AGENTS.md if newer
        NEW_AGENTS="$EXTRACT_DIR/AGENTS.md"
        if [ -f "$NEW_AGENTS" ] && [ -f "$PROJECT_DIR/AGENTS.md" ]; then
            if ! diff -q "$NEW_AGENTS" "$PROJECT_DIR/AGENTS.md" >/dev/null 2>&1; then
                cp "$NEW_AGENTS" "$PROJECT_DIR/AGENTS.md"
                [ "$VERBOSE" = "1" ] && echo "  AGENTS.md updated from archive"
            fi
        fi

        # Update sync.sh if newer
        NEW_SYNC="$EXTRACT_DIR/telegram-hub/sync.sh"
        if [ -f "$NEW_SYNC" ] && [ -f "$PROJECT_DIR/telegram-hub/sync.sh" ]; then
            if ! diff -q "$NEW_SYNC" "$PROJECT_DIR/telegram-hub/sync.sh" >/dev/null 2>&1; then
                cp "$NEW_SYNC" "$PROJECT_DIR/telegram-hub/sync.sh"
                chmod +x "$PROJECT_DIR/telegram-hub/sync.sh"
                [ "$VERBOSE" = "1" ] && echo "  sync.sh updated from archive"
            fi
        fi

        rm -rf "$EXTRACT_DIR"
    fi
fi
rm -rf "$TCLONE_DIR"

# Cleanup
rm -rf "$SYNC_DIR"
rm -f /tmp/sync_new_lines.txt
