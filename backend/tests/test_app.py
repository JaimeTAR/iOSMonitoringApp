"""Smoke tests for the Flask app factory and test fixtures."""


def test_app_creates_successfully(app):
    """Verify the app factory produces a valid Flask app."""
    assert app is not None
    assert app.config["TESTING"] is True


def test_client_fixture(client):
    """Verify the test client fixture works."""
    assert client is not None


def test_blueprints_registered(app):
    """Verify all three blueprints are registered."""
    assert "auth" in app.blueprints
    assert "clinician" in app.blueprints
    assert "patient" in app.blueprints


def test_config_values(app):
    """Verify testing config loads expected values."""
    assert app.config["SUPABASE_URL"] == "http://localhost:54321"
    assert app.config["SUPABASE_SERVICE_KEY"] == "test-service-key"
    assert app.config["SUPABASE_JWT_SECRET"] == "test-jwt-secret"


def test_404_handler(client):
    """Verify 404 returns consistent JSON error format."""
    response = client.get("/nonexistent-route")
    assert response.status_code == 404
    data = response.get_json()
    assert data["error"] == "not_found"
    assert "message" in data


def test_mock_supabase_fixture(mock_supabase):
    """Verify the mock Supabase fixture provides a mock client."""
    assert mock_supabase is not None
    assert mock_supabase.auth is not None
    assert mock_supabase.table is not None
