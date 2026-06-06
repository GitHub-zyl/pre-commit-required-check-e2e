"""Control test that always passes (used for fixing the branch)."""
import pytest

def test_basic_math():
    assert 1 + 1 == 2

def test_string_concat():
    assert "a" + "b" == "ab"
