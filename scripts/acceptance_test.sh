#!/bin/bash
# scripts/acceptance_test.sh
# PTY-level acceptance tests for all fafafa.tui examples.
# Drives demos through tmux and verifies output by inspecting pane content.
#
# Requirements: tmux, make (examples must be built first)
# Usage: make acceptance

set -uo pipefail

BIN="./build/bin"
SESSION="ftui_acc_$$"
PASS=0
FAIL=0
TOTAL_PASS=0
TOTAL_FAIL=0

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

assert_contains() {
  local desc="$1" pattern="$2" content="$3"
  if echo "$content" | grep -q "$pattern"; then
    echo "  ok      $desc"
    ((PASS++))
  else
    echo "  FAIL    $desc (pattern '$pattern' not found)"
    ((FAIL++))
  fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" content="$3"
  if echo "$content" | grep -q "$pattern"; then
    echo "  FAIL    $desc (pattern '$pattern' should not be present)"
    ((FAIL++))
  else
    echo "  ok      $desc"
    ((PASS++))
  fi
}

assert_exit_clean() {
  local desc="$1"
  sleep 0.3
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    local pane_dead
    pane_dead=$(tmux display-message -t "$SESSION" -p '#{pane_dead}' 2>/dev/null || echo "")
    if [ "$pane_dead" = "1" ]; then
      echo "  ok      $desc"
      ((PASS++))
    else
      echo "  FAIL    $desc (process still running)"
      ((FAIL++))
    fi
  else
    echo "  ok      $desc"
    ((PASS++))
  fi
}

start_demo() {
  local demo="$1"
  cleanup
  tmux new-session -d -s "$SESSION" -x 80 -y 24 "$BIN/$demo"
  tmux set-option -t "$SESSION" remain-on-exit on 2>/dev/null
  tmux set-option -t "$SESSION" escape-time 0 2>/dev/null
  sleep 0.5
}

report_group() {
  local name="$1"
  TOTAL_PASS=$((TOTAL_PASS + PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + FAIL))
  PASS=0
  FAIL=0
}

if ! command -v tmux &>/dev/null; then
  echo "SKIP: tmux not installed"
  exit 0
fi

echo "=== fafafa.tui acceptance tests ==="
echo

# --- hello_box: auto-exits after 800ms, renders bordered box ---
echo ">> hello_box"
start_demo "hello_box"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "box rendered" "fafafa.tui" "$CONTENT"
sleep 1.0
assert_exit_clean "exits after timeout"
report_group "hello_box"

# --- chat_mock: auto-exits, renders cli888 layout ---
echo ">> chat_mock"
start_demo "chat_mock"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "title bar rendered" "fafafa.tui" "$CONTENT"
assert_contains "message list visible" "messages" "$CONTENT"
assert_contains "user message visible" "hello" "$CONTENT"
sleep 1.0
assert_exit_clean "exits after timeout"
report_group "chat_mock"

# --- layout_demo: auto-exits, renders colored regions ---
echo ">> layout_demo"
start_demo "layout_demo"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "header rendered" "fafafa" "$CONTENT"
sleep 1.0
assert_exit_clean "exits after timeout"
report_group "layout_demo"

# --- cjk_demo: interactive, quit with 'q' ---
echo ">> cjk_demo"
start_demo "cjk_demo"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "CJK title rendered" "fafafa.tui" "$CONTENT"
assert_contains "Chinese message visible" "world" "$CONTENT"
# Navigate down
tmux send-keys -t "$SESSION" Down
sleep 0.2
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "selection moved" "1" "$CONTENT"
# Quit
tmux send-keys -t "$SESSION" "q"
sleep 0.5
assert_exit_clean "q quits cleanly"
report_group "cjk_demo"

# --- full_demo: interactive list navigation ---
echo ">> full_demo"
start_demo "full_demo"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "list renders" "item" "$CONTENT"
# Navigate
tmux send-keys -t "$SESSION" Down Down Down
sleep 0.3
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "selection indicator" ">" "$CONTENT"
# Select with Enter
tmux send-keys -t "$SESSION" Enter
sleep 0.2
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "selection recorded" "selected" "$CONTENT"
# Quit
tmux send-keys -t "$SESSION" "q"
sleep 0.5
assert_exit_clean "q quits cleanly"
report_group "full_demo"

# --- streaming_demo: streaming text appears ---
echo ">> streaming_demo"
start_demo "streaming_demo"
sleep 1.0
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "streaming text visible" "streaming" "$CONTENT"
# Quit
tmux send-keys -t "$SESSION" "q"
sleep 0.5
assert_exit_clean "q quits cleanly"
report_group "streaming_demo"

# --- popup_demo: modal popup ---
echo ">> popup_demo"
start_demo "popup_demo"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "background list visible" "Item" "$CONTENT"
# Open popup
tmux send-keys -t "$SESSION" Enter
sleep 0.3
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "popup appeared" "Enter or Esc" "$CONTENT"
# Dismiss popup
tmux send-keys -t "$SESSION" Escape
sleep 0.5
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_not_contains "popup dismissed" "Enter or Esc" "$CONTENT"
# Quit
tmux send-keys -t "$SESSION" "q"
sleep 0.5
assert_exit_clean "q quits cleanly"
report_group "popup_demo"

# --- tabs_demo: tab switching ---
echo ">> tabs_demo"
start_demo "tabs_demo"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "tab bar visible" "Chat" "$CONTENT"
assert_contains "tab 1 content" "Welcome" "$CONTENT"
# Switch to tab 2
tmux send-keys -t "$SESSION" "2"
sleep 0.3
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "tab 2 active" "Files" "$CONTENT"
# Quit
tmux send-keys -t "$SESSION" "q"
sleep 0.5
assert_exit_clean "q quits cleanly"
report_group "tabs_demo"

# --- canvas_overlay_demo: mouse interaction ---
echo ">> canvas_overlay_demo"
start_demo "canvas_overlay_demo"
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "canvas renders" "Move mouse" "$CONTENT"
# Mouse move
tmux send-keys -t "$SESSION" -l $'\e[<35;20;10M'
sleep 0.3
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "mouse position updated" "(19,9)" "$CONTENT"
# Drag
tmux send-keys -t "$SESSION" -l $'\e[<0;10;5M'
sleep 0.1
tmux send-keys -t "$SESSION" -l $'\e[<32;15;5M'
sleep 0.2
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "drag active" "DRAGGING" "$CONTENT"
# Release
tmux send-keys -t "$SESSION" -l $'\e[<0;15;5m'
sleep 0.3
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_not_contains "drag ended" "DRAGGING" "$CONTENT"
# Esc quits
tmux send-keys -t "$SESSION" Escape
sleep 1.0
tmux send-keys -t "$SESSION" Escape
sleep 1.0
assert_exit_clean "Esc quits cleanly"
report_group "canvas_overlay_demo"

# --- Summary ---
cleanup
echo
echo "=== Results: $TOTAL_PASS passed, $TOTAL_FAIL failed ==="
[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
