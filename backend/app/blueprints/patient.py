"""Patient blueprint — sample upload and profile management.

Routes:
    POST /patient/samples   — Upload physiological samples
    GET  /patient/profile   — Get patient profile
    PUT  /patient/profile   — Update patient profile
"""

from flask import Blueprint, g, jsonify, request

from app.middleware.auth import require_auth
from app.middleware.roles import require_role
from app.services import patient_service

patient_bp = Blueprint("patient", __name__, url_prefix="/patient")


@patient_bp.route("/samples", methods=["POST"])
@require_auth
@require_role("patient")
def upload_samples():
    """Accept a JSON array of samples and batch-insert them."""
    data = request.get_json(silent=True)
    if not isinstance(data, list):
        from app.errors import error_response
        return error_response(
            "invalid_samples",
            "Request body must be a JSON array of samples",
            400,
        )

    result, status_code = patient_service.upload_samples(g.user_id, data)

    # If result is a Flask response (error), return it directly
    if hasattr(result, "status_code"):
        return result

    return jsonify(result), status_code


@patient_bp.route("/profile")
@require_auth
@require_role("patient")
def get_profile():
    """Return the authenticated patient's profile."""
    result = patient_service.get_profile(g.user_id)

    if hasattr(result, "status_code"):
        return result

    return jsonify(result), 200


@patient_bp.route("/profile", methods=["PUT"])
@require_auth
@require_role("patient")
def update_profile():
    """Update the authenticated patient's profile fields."""
    fields = request.get_json(silent=True) or {}

    result, status_code = patient_service.update_profile(g.user_id, fields)

    if hasattr(result, "status_code"):
        return result

    return jsonify(result), status_code
