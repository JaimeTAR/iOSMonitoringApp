"""Auth service — signup, signin, signout, session, and invitation-code validation.

Delegates authentication to Supabase Auth and manages invitation
codes, user profiles, and clinician-patient relationships in the
hosted Supabase PostgreSQL database.
"""

from datetime import datetime, timezone

from supabase_auth.errors import AuthApiError

from app.errors import error_response
from app.services.supabase_client import get_supabase


def validate_invitation_code(code):
    """Validate an invitation code and return clinician info.

    Queries the ``clinician_invitation_codes`` table for the given code
    and checks its status and expiry.

    Returns:
        A tuple ``(flask.Response, int)`` on error, or a dict with
        ``clinician_name`` on success.
    """
    sb = get_supabase()

    result = (
        sb.table("clinician_invitation_codes")
        .select("*")
        .eq("code", code)
        .execute()
    )

    if not result.data:
        return error_response(
            "invalid_invitation_code",
            "The invitation code does not exist",
            400,
        )

    invitation = result.data[0]
    status = invitation.get("status")

    if status == "used":
        return error_response(
            "invitation_code_used",
            "This invitation code has already been used",
            400,
        )

    if status == "revoked":
        return error_response(
            "invitation_code_revoked",
            "This invitation code has been revoked",
            400,
        )

    if status == "expired":
        return error_response(
            "invitation_code_expired",
            "This invitation code has expired",
            400,
        )

    # Check expires_at even if status is still pending
    expires_at_str = invitation.get("expires_at")
    if expires_at_str:
        expires_at = datetime.fromisoformat(expires_at_str)
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            return error_response(
                "invitation_code_expired",
                "This invitation code has expired",
                400,
            )

    # Valid code — fetch clinician name
    clinician_id = invitation.get("clinician_id")
    profile_result = (
        sb.table("user_profile")
        .select("name")
        .eq("user_id", clinician_id)
        .execute()
    )

    clinician_name = None
    if profile_result.data:
        clinician_name = profile_result.data[0].get("name")

    return {"clinician_name": clinician_name, "invitation": invitation}


def signup(email, password, invitation_code):
    """Register a new patient account.

    1. Validate the invitation code (status + expiry).
    2. Create the user via Supabase Auth.
    3. Create a ``user_profile`` with role ``patient``.
    4. Mark the invitation code as ``used``.
    5. Create a ``clinician_patients`` relationship with status ``activo``.
    6. Return the Supabase-issued JWT.

    Returns:
        A Flask JSON response (tuple of response, status_code).
    """
    sb = get_supabase()

    # Step 1 — validate invitation code
    validation = validate_invitation_code(invitation_code)

    # If validation returned an error response, propagate it
    if not isinstance(validation, dict):
        return validation

    invitation = validation["invitation"]
    clinician_id = invitation["clinician_id"]
    invitation_id = invitation["id"]

    # Step 2 — create user via Supabase Auth
    try:
        auth_response = sb.auth.sign_up(
            {"email": email, "password": password}
        )
    except AuthApiError as e:
        if "User already registered" in str(e):
            return error_response(
                "email_already_exists",
                "A user with this email already exists",
                409,
            )
        raise

    user = auth_response.user
    session = auth_response.session
    user_id = user.id

    # Step 3 — create user_profile with role patient
    sb.table("user_profile").insert(
        {"user_id": user_id, "role": "patient"}
    ).execute()

    # Step 4 — mark invitation code as used
    sb.table("clinician_invitation_codes").update(
        {"status": "used"}
    ).eq("id", invitation_id).execute()

    # Step 5 — create clinician-patient relationship
    sb.table("clinician_patients").insert(
        {
            "clinician_id": clinician_id,
            "patient_id": user_id,
            "invitation_code_id": invitation_id,
            "status": "activo",
        }
    ).execute()

    # Step 6 — return the JWT
    access_token = session.access_token if session else None

    return {"access_token": access_token}


def signin(email, password):
    """Sign in a user with email and password.

    Delegates to Supabase Auth ``sign_in_with_password``, then fetches
    the user's role from the ``user_profile`` table.

    Returns:
        A dict with ``access_token`` and ``role`` on success,
        or a Flask error response on failure.
    """
    sb = get_supabase()

    try:
        auth_response = sb.auth.sign_in_with_password(
            {"email": email, "password": password}
        )
    except AuthApiError as e:
        if "Invalid login credentials" in str(e):
            return error_response(
                "invalid_credentials",
                "Invalid email or password",
                401,
            )
        raise

    session = auth_response.session
    user = auth_response.user
    access_token = session.access_token if session else None

    # Fetch role from user_profile
    role = None
    if user:
        profile_result = (
            sb.table("user_profile")
            .select("role")
            .eq("user_id", user.id)
            .execute()
        )
        if profile_result.data:
            role = profile_result.data[0].get("role")

    return {"access_token": access_token, "role": role}


def signout(jwt_token):
    """Sign out the current user.

    Delegates session invalidation to Supabase Auth.

    Returns:
        A dict with ``message`` on success.
    """
    sb = get_supabase()
    sb.auth.sign_out()
    return {"message": "Successfully signed out"}


def validate_session(jwt_token):
    """Validate and refresh a user session.

    Uses Supabase Auth ``get_user(jwt)`` to validate the token,
    then fetches the user's role from the ``user_profile`` table.

    Returns:
        A dict with ``user_id``, ``role``, and ``access_token`` on success,
        or a Flask error response on failure.
    """
    sb = get_supabase()

    try:
        user_response = sb.auth.get_user(jwt_token)
    except AuthApiError:
        return error_response(
            "session_expired",
            "Session has expired or is invalid",
            401,
        )

    user = user_response.user
    if not user:
        return error_response(
            "session_expired",
            "Session has expired or is invalid",
            401,
        )

    user_id = user.id

    # Fetch role from user_profile
    role = None
    profile_result = (
        sb.table("user_profile")
        .select("role")
        .eq("user_id", user_id)
        .execute()
    )
    if profile_result.data:
        role = profile_result.data[0].get("role")

    return {
        "user_id": user_id,
        "role": role,
        "access_token": jwt_token,
    }
