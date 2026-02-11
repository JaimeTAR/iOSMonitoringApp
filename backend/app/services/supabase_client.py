"""Supabase client singleton.

Initializes a supabase.Client using SUPABASE_URL and SUPABASE_SERVICE_KEY
from the Flask app config. Uses the service key (not anon key) so the API
can perform admin operations.
"""

import supabase

_supabase_client = None


def init_supabase(app):
    """Initialize the Supabase client singleton from Flask app config.

    Reads ``SUPABASE_URL`` and ``SUPABASE_SERVICE_KEY`` from the app
    configuration and creates the shared client instance.

    Args:
        app: The Flask application instance.

    Raises:
        RuntimeError: If URL or service key is missing from config.
    """
    global _supabase_client

    url = app.config.get("SUPABASE_URL")
    key = app.config.get("SUPABASE_SERVICE_KEY")

    if not url or not key:
        raise RuntimeError(
            "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set "
            "in the application config."
        )

    _supabase_client = supabase.create_client(url, key)


def get_supabase():
    """Return the Supabase client singleton.

    Returns:
        The initialized Supabase client instance.

    Raises:
        RuntimeError: If the client has not been initialized.
    """
    if _supabase_client is None:
        raise RuntimeError(
            "Supabase client not initialized. "
            "Call init_supabase(app) first."
        )
    return _supabase_client
