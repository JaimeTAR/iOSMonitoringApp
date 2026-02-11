from flask import Flask, jsonify

from app.config import config_by_name
from app.errors import register_error_handlers
from app.blueprints.auth import auth_bp
from app.blueprints.clinician import clinician_bp
from app.blueprints.patient import patient_bp
from app.services.supabase_client import init_supabase, get_supabase


def create_app(config_name="development"):
    """Application factory for the Flask API.

    Args:
        config_name: One of 'development', 'testing', 'production'.

    Returns:
        A configured Flask application instance.
    """
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])

    # Initialize Supabase client
    if not app.config.get("TESTING"):
        init_supabase(app)

    # Register blueprints
    app.register_blueprint(auth_bp)
    app.register_blueprint(clinician_bp)
    app.register_blueprint(patient_bp)

    # Register error handlers
    register_error_handlers(app)

    # Health check endpoint — registered directly on the app, no auth
    @app.route("/health")
    def health_check():
        try:
            sb = get_supabase()
            sb.table("user_profile").select("id").limit(1).execute()
            return jsonify({"status": "healthy"}), 200
        except Exception:
            return (
                jsonify({
                    "status": "unhealthy",
                    "error": "supabase_unavailable",
                }),
                503,
            )

    return app
