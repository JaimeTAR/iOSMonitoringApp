"""Tests for the Supabase client singleton module."""

import pytest
from unittest.mock import patch, MagicMock

from app.services import supabase_client


@pytest.fixture(autouse=True)
def reset_singleton():
    """Reset the module-level singleton before each test."""
    supabase_client._supabase_client = None
    yield
    supabase_client._supabase_client = None


def test_get_supabase_raises_before_init():
    """get_supabase raises RuntimeError when not initialized."""
    with pytest.raises(RuntimeError, match="not initialized"):
        supabase_client.get_supabase()


@patch("app.services.supabase_client.supabase")
def test_init_supabase_creates_client(mock_supabase):
    """init_supabase creates a client from app config."""
    mock_client = MagicMock()
    mock_supabase.create_client.return_value = mock_client

    app = MagicMock()
    app.config.get = lambda k: {
        "SUPABASE_URL": "http://localhost:54321",
        "SUPABASE_SERVICE_KEY": "test-key",
    }.get(k)

    supabase_client.init_supabase(app)

    mock_supabase.create_client.assert_called_once_with(
        "http://localhost:54321", "test-key"
    )
    assert supabase_client.get_supabase() is mock_client


def test_init_supabase_raises_without_url(app):
    """init_supabase raises RuntimeError when URL is missing."""
    app.config["SUPABASE_URL"] = ""
    with pytest.raises(RuntimeError, match="must be set"):
        supabase_client.init_supabase(app)


def test_init_supabase_raises_without_key(app):
    """init_supabase raises RuntimeError when service key is missing."""
    app.config["SUPABASE_SERVICE_KEY"] = ""
    with pytest.raises(RuntimeError, match="must be set"):
        supabase_client.init_supabase(app)
