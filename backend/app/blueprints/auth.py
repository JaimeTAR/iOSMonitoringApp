from flask import Blueprint, jsonify, request

from app.middleware.auth import require_auth
from app.errors import error_response

auth_bp = Blueprint("auth", __name__, url_prefix="/auth")


@auth_bp.route("/signup", methods=["POST"])
def signup():
    """Register a new patient with an invitation code.

    Accepts JSON: {"email": "...", "password": "...", "invitation_code": "..."}
    Returns the Supabase-issued JWT on success.
    """
    from app.services.auth_service import signup as do_signup

    data = request.get_json(silent=True) or {}
    email = data.get("email")
    password = data.get("password")
    invitation_code = data.get("invitation_code")

    if not email or not password or not invitation_code:
        return error_response(
            "missing_fields",
            "email, password, and invitation_code are required",
            400,
        )

    result = do_signup(email, password, invitation_code)

    # If the service returned a Flask response (error), pass it through
    if not isinstance(result, dict):
        return result

    return jsonify({"access_token": result["access_token"]}), 201


@auth_bp.route("/validate-code", methods=["POST"])
def validate_code():
    """Validate an invitation code before registration.

    Accepts JSON: {"code": "..."}
    Returns the clinician name if the code is valid.
    """
    from app.services.auth_service import validate_invitation_code

    data = request.get_json(silent=True) or {}
    code = data.get("code")

    if not code:
        return error_response(
            "missing_fields",
            "code is required",
            400,
        )

    result = validate_invitation_code(code)

    # If the service returned a Flask response (error), pass it through
    if not isinstance(result, dict):
        return result

    return jsonify({"clinician_name": result["clinician_name"]}), 200


@auth_bp.route("/signin", methods=["POST"])
def signin():
    """Sign in with email and password.

    Accepts JSON: {"email": "...", "password": "..."}
    Returns the Supabase-issued JWT and user role on success.
    """
    from app.services.auth_service import signin as do_signin

    data = request.get_json(silent=True) or {}
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return error_response(
            "missing_fields",
            "email and password are required",
            400,
        )

    result = do_signin(email, password)

    if not isinstance(result, dict):
        return result

    return jsonify({
        "access_token": result["access_token"],
        "role": result["role"],
    }), 200


@auth_bp.route("/signout", methods=["POST"])
@require_auth
def signout():
    """Sign out the current user.

    Requires a valid JWT in the Authorization header.
    """
    from app.services.auth_service import signout as do_signout

    token = request.headers.get("Authorization", "").split(" ", 1)[-1]
    result = do_signout(token)

    if not isinstance(result, dict):
        return result

    return jsonify(result), 200


@auth_bp.route("/session", methods=["GET"])
@require_auth
def get_session():
    """Validate/refresh session.

    Requires a valid JWT in the Authorization header.
    Returns user_id, role, and refreshed token.
    """
    from app.services.auth_service import validate_session

    token = request.headers.get("Authorization", "").split(" ", 1)[-1]
    result = validate_session(token)

    if not isinstance(result, dict):
        return result

    return jsonify(result), 200
