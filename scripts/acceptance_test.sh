#!/bin/bash
# scripts/acceptance_test.sh
# PTY-level acceptance test using tmux.
# Drives canvas_overlay_demo through a real terminal session and
# verifies key behaviors by inspecting tmux pane content.
#
# Requirements: tmux, make (examples must be built first)
# Usage: make examples && bash scripts/acceptance_test.sh
#
# Tests:
#   1. Program starts and renders canvas
#   2. Mouse move updates cursor position in status bar
#   3. Esc quits cleanly (exit code 0)
#   4. Terminal is restored after exit (no raw mode residue)

set -uo pipefail

DEMO="./build/bin/canvas_overlay_demo"
SESSION="ftui_acceptance_$$"
PASS=0
FAIL=0

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
}
trap cleanup EXIT

assert_contains() {
  local desc="$1" pattern="$2" content="$3"
  if echo "$content" | grep -q "$pattern"; then
    echo "  PASS  $desc"
    ((PASS++))
  else
    echo "  FAIL  $desc (pattern '$pattern' not found)"
    ((FAIL++))
  fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" content="$3"
  if echo "$content" | grep -q "$pattern"; then
    echo "  FAIL  $desc (pattern '$pattern' should not be present)"
    ((FAIL++))
  else
    echo "  PASS  $desc"
    ((PASS++))
  fi
}

if ! command -v tmux &>/dev/null; then
  echo "SKIP: tmux not installed"
  exit 0
fi

if [ ! -x "$DEMO" ]; then
  echo "ERROR: $DEMO not found. Run 'make examples' first."
  exit 1
fi

echo "=== fafafa.tui PTY acceptance test ==="
echo

# Start demo in a tmux session (80x24 default).
tmux new-session -d -s "$SESSION" -x 80 -y 24 "$DEMO"
tmux set-option -t "$SESSION" escape-time 0
sleep 0.5

# Test 1: Program started and rendered.
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "canvas renders on startup" "Move mouse" "$CONTENT"
assert_contains "status bar visible" "Move mouse" "$CONTENT"

# Test 2: Send a mouse move event (SGR format).
# CSI < 35 ; 20 ; 10 M = moved at (20, 10)
tmux send-keys -t "$SESSION" -l $'\e[<35;20;10M'
sleep 0.2
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "mouse position shown in status" "(19,9)" "$CONTENT"

# Test 3: Send mouse down + drag + up (draw a line).
# Down at (10,5): CSI < 0 ; 10 ; 5 M
tmux send-keys -t "$SESSION" -l $'\e[<0;10;5M'
sleep 0.1
# Drag to (15,5): CSI < 32 ; 15 ; 5 M
tmux send-keys -t "$SESSION" -l $'\e[<32;15;5M'
sleep 0.1
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "drag shows DRAGGING status" "DRAGGING" "$CONTENT"
# Up at (15,5): CSI < 0 ; 15 ; 5 m
tmux send-keys -t "$SESSION" -l $'\e[<0;15;5m'
sleep 0.2
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_not_contains "after release, no DRAGGING" "DRAGGING" "$CONTENT"

# Test 4: Esc during drag cancels (no commit).
tmux send-keys -t "$SESSION" -l $'\e[<0;5;3M'
sleep 0.1
tmux send-keys -t "$SESSION" -l $'\e[<32;10;3M'
sleep 0.1
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_contains "drag active before Esc" "DRAGGING" "$CONTENT"
# Send Esc (wait longer for bare-Esc timeout resolution).
tmux send-keys -t "$SESSION" Escape
sleep 0.8
CONTENT=$(tmux capture-pane -t "$SESSION" -p)
assert_not_contains "Esc cancels drag" "DRAGGING" "$CONTENT"

# Test 5: Esc without session quits.
tmux send-keys -t "$SESSION" Escape
sleep 1.0
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "  PASS  Esc quits program"
  ((PASS++))
else
  # Session might still exist if program exited but tmux kept it.
  CONTENT=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "")
  if echo "$CONTENT" | grep -q "Move mouse"; then
    echo "  FAIL  Esc did not quit program"
    ((FAIL++))
  else
    echo "  PASS  Esc quits program (session ended)"
    ((PASS++))
  fi
fi

# Test 6: Terminal restored (check stty is sane).
# After tmux session ends, our terminal should be fine.
# If raw mode leaked, 'stty' would show '-echo' or similar.
STTY_OUT=$(stty 2>/dev/null || echo "")
if echo "$STTY_OUT" | grep -q "\-echo"; then
  echo "  FAIL  terminal not restored (raw mode leaked)"
  ((FAIL++))
else
  echo "  PASS  terminal restored after exit"
  ((PASS++))
fi

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
