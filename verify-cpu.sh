#!/bin/bash

echo "=== CPU Summary ==="
lscpu | grep -E "^CPU\(s\)|^Thread|^Core|^Socket|^Model name"

echo ""
echo "=== Physical vs Logical Cores ==="
echo "Physical cores: $(lscpu | grep '^Core(s) per socket:' | awk '{print $NF}')"
echo "Sockets: $(lscpu | grep '^Socket(s):' | awk '{print $NF}')"
echo "Total physical cores: $(( $(lscpu | grep '^Core(s) per socket:' | awk '{print $NF}') * $(lscpu | grep '^Socket(s):' | awk '{print $NF}') ))"
echo "Total logical CPUs (threads): $(lscpu | grep '^CPU(s):' | head -1 | awk '{print $NF}')"

echo ""
echo "=== Core Topology (first 16 entries) ==="
lscpu -p=CPU,Core,Socket | grep -v '^#' | head -16 | column -t -s','

echo ""
echo "=== Recommended CPU Settings ==="
echo "Use all threads:       ./launch-transcode.sh --cpus 16"
echo "Use all P-cores:       ./launch-transcode.sh --cpuset-cpus 0-7"
echo "Use half capacity:     ./launch-transcode.sh --cpus 8"
