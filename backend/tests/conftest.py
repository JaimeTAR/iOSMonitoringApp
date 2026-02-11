import time

import jwt as pyjwt
import pytest
from unittest.mock import MagicMock, patch

from app import create_app

TEST_JWT_SECRET = "test-jwt-secret"


@pytest.fixture
def app():
    """Create a Flask application configured for testing."""
    app = create_app("testing")
    app.config.update({"TESTING": True})
    yield app


@pytest.fixture
def client(app):
    """Provide a Flask test client."""
    return app.test_client()


@pytest.fixture
def valid_token_header():
    """Return an Authorization header with a valid JWT for testing.

    The token is signed with the test secret and contains a ``sub``
    claim (user ID), ``exp`` (1 hour from now), and ``role`` (patient).
    """
    token = pyjwt.encode(
        {
            "sub": "test-user-id",
            "exp": int(time.time()) + 3600,
            "role": "patient",
        },
        TEST_JWT_SECRET,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def mock_supabase():
    """Mock the Supabase client used by services.

    Patches the supabase client at the service layer so that
    no real Supabase calls are made during tests.
    """
    mock_client = MagicMock()

    # Set up common return value chains for table operations
    mock_table = MagicMock()
    mock_client.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.insert.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.delete.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.execute.return_value = MagicMock(data=[])

    # Set up auth mock
    mock_auth = MagicMock()
    mock_client.auth = mock_auth

    with patch(
        "app.services.supabase_client.get_supabase",
        return_value=mock_client,
    ):
        yield mock_client
