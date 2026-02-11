"""Patient service — sample upload and profile management.

Provides business logic for patient-facing endpoints: batch sample
upload with validation, profile retrieval, and partial profile update.
"""

from datetime import datetime, timezone

from app.errors import error_response
from app.models.validators import validate_profile_fields, validate_sample
from app.services.supabase_client import get_supabase


def upload_samples(user_id, samples):
    """Validate and batch-insert physiological samples.

    Args:
        user_id: The authenticated patient's user ID.
        samples: List of sample dicts to insert.

    Returns:
        Tuple of (result_dict, status_code). On success the dict
        contains ``{"inserted": <count>}`` with status 201. On
        validation failure the dict contains the error payload with
        status 400.
    """
    invalid_indices = []
    for idx, sample in enumerate(samples):
        is_valid, _errors = validate_sample(sample)
        if not is_valid:
            invalid_indices.append(idx)

    if invalid_indices:
        return (
            error_response(
                "invalid_samples",
                "Batch contains invalid samples",
                400,
            ),
            None,
        )

    # Prepare rows for batch insert
    rows = []
    for sample in samples:
        rows.append({
            "user_id": user_id,
            "window_start": sample.get("window_start"),
            "avg_heart_rate": sample["avg_heart_rate"],
            "rmssd": sample.get("rmssd"),
            "sdnn": sample.get("sdnn"),
            "sample_count": sample["sample_count"],
        })

    sb = get_supabase()
    sb.table("physiological_samples").insert(rows).execute()

    return {"inserted": len(rows)}, 201


def get_profile(user_id):
    """Fetch the patient's user profile.

    Args:
        user_id: The patient's user ID.

    Returns:
        The profile dict on success, or a Flask error response
        if no profile is found.
    """
    sb = get_supabase()

    result = (
        sb.table("user_profile")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )

    if not result.data:
        return error_response(
            "profile_not_found",
            "No profile found for the given user",
            404,
        )

    return result.data[0]


def update_profile(user_id, fields):
    """Validate and partially update the patient's profile.

    Args:
        user_id: The patient's user ID.
        fields: Dict of fields to update.

    Returns:
        Tuple of (result, status_code) or a Flask error response
        on validation failure.
    """
    is_valid, invalid_fields = validate_profile_fields(fields)
    if not is_valid:
        return (
            error_response(
                "invalid_profile_data",
                "Profile fields failed validation",
                400,
            ),
            None,
        )

    # Only allow known updatable fields
    allowed = {
        "name", "age", "sex", "height_cm",
        "weight_kg", "exercise_frequency", "activity_level",
    }
    update_data = {k: v for k, v in fields.items() if k in allowed}
    update_data["updated_at"] = datetime.now(timezone.utc).isoformat()

    sb = get_supabase()
    result = (
        sb.table("user_profile")
        .update(update_data)
        .eq("user_id", user_id)
        .execute()
    )

    return result.data[0] if result.data else {}, 200
