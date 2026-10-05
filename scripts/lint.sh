#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift format lint --strict --recursive CursivePrototype.swiftpm Tests
