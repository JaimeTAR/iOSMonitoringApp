"""JWT authentication middleware.

Validates Supabase-issued JWTs from the Authorization header,
sets g.user_id and g.user_role on success.
"""

from functools import wraps

import jwt
from flask import request, g, current_app

from app.errors import error_response


def require_auth(f):
    """Decorator that validates a Supabase JWT from the Authorization header.

    Extracts the token from ``Authorization: Bearer <token>``, decodes it
    using the configured ``SUPABASE_JWT_SECRET`` with HS256, and sets
    ``g.user_id`` (from the ``sub`` claim) and ``g.user_role`` (from
    ``user_metadata.role``, falling back to the top-level ``role`` claim).

    Returns 401 with the appropriate error code on failure:
    - ``missing_token`` – no Authorization header present
    - ``invalid_token`` – malformed JWT or signature mismatch
    - ``token_expired`` – JWT ``exp`` claim is in the past
    """

    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")

        if not auth_header:
            return error_response("missing_token", "Authorization header is required", 401)

        # Expect "Bearer <token>"
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            return error_response("invalid_token", "Invalid authorization header format", 401)

        token = parts[1]
        secret = current_app.config.get("SUPABASE_JWT_SECRET", "")

        try:
            payload = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
                options={"require": ["exp", "sub"]},
            )
        except jwt.ExpiredSignatureError:
            return error_response("token_expired", "Token has expired", 401)
        except jwt.InvalidTokenError:
            return error_response("invalid_token", "Invalid or malformed token", 401)

        # Extract user_id from sub claim
        g.user_id = payload.get("sub")

        # Extract role: prefer user_metadata.role, fall back to top-level role
        user_metadata = payload.get("user_metadata", {})
        if isinstance(user_metadata, dict) and user_metadata.get("role"):
            g.user_role = user_metadata["role"]
        else:
            g.user_role = payload.get("role")

        return f(*args, **kwargs)

    return decorated
