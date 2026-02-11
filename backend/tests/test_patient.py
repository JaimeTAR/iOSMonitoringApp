"""Unit tests for patient endpoints: sample upload and profile management.

Requirements: 15.1, 15.2, 15.3, 16.1, 16.2, 16.3, 16.4
"""

import time
from unittest.mock import MagicMock, patch

import jwt as pyjwt
import pytest

TEST_JWT_SECRET = "test-jwt-secret"
PATIENT_ID = "test-user-id"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_sb():
    """Patch get_supabase where patient_service imports it."""
    mock_client = MagicMock()

    mock_table = MagicMock()
    mock_client.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.insert.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.delete.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.execute.return_value = MagicMock(data=[])

    with patch(
        "app.services.patient_service.get_supabase",
        return_value=mock_client,
    ):
        yield mock_client


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _patient_token(user_id=PATIENT_ID):
    """Return an Authorization header with a patient JWT."""
    token = pyjwt.encode(
        {
            "sub": user_id,
            "exp": int(time.time()) + 3600,
            "role": "patient",
        },
        TEST_JWT_SECRET,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# POST /patient/samples
# ---------------------------------------------------------------------------

class TestUploadSamples:
    """Tests for POST /patient/samples — Requirements 15.1, 15.2, 15.3."""

    def test_upload_samples_success(self, client, mock_sb):
        """Req 15.1: valid batch returns 201 with inserted count."""
        samples = [
            {
                "window_start": "2024-01-01T00:00:00Z",
                "avg_heart_rate": 72,
                "rmssd": 45.0,
                "sdnn": 50.0,
                "sample_count": 10,
            },
            {
                "window_start": "2024-01-01T00:01:00Z",
                "avg_heart_rate": 75,
                "sample_count": 8,
            },
        ]

        resp = client.post(
            "/patient/samples",
            json=samples,
            headers=_patient_token(),
        )

        assert resp.status_code == 201
        data = resp.get_json()
        assert data["inserted"] == 2

    def test_upload_samples_batch_rejection(self, client, mock_sb):
        """Req 15.3: batch with invalid sample returns 400 with error."""
        samples = [
            {
                "window_start": "2024-01-01T00:00:00Z",
                "avg_heart_rate": 72,
                "sample_count": 10,
            },
            {
                "window_start": "2024-01-01T00:01:00Z",
                "avg_heart_rate": -5,  # invalid: below 0
                "sample_count": 10,
            },
        ]

        resp = client.post(
            "/patient/samples",
            json=samples,
            headers=_patient_token(),
        )

        assert resp.status_code == 400
        data = resp.get_json()
        assert data["error"] == "invalid_samples"


# ---------------------------------------------------------------------------
# GET /patient/profile
# ---------------------------------------------------------------------------

class TestGetProfile:
    """Tests for GET /patient/profile — Requirement 16.1."""

    def test_get_profile_success(self, client, mock_sb):
        """Req 16.1: returns 200 with patient profile."""
        def table_side_effect(table_name):
            t = MagicMock()
            t.select.return_value = t
            t.eq.return_value = t
            if table_name == "user_profile":
                t.execute.return_value = MagicMock(
                    data=[{
                        "user_id": PATIENT_ID,
                        "name": "Jane Doe",
                        "role": "patient",
                        "age": 30,
                    }]
                )
            else:
                t.execute.return_value = MagicMock(data=[])
            return t

        mock_sb.table.side_effect = table_side_effect

        resp = client.get(
            "/patient/profile",
            headers=_patient_token(),
        )

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["name"] == "Jane Doe"


# ---------------------------------------------------------------------------
# PUT /patient/profile
# ---------------------------------------------------------------------------

class TestUpdateProfile:
    """Tests for PUT /patient/profile — Requirements 16.2, 16.3, 16.4."""

    def test_update_profile_success(self, client, mock_sb):
        """Req 16.2: valid fields returns 200."""
        def table_side_effect(table_name):
            t = MagicMock()
            t.select.return_value = t
            t.update.return_value = t
            t.eq.return_value = t
            if table_name == "user_profile":
                t.execute.return_value = MagicMock(
                    data=[{
                        "user_id": PATIENT_ID,
                        "name": "Jane Updated",
                        "age": 31,
                    }]
                )
            else:
                t.execute.return_value = MagicMock(data=[])
            return t

        mock_sb.table.side_effect = table_side_effect

        resp = client.put(
            "/patient/profile",
            json={"name": "Jane Updated", "age": 31},
            headers=_patient_token(),
        )

        assert resp.status_code == 200

    def test_update_profile_validation_error(self, client, mock_sb):
        """Req 16.4: invalid fields returns 400 invalid_profile_data."""
        resp = client.put(
            "/patient/profile",
            json={"age": 200},  # age must be 1-149
            headers=_patient_token(),
        )

        assert resp.status_code == 400
        data = resp.get_json()
        assert data["error"] == "invalid_profile_data"
