"""Intentionally failing test for E2E validation of required check."""
import pytest

def test_must_fail():
    """This test is INTENTIONALLY failing to demonstrate branch protection."""
    actual = 1 + 1
    expected = 3  # WRONG on purpose
    assert actual == expected, f"Expected {expected}, got {actual}"

def test_must_also_fail():
    """Another intentionally failing test."""
    assert False, "This test is designed to fail for E2E validation"
