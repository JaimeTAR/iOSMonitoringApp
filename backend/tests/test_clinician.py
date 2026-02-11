"""Unit tests for clinician endpoints: resting HR update and profile.

Requirements: 13.1, 13.2, 13.3, 14.1, 14.2
"""

import time
from unittest.mock import MagicMock, patch

import jwt as pyjwt
import pytest

TEST_JWT_SECRET = "test-jwt-secret"
CLINICIAN_ID = "clinician-uuid"
PATIENT_ID = "patient-uuid"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_sb():
    """Patch get_supabase where clinician_service imports it."""
    mock_client = MagicMock()

    mock_table = MagicMock()
    mock_client.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.insert.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.delete.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.is_.return_value = mock_table
    mock_table.execute.return_value = MagicMock(data=[])

    with patch(
        "app.services.clinician_service.get_supabase",
        return_value=mock_client,
    ):
        yield mock_client


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _clinician_token(clinician_id=CLINICIAN_ID):
    """Return an Authorization header with a clinician JWT."""
    token = pyjwt.encode(
        {
            "sub": clinician_id,
            "exp": int(time.time()) + 3600,
            "role": "clinician",
        },
        TEST_JWT_SECRET,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


def _setup_relationship_and_profile(mock_sb, has_relationship=True):
    """Wire up mock for relationship check and profile update."""
    rel_data = (
        [{"clinician_id": CLINICIAN_ID, "patient_id": PATIENT_ID,
          "status": "activo", "end_date": None}]
        if has_relationship else []
    )

    def table_side_effect(table_name):
        t = MagicMock()
        t.select.return_value = t
        t.update.return_value = t
        t.eq.return_value = t
        t.is_.return_value = t

        if table_name == "clinician_patients":
            t.execute.return_value = MagicMock(data=rel_data)
        elif table_name == "user_profile":
            t.execute.return_value = MagicMock(
                data=[{"user_id": PATIENT_ID, "resting_heart_rate": 72}]
            )
        else:
            t.execute.return_value = MagicMock(data=[])
        return t

    mock_sb.table.side_effect = table_side_effect


# ---------------------------------------------------------------------------
# PUT /clinician/<id>/patients/<pid>/resting-hr
# ---------------------------------------------------------------------------

class TestUpdateRestingHR:
    """Tests for PUT resting-hr — Requirements 13.1, 13.2, 13.3."""

    def test_update_resting_hr_success(self, client, mock_sb):
        """Req 13.1: valid bpm updates resting heart rate."""
        _setup_relationship_and_profile(mock_sb, has_relationship=True)

        resp = client.put(
            f"/clinician/{CLINICIAN_ID}/patients/{PATIENT_ID}/resting-hr",
            json={"bpm": 72},
            headers=_clinician_token(),
        )

        assert resp.status_code == 200

    def test_update_resting_hr_invalid_low(self, client, mock_sb):
        """Req 13.2: bpm below 30 returns 400 invalid_heart_rate."""
        resp = client.put(
            f"/clinician/{CLINICIAN_ID}/patients/{PATIENT_ID}/resting-hr",
            json={"bpm": 10},
            headers=_clinician_token(),
        )

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invalid_heart_rate"

    def test_update_resting_hr_invalid_high(self, client, mock_sb):
        """Req 13.2: bpm above 220 returns 400 invalid_heart_rate."""
        resp = client.put(
            f"/clinician/{CLINICIAN_ID}/patients/{PATIENT_ID}/resting-hr",
            json={"bpm": 250},
            headers=_clinician_token(),
        )

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invalid_heart_rate"

    def test_update_resting_hr_forbidden(self, client, mock_sb):
        """Req 13.3: no relationship returns 403 forbidden."""
        _setup_relationship_and_profile(mock_sb, has_relationship=False)

        resp = client.put(
            f"/clinician/{CLINICIAN_ID}/patients/{PATIENT_ID}/resting-hr",
            json={"bpm": 72},
            headers=_clinician_token(),
        )

        assert resp.status_code == 403
        assert resp.get_json()["error"] == "forbidden"

    def test_update_resting_hr_missing_bpm(self, client, mock_sb):
        """Missing bpm field returns 400."""
        resp = client.put(
            f"/clinician/{CLINICIAN_ID}/patients/{PATIENT_ID}/resting-hr",
            json={},
            headers=_clinician_token(),
        )

        assert resp.status_code == 400
        assert resp.get_json()["error"] == "invalid_heart_rate"


# ---------------------------------------------------------------------------
# GET /clinician/<id>/profile
# ---------------------------------------------------------------------------

class TestGetProfile:
    """Tests for GET profile — Requirements 14.1, 14.2."""

    def test_get_profile_success(self, client, mock_sb):
        """Req 14.1: existing profile returns 200 with profile data."""
        def table_side_effect(table_name):
            t = MagicMock()
            t.select.return_value = t
            t.eq.return_value = t
            if table_name == "user_profile":
                t.execute.return_value = MagicMock(
                    data=[{"user_id": CLINICIAN_ID, "name": "Dr. Smith",
                           "role": "clinician"}]
                )
            else:
                t.execute.return_value = MagicMock(data=[])
            return t

        mock_sb.table.side_effect = table_side_effect

        resp = client.get(
            f"/clinician/{CLINICIAN_ID}/profile",
            headers=_clinician_token(),
        )

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["name"] == "Dr. Smith"

    def test_get_profile_not_found(self, client, mock_sb):
        """Req 14.2: missing profile returns 404 profile_not_found."""
        def table_side_effect(table_name):
            t = MagicMock()
            t.select.return_value = t
            t.eq.return_value = t
            t.execute.return_value = MagicMock(data=[])
            return t

        mock_sb.table.side_effect = table_side_effect

        resp = client.get(
            f"/clinician/{CLINICIAN_ID}/profile",
            headers=_clinician_token(),
        )

        assert resp.status_code == 404
        assert resp.get_json()["error"] == "profile_not_found"
