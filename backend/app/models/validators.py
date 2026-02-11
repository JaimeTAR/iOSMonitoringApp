"""Pure input validation functions.

Each validator is a pure function with no side effects, making them
independently testable via property-based tests.
"""

import re
from datetime import datetime
from typing import Optional


def validate_heart_rate(bpm) -> bool:
    """Return True if bpm is a number in [30, 220]."""
    try:
        value = float(bpm)
    except (TypeError, ValueError):
        return False
    return 30 <= value <= 220


def validate_invitation_code_format(code) -> bool:
    """Return True if code is exactly 5 alphanumeric characters."""
    if not isinstance(code, str):
        return False
    return bool(re.fullmatch(r"[A-Za-z0-9]{5}", code))


def validate_iso8601(date_str) -> Optional[datetime]:
    """Parse an ISO 8601 date string and return a datetime, or None."""
    if not isinstance(date_str, str):
        return None
    try:
        dt = datetime.fromisoformat(date_str)
        return dt
    except (ValueError, TypeError):
        return None


def validate_sample(sample_dict) -> tuple:
    """Validate a physiological sample dictionary.

    Returns (is_valid, errors) where errors is a list of field-level
    error strings.

    Rules:
      - avg_heart_rate: required, 0 <= value <= 300
      - rmssd: when present, must be >= 0
      - sdnn: when present, must be >= 0
      - sample_count: required, must be > 0
    """
    errors = []

    # avg_heart_rate: required, 0-300
    hr = sample_dict.get("avg_heart_rate")
    if hr is None:
        errors.append("avg_heart_rate is required")
    else:
        try:
            hr_val = float(hr)
            if not (0 <= hr_val <= 300):
                errors.append("avg_heart_rate must be between 0 and 300")
        except (TypeError, ValueError):
            errors.append("avg_heart_rate must be a number")

    # rmssd: optional, >= 0
    if "rmssd" in sample_dict and sample_dict["rmssd"] is not None:
        try:
            rmssd_val = float(sample_dict["rmssd"])
            if rmssd_val < 0:
                errors.append("rmssd must be non-negative")
        except (TypeError, ValueError):
            errors.append("rmssd must be a number")

    # sdnn: optional, >= 0
    if "sdnn" in sample_dict and sample_dict["sdnn"] is not None:
        try:
            sdnn_val = float(sample_dict["sdnn"])
            if sdnn_val < 0:
                errors.append("sdnn must be non-negative")
        except (TypeError, ValueError):
            errors.append("sdnn must be a number")

    # sample_count: required, > 0
    sc = sample_dict.get("sample_count")
    if sc is None:
        errors.append("sample_count is required")
    else:
        try:
            sc_val = int(sc)
            if sc_val <= 0:
                errors.append("sample_count must be positive")
        except (TypeError, ValueError):
            errors.append("sample_count must be an integer")

    return (len(errors) == 0, errors)


def validate_profile_fields(fields) -> tuple:
    """Validate profile update fields.

    Returns (is_valid, invalid_fields) where invalid_fields is a list
    of field names that are out of bounds.

    Rules:
      - age (when present): 1-149
      - height_cm (when present): 0-300
      - weight_kg (when present): 0-500
      - exercise_frequency (when present): 0-21
    """
    invalid_fields = []

    bounds = {
        "age": (1, 149),
        "height_cm": (0, 300),
        "weight_kg": (0, 500),
        "exercise_frequency": (0, 21),
    }

    for field_name, (lo, hi) in bounds.items():
        if field_name in fields and fields[field_name] is not None:
            try:
                val = float(fields[field_name])
                if not (lo <= val <= hi):
                    invalid_fields.append(field_name)
            except (TypeError, ValueError):
                invalid_fields.append(field_name)

    return (len(invalid_fields) == 0, invalid_fields)
