from flask import Blueprint, g, jsonify, request

from app.errors import error_response
from app.middleware.auth import require_auth
from app.middleware.roles import require_role
from app.models.validators import validate_iso8601
from app.services import clinician_service

clinician_bp = Blueprint("clinician", __name__, url_prefix="/clinician")


@clinician_bp.route("/<clinician_id>/patients")
@require_auth
@require_role("clinician")
def get_patients(clinician_id):
    """Return active patients with 7-day trends for a clinician.

    Enforces ownership: the authenticated user must match the
    clinician ID in the path. Returns 403 otherwise.
    """
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    patients = clinician_service.get_patients(clinician_id)
    return jsonify(patients), 200


@clinician_bp.route("/<clinician_id>/patients/<patient_id>")
@require_auth
@require_role("clinician")
def get_patient_detail(clinician_id, patient_id):
    """Return patient profile and 7-day overview."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    detail = clinician_service.get_patient_detail(patient_id)
    return jsonify(detail), 200


@clinician_bp.route("/<clinician_id>/patients/<patient_id>/samples")
@require_auth
@require_role("clinician")
def get_patient_samples(clinician_id, patient_id):
    """Return patient samples filtered by date range."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    from_str = request.args.get("from")
    to_str = request.args.get("to")

    from_dt = validate_iso8601(from_str)
    to_dt = validate_iso8601(to_str)

    if from_dt is None or to_dt is None:
        return error_response(
            "invalid_date_range",
            "Both 'from' and 'to' query parameters must be valid "
            "ISO 8601 timestamps",
            400,
        )

    samples = clinician_service.get_patient_samples(
        patient_id, from_str, to_str
    )
    return jsonify(samples), 200


@clinician_bp.route("/<clinician_id>/dashboard")
@require_auth
@require_role("clinician")
def get_dashboard(clinician_id):
    """Return dashboard statistics for a clinician."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    stats = clinician_service.get_dashboard_stats(clinician_id)
    return jsonify(stats), 200


@clinician_bp.route("/<clinician_id>/needs-attention")
@require_auth
@require_role("clinician")
def get_needs_attention(clinician_id):
    """Return patients needing attention for a clinician."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    items = clinician_service.get_needs_attention(clinician_id)
    return jsonify(items), 200


@clinician_bp.route("/<clinician_id>/recent-activity")
@require_auth
@require_role("clinician")
def get_recent_activity(clinician_id):
    """Return recent monitoring sessions across all active patients."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    limit = request.args.get("limit", 10, type=int)
    activity = clinician_service.get_recent_activity(clinician_id, limit)
    return jsonify(activity), 200


@clinician_bp.route("/<clinician_id>/invitations")
@require_auth
@require_role("clinician")
def get_invitations(clinician_id):
    """Return all invitation codes for a clinician."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    invitations = clinician_service.get_invitations(clinician_id)
    return jsonify(invitations), 200


@clinician_bp.route("/<clinician_id>/invitations", methods=["POST"])
@require_auth
@require_role("clinician")
def generate_invitation(clinician_id):
    """Generate a new invitation code for a clinician."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    invitation = clinician_service.generate_invitation(clinician_id)
    return jsonify(invitation), 201


@clinician_bp.route(
    "/<clinician_id>/invitations/<code_id>", methods=["DELETE"]
)
@require_auth
@require_role("clinician")
def revoke_invitation(clinician_id, code_id):
    """Revoke an invitation code."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    result = clinician_service.revoke_invitation(clinician_id, code_id)

    # If result is a Flask response (error), return it directly
    if hasattr(result, "status_code"):
        return result

    return jsonify(result), 200


@clinician_bp.route(
    "/<clinician_id>/patients/<patient_id>/resting-hr", methods=["PUT"]
)
@require_auth
@require_role("clinician")
def update_resting_hr(clinician_id, patient_id):
    """Update a patient's resting heart rate baseline."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    data = request.get_json(silent=True) or {}
    bpm = data.get("bpm")

    if bpm is None:
        return error_response(
            "invalid_heart_rate",
            "Heart rate must be between 30 and 220 bpm",
            400,
        )

    result = clinician_service.update_resting_hr(
        clinician_id, patient_id, bpm
    )

    # If result is a Flask response (error), return it directly
    if hasattr(result, "status_code"):
        return result

    return jsonify(result), 200


@clinician_bp.route("/<clinician_id>/profile")
@require_auth
@require_role("clinician")
def get_profile(clinician_id):
    """Return the clinician's profile."""
    if g.user_id != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to access this resource",
            403,
        )

    result = clinician_service.get_profile(clinician_id)

    # If result is a Flask response (error), return it directly
    if hasattr(result, "status_code"):
        return result

    return jsonify(result), 200
