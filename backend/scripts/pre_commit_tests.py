#!/usr/bin/env python
"""Pre-Commit test runner. Exits 0 on success, 1 on failure."""
import sys
import subprocess
result = subprocess.run(
    [sys.executable, "-m", "pytest", "tests/", "-v", "--tb=short", "--color=no"],
    cwd="."
)
sys.exit(result.returncode)
