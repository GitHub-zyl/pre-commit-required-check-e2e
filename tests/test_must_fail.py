"""Test file for E2E validation - all tests pass."""
import pytest

def test_basic_math():
    assert 1 + 1 == 2

def test_string_concat():
    assert "a" + "b" == "ab"

def test_list_operations():
    assert [1, 2, 3][1] == 2
