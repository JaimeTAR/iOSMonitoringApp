"""Unit tests for auth endpoints: signup and validate-code.

Requirements: 1.1-1.6, 5.1, 5.2
"""

from unittest.mock import MagicMock, patch
from datetime import datetime, timezone, timedelta

import pytest
from supabase_auth.errors import AuthApiError


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_sb():
    """Patch get_supabase where auth_service imports it."""
    mock_client = MagicMock()

    # Default table chain — returns empty data
    mock_table = MagicMock()
    mock_client.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.insert.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.delete.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.execute.return_value = MagicMock(data=[])

    mock_auth = MagicMock()
    mock_client.auth = mock_auth

    with patch(
        "app.services.auth_service.get_supabase",
        return_value=mock_client,
    ):
        yield mock_client


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _valid_invitation(clinician_id="clinician-uuid", code_id="code-uuid"):
    """Return a valid pending invitation row."""
    return {
        "id": code_id,
        "clinician_id": clinician_id,
        "code": "ABC12",
        "status": "pending",
        "expires_at": (
            datetime.now(timezone.utc) + timedelta(days=3)
        ).isoformat(),
    }


def _setup_signup_mocks(mock_sb, invitation=None, clinician_name="Dr. Smith"):
    """Wire up the mock Supabase client for a successful signup flow."""
    inv = invitation or _valid_invitation()

    def table_side_effect(table_name):
        mock_table = MagicMock()
        mock_table.select.return_value = mock_table
        mock_table.insert.return_value = mock_table
        mock_table.update.return_value = mock_table
        mock_table.eq.return_value = mock_table

        if table_name == "clinician_invitation_codes":
            mock_table.execute.return_value = MagicMock(data=[inv])
        elif table_name == "user_profile":
            mock_table.execute.return_value = MagicMock(
                data=[{"name": clinician_name}]
            )
        elif table_name == "clinician_patients":
            mock_table.execute.return_value = MagicMock(data=[])
        else:
            mock_table.execute.return_value = MagicMock(data=[])

        return mock_table

    mock_sb.table.side_effect = table_side_effect

    # Auth sign_up mock
    mock_user = MagicMock()
    mock_user.id = "new-user-uuid"
    mock_session = MagicMock()
    mock_session.access_token = "jwt-token-123"
    mock_auth_response = MagicMock()
    mock_auth_response.user = mock_user
    mock_auth_response.session = mock_session
    mock_sb.auth.sign_up.return_value = mock_auth_response


def _setup_invitation_lookup(mock_sb, invitation_data, clinician_name="Dr. Smith"):
    """Set up table side_effect for validate_invitation_code flow."""
    def table_side_effect(table_name):
        t = MagicMock()
        t.select.return_value = t
        t.eq.return_value = t

        if table_name == "clinician_invitation_codes":
            t.execute.return_value = MagicMock(data=invitation_data)
        elif table_name == "user_profile":
            t.execute.return_value = MagicMock(
                data=[{"name": clinician_name}]
            )
        else:
            t.execute.return_value = MagicMock(data=[])
        return t

    mock_sb.table.side_effect = table_side_effect


# ---------------------------------------------------------------------------
# POST /auth/signup
# ---------------------------------------------------------------------------

class TestSignup:
    """Tests for POST /auth/signup — Requirement 1."""

    def test_signup_happy_path(self, client, mock_sb):
        """Req 1.1: successful signup returns JWT and 201."""
        _setup_signup_mocks(mock_sb)

        resp = client.post("/auth/signup", json={
            "email": "patient@example.com",
            "password": "securepass",
            "invitation_code": "ABC12",
        })

        assert resp.status_code == 201
        data = resp.get_json()
        assert data["access_token"] == "jwt-token-123"

        mock_sb.auth.sign_up.assert_called_once_with(
            {"email": "patient@example.com", "password": "securepass"}
        )

    def test_signup_missing_fields(self, client, mock_sb):
        """Missing required fields returns 400."""
        resp = client.post("/auth/signup", json={"email": "a@b.com"})
        assert resp.status_code == 400
        assert resp.get_json()["error"] == "missing_fields"

    def test_signup_invalid_invitation_code(self, client, mock_sb):
        """Req 1.2: non-existent code returns 400 invalid_invitation_code."""
        _setup_invitation_lookup(mock_sb, invitation_data=[])

        resp = client.post("/auth/signup", json={
            "email": "p@example.com",
            "password": "pass",
            "invitation_code": "XXXXX",
        })

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invalid_invitation_code"

    def test_signup_invitation_code_used(self, client, mock_sb):
        """Req 1.3: used code returns 400 invitation_code_used."""
        inv = _valid_invitation()
        inv["status"] = "used"
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/signup", json={
            "email": "p@example.com",
            "password": "pass",
            "invitation_code": "ABC12",
        })

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_used"

    def test_signup_invitation_code_expired_status(self, client, mock_sb):
        """Req 1.4: code with status 'expired' returns 400."""
        inv = _valid_invitation()
        inv["status"] = "expired"
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/signup", json={
            "email": "p@example.com",
            "password": "pass",
            "invitation_code": "ABC12",
        })

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_expired"

    def test_signup_invitation_code_expired_by_date(self, client, mock_sb):
        """Req 1.4: code with expires_at in the past returns 400."""
        inv = _valid_invitation()
        inv["status"] = "pending"
        inv["expires_at"] = (
            datetime.now(timezone.utc) - timedelta(hours=1)
        ).isoformat()
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/signup", json={
            "email": "p@example.com",
            "password": "pass",
            "invitation_code": "ABC12",
        })

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_expired"

    def test_signup_invitation_code_revoked(self, client, mock_sb):
        """Req 1.5: revoked code returns 400 invitation_code_revoked."""
        inv = _valid_invitation()
        inv["status"] = "revoked"
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/signup", json={
            "email": "p@example.com",
            "password": "pass",
            "invitation_code": "ABC12",
        })

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_revoked"

    def test_signup_email_already_exists(self, client, mock_sb):
        """Req 1.6: duplicate email returns 409 email_already_exists."""
        _setup_signup_mocks(mock_sb)
        mock_sb.auth.sign_up.side_effect = AuthApiError(
            "User already registered", status=400, code=None
        )

        resp = client.post("/auth/signup", json={
            "email": "existing@example.com",
            "password": "pass",
            "invitation_code": "ABC12",
        })

        assert resp.status_code == 409
        assert resp.get_json()["error"] == "email_already_exists"


# ---------------------------------------------------------------------------
# POST /auth/validate-code
# ---------------------------------------------------------------------------

class TestValidateCode:
    """Tests for POST /auth/validate-code — Requirement 5."""

    def test_validate_code_happy_path(self, client, mock_sb):
        """Req 5.1: valid code returns 200 with clinician name."""
        inv = _valid_invitation()
        _setup_invitation_lookup(
            mock_sb, invitation_data=[inv], clinician_name="Dr. Smith"
        )

        resp = client.post("/auth/validate-code", json={"code": "ABC12"})

        assert resp.status_code == 200
        assert resp.get_json()["clinician_name"] == "Dr. Smith"

    def test_validate_code_missing_code(self, client, mock_sb):
        """Missing code field returns 400."""
        resp = client.post("/auth/validate-code", json={})
        assert resp.status_code == 400
        assert resp.get_json()["error"] == "missing_fields"

    def test_validate_code_not_found(self, client, mock_sb):
        """Req 5.2: non-existent code returns 400 invalid_invitation_code."""
        _setup_invitation_lookup(mock_sb, invitation_data=[])

        resp = client.post("/auth/validate-code", json={"code": "NOPE1"})

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invalid_invitation_code"

    def test_validate_code_used(self, client, mock_sb):
        """Req 5.2: used code returns 400 invitation_code_used."""
        inv = _valid_invitation()
        inv["status"] = "used"
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/validate-code", json={"code": "ABC12"})

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_used"

    def test_validate_code_expired(self, client, mock_sb):
        """Req 5.2: expired code returns 400 invitation_code_expired."""
        inv = _valid_invitation()
        inv["status"] = "expired"
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/validate-code", json={"code": "ABC12"})

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_expired"

    def test_validate_code_revoked(self, client, mock_sb):
        """Req 5.2: revoked code returns 400 invitation_code_revoked."""
        inv = _valid_invitation()
        inv["status"] = "revoked"
        _setup_invitation_lookup(mock_sb, invitation_data=[inv])

        resp = client.post("/auth/validate-code", json={"code": "ABC12"})

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invitation_code_revoked"


# ---------------------------------------------------------------------------
# Signin / Signout / Session helpers
# ---------------------------------------------------------------------------

def _setup_signin_mocks(mock_sb, user_id="user-uuid", role="patient"):
    """Wire up the mock Supabase client for a successful signin flow."""
    mock_user = MagicMock()
    mock_user.id = user_id
    mock_session = MagicMock()
    mock_session.access_token = "jwt-signin-token"
    mock_auth_response = MagicMock()
    mock_auth_response.user = mock_user
    mock_auth_response.session = mock_session
    mock_sb.auth.sign_in_with_password.return_value = mock_auth_response

    # Table lookup for role
    def table_side_effect(table_name):
        t = MagicMock()
        t.select.return_value = t
        t.eq.return_value = t
        if table_name == "user_profile":
            t.execute.return_value = MagicMock(data=[{"role": role}])
        else:
            t.execute.return_value = MagicMock(data=[])
        return t

    mock_sb.table.side_effect = table_side_effect


def _make_auth_header(token="valid-jwt-token"):
    """Return an Authorization header dict."""
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# POST /auth/signin
# ---------------------------------------------------------------------------

class TestSignin:
    """Tests for POST /auth/signin — Requirement 2."""

    def test_signin_success(self, client, mock_sb):
        """Req 2.1: successful signin returns JWT and role."""
        _setup_signin_mocks(mock_sb, role="patient")

        resp = client.post("/auth/signin", json={
            "email": "user@example.com",
            "password": "securepass",
        })

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["access_token"] == "jwt-signin-token"
        assert data["role"] == "patient"

        mock_sb.auth.sign_in_with_password.assert_called_once_with(
            {"email": "user@example.com", "password": "securepass"}
        )

    def test_signin_invalid_credentials(self, client, mock_sb):
        """Req 2.2: invalid credentials returns 401 invalid_credentials."""
        mock_sb.auth.sign_in_with_password.side_effect = AuthApiError(
            "Invalid login credentials", status=400, code=None
        )

        resp = client.post("/auth/signin", json={
            "email": "user@example.com",
            "password": "wrongpass",
        })

        assert resp.status_code == 401
        assert resp.get_json()["error"] == "invalid_credentials"

    def test_signin_missing_fields(self, client, mock_sb):
        """Missing email or password returns 400."""
        resp = client.post("/auth/signin", json={"email": "a@b.com"})
        assert resp.status_code == 400
        assert resp.get_json()["error"] == "missing_fields"

    def test_signin_clinician_role(self, client, mock_sb):
        """Signin returns the correct role for clinicians."""
        _setup_signin_mocks(mock_sb, role="clinician")

        resp = client.post("/auth/signin", json={
            "email": "doc@example.com",
            "password": "securepass",
        })

        assert resp.status_code == 200
        assert resp.get_json()["role"] == "clinician"


# ---------------------------------------------------------------------------
# POST /auth/signout
# ---------------------------------------------------------------------------

class TestSignout:
    """Tests for POST /auth/signout — Requirement 3."""

    def test_signout_success(self, client, mock_sb, valid_token_header):
        """Req 3.1: signout with valid JWT returns 200."""
        resp = client.post(
            "/auth/signout",
            headers=valid_token_header,
        )

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["message"] == "Successfully signed out"

    def test_signout_missing_token(self, client, mock_sb):
        """Req 3.2: signout without JWT returns 401."""
        resp = client.post("/auth/signout")

        assert resp.status_code == 401
        assert resp.get_json()["error"] == "missing_token"


# ---------------------------------------------------------------------------
# GET /auth/session
# ---------------------------------------------------------------------------

class TestSession:
    """Tests for GET /auth/session — Requirement 4."""

    def test_session_valid(self, client, mock_sb, valid_token_header):
        """Req 4.1: session validation returns user info."""
        mock_user = MagicMock()
        mock_user.id = "user-uuid"
        mock_user_response = MagicMock()
        mock_user_response.user = mock_user
        mock_sb.auth.get_user.return_value = mock_user_response

        def table_side_effect(table_name):
            t = MagicMock()
            t.select.return_value = t
            t.eq.return_value = t
            if table_name == "user_profile":
                t.execute.return_value = MagicMock(
                    data=[{"role": "patient"}]
                )
            else:
                t.execute.return_value = MagicMock(data=[])
            return t

        mock_sb.table.side_effect = table_side_effect

        resp = client.get(
            "/auth/session",
            headers=valid_token_header,
        )

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["user_id"] == "user-uuid"
        assert data["role"] == "patient"
        assert "access_token" in data

    def test_session_expired(self, client, mock_sb, valid_token_header):
        """Req 4.2: expired/invalid JWT returns 401 session_expired."""
        mock_sb.auth.get_user.side_effect = AuthApiError(
            "Invalid token", status=401, code=None
        )

        resp = client.get(
            "/auth/session",
            headers=valid_token_header,
        )

        assert resp.status_code == 401
        assert resp.get_json()["error"] == "session_expired"

    def test_session_missing_token(self, client, mock_sb):
        """Session without JWT returns 401 missing_token."""
        resp = client.get("/auth/session")

        assert resp.status_code == 401
        assert resp.get_json()["error"] == "missing_token"
