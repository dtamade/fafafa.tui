#!/bin/bash
# scripts/bench_all.sh — Run all benchmarks and output a summary table.
# Usage: make benchmarks && bash scripts/bench_all.sh

set -uo pipefail

BIN="./build/bin"
PASS=0
FAIL=0

echo "=== fafafa.tui benchmark summary ==="
echo ""
printf "%-20s %12s %10s %8s\n" "Benchmark" "Result" "Target" "Status"
printf "%-20s %12s %10s %8s\n" "─────────" "──────" "──────" "──────"

run_bench() {
  local name="$1" target="$2" unit="$3" pattern="$4"
  local output value status best i
  best=""
  # Run 3 times, take best result (reduces system noise)
  for i in 1 2 3; do
    output=$("$BIN/$name" 2>&1)
    value=$(echo "$output" | grep -oP "$pattern" | head -1)
    if [ -z "$best" ] || [ "$(echo "$value < $best" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
      best="$value"
    fi
  done
  if echo "$output" | grep -q "PASS"; then
    status="PASS"
    ((PASS++))
  else
    # Check if best-of-3 meets target
    if [ "$(echo "$best < $target" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
      status="PASS"
      ((PASS++))
    else
      status="FAIL"
      ((FAIL++))
    fi
  fi
  printf "%-20s %12s %10s %8s\n" "$name" "$best $unit" "< $target $unit" "$status"
}

run_bench "bench_diff" "1000" "us" "(?<=per-frame:       )[0-9.]+"
run_bench "bench_layout" "5" "us" "(?<=per-call:     )[0-9.]+"
run_bench "bench_input" "1000" "ns" "(?<=per-event:       )[0-9.]+"
run_bench "bench_render" "1000" "us" "(?<=per-frame:       )[0-9.]+"
run_bench "bench_mouse_move" "500" "us" "(?<=per-event:       )[0-9.]+"
run_bench "bench_fullscreen" "2000" "us" "(?<=per frame: )[0-9.]+"

echo ""
echo "--- CJK comparison ---"
"$BIN/bench_cjk" 2>&1 | grep -E "^\s+(ASCII|CJK|Mixed)"

echo ""
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
