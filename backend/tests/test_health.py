"""Unit tests for the GET /health endpoint.

Requirements: 24.1, 24.2, 24.3
"""

from unittest.mock import MagicMock, patch


class TestHealthCheck:
    """Tests for GET /health — Requirement 24."""

    def test_healthy_response(self, client):
        """Req 24.1: returns 200 with {"status": "healthy"} when Supabase
        is reachable."""
        mock_client = MagicMock()
        mock_table = MagicMock()
        mock_client.table.return_value = mock_table
        mock_table.select.return_value = mock_table
        mock_table.limit.return_value = mock_table
        mock_table.execute.return_value = MagicMock(data=[])

        with patch(
            "app.get_supabase",
            return_value=mock_client,
        ):
            resp = client.get("/health")

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["status"] == "healthy"

    def test_unhealthy_when_supabase_unavailable(self, client):
        """Req 24.2: returns 503 with unhealthy status when Supabase
        client raises an exception."""
        with patch(
            "app.get_supabase",
            side_effect=RuntimeError("Supabase client not initialized."),
        ):
            resp = client.get("/health")

        assert resp.status_code == 503
        data = resp.get_json()
        assert data["status"] == "unhealthy"
        assert data["error"] == "supabase_unavailable"

    def test_unhealthy_when_query_fails(self, client):
        """Req 24.2: returns 503 when the Supabase query itself fails."""
        mock_client = MagicMock()
        mock_table = MagicMock()
        mock_client.table.return_value = mock_table
        mock_table.select.return_value = mock_table
        mock_table.limit.return_value = mock_table
        mock_table.execute.side_effect = Exception("Connection refused")

        with patch(
            "app.get_supabase",
            return_value=mock_client,
        ):
            resp = client.get("/health")

        assert resp.status_code == 503
        data = resp.get_json()
        assert data["status"] == "unhealthy"
        assert data["error"] == "supabase_unavailable"

    def test_health_no_auth_required(self, client):
        """Req 24.3: /health does not require authentication — calling
        without any Authorization header should not return 401."""
        with patch(
            "app.get_supabase",
            side_effect=RuntimeError("not initialized"),
        ):
            resp = client.get("/health")

        # Even if unhealthy, it should NOT be 401
        assert resp.status_code != 401
