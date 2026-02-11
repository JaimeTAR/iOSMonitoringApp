"""Role-based access control middleware.

Checks that the authenticated user's role (set by @require_auth)
matches the role required by the endpoint.
"""

from functools import wraps

from flask import g

from app.errors import error_response


def require_role(role):
    """Decorator that enforces role-based access control.

    Must be applied **after** ``@require_auth`` so that ``g.user_role``
    is already populated.

    Args:
        role: The role string required to access the endpoint
              (e.g. ``"clinician"`` or ``"patient"``).

    Returns 403 with error ``forbidden`` when the authenticated user's
    role does not match the required role.
    """

    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if getattr(g, "user_role", None) != role:
                return error_response(
                    "forbidden",
                    "You do not have permission to access this resource",
                    403,
                )
            return f(*args, **kwargs)

        return decorated

    return decorator
