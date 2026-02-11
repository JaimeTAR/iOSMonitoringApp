"""Unit tests for JWT authentication middleware.

Tests: missing header, malformed token, expired token, valid token.
Requirements: 17.1, 17.2, 17.3, 17.4
"""

import time

import jwt as pyjwt
import pytest

from app import create_app

TEST_JWT_SECRET = "test-jwt-secret"


def _make_token(payload, secret=TEST_JWT_SECRET):
    """Create a signed JWT for testing."""
    return pyjwt.encode(payload, secret, algorithm="HS256")


@pytest.fixture
def app():
    app = create_app("testing")
    yield app


@pytest.fixture
def client(app):
    return app.test_client()


class TestRequireAuthMissingHeader:
    """Requirement 17.2: missing Authorization header → 401 missing_token."""

    def test_missing_auth_header(self, client):
        response = client.get("/auth/session")
        assert response.status_code == 401
        data = response.get_json()
        assert data["error"] == "missing_token"


class TestRequireAuthMalformedToken:
    """Requirement 17.3: malformed or bad-signature token → 401 invalid_token."""

    def test_malformed_token_garbage(self, client):
        response = client.get(
            "/auth/session",
            headers={"Authorization": "Bearer not-a-jwt"},
        )
        assert response.status_code == 401
        data = response.get_json()
        assert data["error"] == "invalid_token"

    def test_wrong_secret(self, client):
        token = _make_token(
            {"sub": "user-1", "exp": int(time.time()) + 3600, "role": "patient"},
            secret="wrong-secret",
        )
        response = client.get(
            "/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 401
        data = response.get_json()
        assert data["error"] == "invalid_token"

    def test_invalid_header_format(self, client):
        response = client.get(
            "/auth/session",
            headers={"Authorization": "Token abc123"},
        )
        assert response.status_code == 401
        data = response.get_json()
        assert data["error"] == "invalid_token"

    def test_missing_sub_claim(self, client):
        token = _make_token({"exp": int(time.time()) + 3600, "role": "patient"})
        response = client.get(
            "/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 401
        data = response.get_json()
        assert data["error"] == "invalid_token"


class TestRequireAuthExpiredToken:
    """Requirement 17.4: expired token → 401 token_expired."""

    def test_expired_token(self, client):
        token = _make_token(
            {"sub": "user-1", "exp": int(time.time()) - 100, "role": "patient"},
        )
        response = client.get(
            "/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 401
        data = response.get_json()
        assert data["error"] == "token_expired"


class TestRequireAuthValidToken:
    """Requirements 17.1, 17.2: valid token sets g.user_id and g.user_role."""

    def test_valid_token_with_user_metadata_role(self, app, client):
        """Role from user_metadata takes priority."""
        token = _make_token({
            "sub": "user-123",
            "exp": int(time.time()) + 3600,
            "role": "fallback_role",
            "user_metadata": {"role": "clinician"},
        })

        # We need a protected route that returns g.user_id and g.user_role.
        # /auth/session is protected by @require_auth but also calls service logic.
        # Instead, register a temporary test route.
        from flask import g, jsonify
        from app.middleware.auth import require_auth

        @app.route("/_test_auth_check")
        @require_auth
        def _test_auth_check():
            return jsonify({"user_id": g.user_id, "user_role": g.user_role})

        response = client.get(
            "/_test_auth_check",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["user_id"] == "user-123"
        assert data["user_role"] == "clinician"

    def test_valid_token_with_top_level_role_fallback(self, app, client):
        """Falls back to top-level role when user_metadata has no role."""
        token = _make_token({
            "sub": "user-456",
            "exp": int(time.time()) + 3600,
            "role": "patient",
        })

        from flask import g, jsonify
        from app.middleware.auth import require_auth

        @app.route("/_test_auth_fallback")
        @require_auth
        def _test_auth_fallback():
            return jsonify({"user_id": g.user_id, "user_role": g.user_role})

        response = client.get(
            "/_test_auth_fallback",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["user_id"] == "user-456"
        assert data["user_role"] == "patient"
