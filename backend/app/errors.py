import logging
from flask import jsonify

logger = logging.getLogger(__name__)


def error_response(error_code, message, status_code):
    """Return a consistent JSON error response.

    Returns JSON: {"error": "<error_code>", "message": "<message>"}
    """
    response = jsonify({"error": error_code, "message": message})
    response.status_code = status_code
    return response


def register_error_handlers(app):
    """Register global error handlers on the Flask app.

    Handles 404, 500, and unhandled exceptions. Logs tracebacks
    server-side and returns sanitized error responses to the client.
    """

    @app.errorhandler(404)
    def not_found(e):
        return error_response("not_found", "Resource not found", 404)

    @app.errorhandler(500)
    def internal_error(e):
        logger.exception("Internal server error")
        return error_response(
            "internal_server_error",
            "An internal server error occurred",
            500,
        )

    @app.errorhandler(Exception)
    def unhandled_exception(e):
        logger.exception("Unhandled exception: %s", str(e))
        return error_response(
            "internal_server_error",
            "An internal server error occurred",
            500,
        )
