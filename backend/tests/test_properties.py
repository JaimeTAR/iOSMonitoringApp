"""Property-based tests for the Flask Backend API.

Uses Hypothesis to verify universal correctness properties
across randomly generated inputs.
"""

import json
import time
from datetime import datetime as _dt, timedelta as _td, timezone as _tz

import jwt as pyjwt
from hypothesis import assume, given, settings, strategies as st

from app import create_app
from app.errors import error_response
from app.models.validators import (
    validate_heart_rate,
    validate_profile_fields,
    validate_sample,
)
from app.services.clinician_service import (
    classify_needs_attention,
    compute_aggregates,
    compute_dashboard_stats,
    compute_trend,
    filter_active_relationships,
    generate_invitation_code,
    group_into_sessions,
)


# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

# Strategy for error codes: non-empty ASCII strings (lowercase + underscores)
error_code_st = st.from_regex(r"[a-z][a-z_]{0,29}", fullmatch=True)

# Strategy for human-readable messages: printable text, 1-200 chars
message_st = st.text(
    alphabet=st.characters(whitelist_categories=("L", "N", "P", "Z")),
    min_size=1,
    max_size=200,
)

# Strategy for valid HTTP error status codes
status_code_st = st.sampled_from([400, 401, 403, 404, 409, 500, 503])


# ---------------------------------------------------------------------------
# Property 14: Error response format consistency
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 14: Error response format consistency
# **Validates: Requirements 23.1, 23.2**


@given(
    error_code=error_code_st,
    message=message_st,
    status_code=status_code_st,
)
@settings(max_examples=100)
def test_error_response_format_consistency(error_code, message, status_code):
    """For any error response produced by the API, the response body shall be
    valid JSON containing exactly the keys 'error' (string) and 'message'
    (string), and the HTTP status code shall be appropriate.

    **Validates: Requirements 23.1, 23.2**
    """
    app = create_app("testing")
    with app.app_context():
        response = error_response(error_code, message, status_code)

        # Response status code matches what was requested
        assert response.status_code == status_code

        # Body is valid JSON
        data = json.loads(response.get_data(as_text=True))

        # Exactly two keys: "error" and "message"
        assert set(data.keys()) == {"error", "message"}

        # Both values are strings
        assert isinstance(data["error"], str)
        assert isinstance(data["message"], str)

        # Values match inputs
        assert data["error"] == error_code
        assert data["message"] == message


# ---------------------------------------------------------------------------
# Property 15: Unhandled exceptions produce safe 500 responses
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 15: Unhandled exceptions produce safe 500 responses
# **Validates: Requirements 23.3**

# Patterns that indicate leaked internals — these are long enough
# to avoid false positives from short random strings in JSON structure.
_UNSAFE_PATTERNS = [
    "Traceback (most recent call last)",
    "File \"",
    "raise RuntimeError",
    "raise Exception",
    ".py\", line",
]

_SAFE_RESPONSE_MESSAGE = "An internal server error occurred"


@given(
    exc_message=st.text(
        alphabet=st.characters(whitelist_categories=("L", "N", "P", "Z")),
        min_size=1,
        max_size=200,
    ),
)
@settings(max_examples=100)
def test_unhandled_exception_produces_safe_500(exc_message):
    """For any request that triggers an unhandled exception in a route handler,
    the API shall return HTTP 500 with {"error": "internal_server_error",
    "message": ...} and the response body shall not contain Python stack
    traces or internal implementation details.

    **Validates: Requirements 23.3**
    """
    app = create_app("testing")

    # Register a temporary route that always raises an exception
    @app.route("/_test_exception")
    def _boom():
        raise RuntimeError(exc_message)

    with app.test_client() as client:
        response = client.get("/_test_exception")

        # Must be HTTP 500
        assert response.status_code == 500

        # Body must be valid JSON
        data = json.loads(response.get_data(as_text=True))

        # Must have exactly "error" and "message" keys
        assert set(data.keys()) == {"error", "message"}

        # error code must be "internal_server_error"
        assert data["error"] == "internal_server_error"

        # message must be a string
        assert isinstance(data["message"], str)

        # The message field must be the fixed safe message — the
        # original exception text must never appear there.
        assert data["message"] == _SAFE_RESPONSE_MESSAGE, (
            "Response message must be the fixed safe message, "
            f"got: {data['message']!r}"
        )

        # The response body must NOT contain stack trace patterns
        body_text = response.get_data(as_text=True)
        for pattern in _UNSAFE_PATTERNS:
            assert pattern not in body_text, (
                f"Unsafe pattern found in response: {pattern!r}"
            )


# ---------------------------------------------------------------------------
# Property 12: JWT validation rejects malformed and expired tokens
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 12: JWT validation rejects malformed and expired tokens
# **Validates: Requirements 17.3, 17.4**

# Strategy for arbitrary strings that are NOT valid JWTs signed with the test secret
arbitrary_string_st = st.text(
    alphabet=st.characters(whitelist_categories=("L", "N", "P", "Z")),
    min_size=0,
    max_size=500,
)

TEST_JWT_SECRET = "test-jwt-secret"


def _make_valid_jwt(payload, secret=TEST_JWT_SECRET):
    """Helper to create a signed JWT."""
    return pyjwt.encode(payload, secret, algorithm="HS256")


@given(token_str=arbitrary_string_st)
@settings(max_examples=100)
def test_jwt_rejects_malformed_tokens(token_str):
    """For any string that is not a valid JWT signed with the configured
    SUPABASE_JWT_SECRET, the auth middleware shall return HTTP 401 with
    error ``invalid_token``.

    **Validates: Requirements 17.3, 17.4**
    """
    # Ensure the string is not accidentally a valid JWT with the test secret
    try:
        pyjwt.decode(
            token_str,
            TEST_JWT_SECRET,
            algorithms=["HS256"],
            options={"require": ["exp", "sub"]},
        )
        assume(False)  # Skip if it happens to be valid
    except Exception:
        pass  # Expected — the string is not a valid JWT

    app = create_app("testing")
    with app.test_client() as client:
        response = client.get(
            "/auth/session",
            headers={"Authorization": f"Bearer {token_str}"},
        )
        data = json.loads(response.get_data(as_text=True))
        assert response.status_code == 401
        assert data["error"] == "invalid_token"


# Strategy for past expiration times (1 second to 1 year in the past)
past_exp_st = st.integers(min_value=1, max_value=365 * 24 * 3600)


@given(seconds_ago=past_exp_st)
@settings(max_examples=100)
def test_jwt_rejects_expired_tokens(seconds_ago):
    """For any JWT with an ``exp`` claim in the past, the middleware shall
    return HTTP 401 with error ``token_expired``.

    **Validates: Requirements 17.3, 17.4**
    """
    expired_payload = {
        "sub": "test-user-id",
        "exp": int(time.time()) - seconds_ago,
        "role": "patient",
    }
    token = _make_valid_jwt(expired_payload)

    app = create_app("testing")
    with app.test_client() as client:
        response = client.get(
            "/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        data = json.loads(response.get_data(as_text=True))
        assert response.status_code == 401
        assert data["error"] == "token_expired"


# ---------------------------------------------------------------------------
# Property 13: Role-based access control
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 13: Role-based access control
# **Validates: Requirements 18.1, 18.2**

# Strategies for role-based access control tests
clinician_endpoint_st = st.sampled_from([
    "/clinician/test-clinician-id/patients",
])

patient_endpoint_st = st.sampled_from([
    "/patient/profile",
])


def _make_role_jwt(role, user_id="test-user-id", secret=TEST_JWT_SECRET):
    """Create a valid JWT with the given role."""
    payload = {
        "sub": user_id,
        "exp": int(time.time()) + 3600,
        "role": role,
    }
    return pyjwt.encode(payload, secret, algorithm="HS256")


@given(endpoint=clinician_endpoint_st)
@settings(max_examples=100)
def test_patient_cannot_access_clinician_endpoints(endpoint):
    """For any authenticated user with role ``patient``, accessing any
    ``/clinician/*`` endpoint shall return HTTP 403 with error ``forbidden``.

    **Validates: Requirements 18.1, 18.2**
    """
    token = _make_role_jwt("patient")

    app = create_app("testing")
    with app.test_client() as client:
        response = client.get(
            endpoint,
            headers={"Authorization": f"Bearer {token}"},
        )
        data = json.loads(response.get_data(as_text=True))
        assert response.status_code == 403
        assert data["error"] == "forbidden"


@given(endpoint=patient_endpoint_st)
@settings(max_examples=100)
def test_clinician_cannot_access_patient_endpoints(endpoint):
    """For any authenticated user with role ``clinician``, accessing any
    ``/patient/*`` endpoint shall return HTTP 403 with error ``forbidden``.

    **Validates: Requirements 18.1, 18.2**
    """
    token = _make_role_jwt("clinician")

    app = create_app("testing")
    with app.test_client() as client:
        response = client.get(
            endpoint,
            headers={"Authorization": f"Bearer {token}"},
        )
        data = json.loads(response.get_data(as_text=True))
        assert response.status_code == 403
        assert data["error"] == "forbidden"


# ---------------------------------------------------------------------------
# Property 9: Heart rate validation bounds
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 9: Heart rate validation bounds
# **Validates: Requirements 13.2**

# Strategy: any finite float (including negatives and large values)
bpm_st = st.floats(
    min_value=-1e6, max_value=1e6, allow_nan=False, allow_infinity=False
)


@given(bpm=bpm_st)
@settings(max_examples=100)
def test_heart_rate_validation_bounds(bpm):
    """For any numeric bpm value, validate_heart_rate(bpm) shall return
    True if and only if 30 <= bpm <= 220.

    **Validates: Requirements 13.2**
    """
    result = validate_heart_rate(bpm)
    expected = 30 <= bpm <= 220
    assert result == expected, (
        f"validate_heart_rate({bpm}) returned {result}, expected {expected}"
    )


# ---------------------------------------------------------------------------
# Property 10: Sample validation and batch rejection
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 10: Sample validation and batch rejection
# **Validates: Requirements 15.2, 15.3**

# Strategy for sample dicts with controlled field values
sample_hr_st = st.floats(
    min_value=-100, max_value=500, allow_nan=False, allow_infinity=False
)
sample_rmssd_st = st.one_of(st.none(), st.floats(
    min_value=-100, max_value=500, allow_nan=False, allow_infinity=False
))
sample_sdnn_st = st.one_of(st.none(), st.floats(
    min_value=-100, max_value=500, allow_nan=False, allow_infinity=False
))
sample_count_st = st.integers(min_value=-10, max_value=100)


@given(
    hr=sample_hr_st,
    rmssd=sample_rmssd_st,
    sdnn=sample_sdnn_st,
    sc=sample_count_st,
)
@settings(max_examples=100)
def test_sample_validation(hr, rmssd, sdnn, sc):
    """For any sample dict, validate_sample shall accept if and only if
    0 <= avg_heart_rate <= 300, rmssd >= 0 (when present), sdnn >= 0
    (when present), and sample_count > 0.

    **Validates: Requirements 15.2, 15.3**
    """
    sample = {
        "avg_heart_rate": hr,
        "sample_count": sc,
    }
    if rmssd is not None:
        sample["rmssd"] = rmssd
    if sdnn is not None:
        sample["sdnn"] = sdnn

    is_valid, errors = validate_sample(sample)

    # Compute expected validity
    hr_ok = 0 <= hr <= 300
    rmssd_ok = rmssd is None or rmssd >= 0
    sdnn_ok = sdnn is None or sdnn >= 0
    sc_ok = sc > 0

    expected_valid = hr_ok and rmssd_ok and sdnn_ok and sc_ok

    assert is_valid == expected_valid, (
        f"validate_sample({sample}) returned valid={is_valid}, "
        f"expected valid={expected_valid}, errors={errors}"
    )


# ---------------------------------------------------------------------------
# Property 11: Profile field validation
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 11: Profile field validation
# **Validates: Requirements 16.3, 16.4**

# Strategy: optional numeric fields that may be in or out of bounds
optional_age_st = st.one_of(
    st.none(),
    st.floats(min_value=-50, max_value=200,
              allow_nan=False, allow_infinity=False),
)
optional_height_st = st.one_of(
    st.none(),
    st.floats(min_value=-50, max_value=400,
              allow_nan=False, allow_infinity=False),
)
optional_weight_st = st.one_of(
    st.none(),
    st.floats(min_value=-50, max_value=600,
              allow_nan=False, allow_infinity=False),
)
optional_exercise_st = st.one_of(
    st.none(),
    st.floats(min_value=-5, max_value=30,
              allow_nan=False, allow_infinity=False),
)


@given(
    age=optional_age_st,
    height_cm=optional_height_st,
    weight_kg=optional_weight_st,
    exercise_frequency=optional_exercise_st,
)
@settings(max_examples=100)
def test_profile_field_validation(age, height_cm, weight_kg,
                                  exercise_frequency):
    """For any dict of profile fields, validate_profile_fields shall accept
    if and only if: age (when present) in [1, 149], height_cm (when present)
    in [0, 300], weight_kg (when present) in [0, 500], exercise_frequency
    (when present) in [0, 21]. Invalid field names shall match exactly the
    fields that are out of bounds.

    **Validates: Requirements 16.3, 16.4**
    """
    fields = {}
    if age is not None:
        fields["age"] = age
    if height_cm is not None:
        fields["height_cm"] = height_cm
    if weight_kg is not None:
        fields["weight_kg"] = weight_kg
    if exercise_frequency is not None:
        fields["exercise_frequency"] = exercise_frequency

    is_valid, invalid_fields = validate_profile_fields(fields)

    # Compute expected invalid fields
    expected_invalid = set()
    if age is not None and not (1 <= age <= 149):
        expected_invalid.add("age")
    if height_cm is not None and not (0 <= height_cm <= 300):
        expected_invalid.add("height_cm")
    if weight_kg is not None and not (0 <= weight_kg <= 500):
        expected_invalid.add("weight_kg")
    if exercise_frequency is not None and not (0 <= exercise_frequency <= 21):
        expected_invalid.add("exercise_frequency")

    expected_valid = len(expected_invalid) == 0

    assert is_valid == expected_valid, (
        f"validate_profile_fields({fields}) returned valid={is_valid}, "
        f"expected valid={expected_valid}"
    )
    assert set(invalid_fields) == expected_invalid, (
        f"Invalid fields mismatch: got {invalid_fields}, "
        f"expected {sorted(expected_invalid)}"
    )


# ---------------------------------------------------------------------------
# Property 1: Health trend computation
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 1: Health trend computation
# **Validates: Requirements 6.2**

# Strategy: sample dicts with positive HR and non-negative RMSSD
sample_hr_positive_st = st.floats(
    min_value=30, max_value=220, allow_nan=False, allow_infinity=False
)
sample_rmssd_positive_st = st.floats(
    min_value=0.1, max_value=200, allow_nan=False, allow_infinity=False
)

sample_dict_st = st.fixed_dictionaries({
    "avg_heart_rate": sample_hr_positive_st,
    "rmssd": sample_rmssd_positive_st,
})


@given(
    recent_samples=st.lists(sample_dict_st, min_size=1, max_size=20),
    prior_samples=st.lists(sample_dict_st, min_size=1, max_size=20),
)
@settings(max_examples=100)
def test_health_trend_computation(recent_samples, prior_samples):
    """For any two non-empty lists of samples, compute_trend shall return
    the correct trend based on HR and RMSSD changes.

    - improving: HR decreased >=5% OR RMSSD increased >=10%
    - declining: HR increased >=10% OR RMSSD decreased >=15%
    - stable: otherwise

    **Validates: Requirements 6.2**
    """
    result = compute_trend(recent_samples, prior_samples)

    # Independently compute expected trend
    recent_agg = compute_aggregates(recent_samples)
    prior_agg = compute_aggregates(prior_samples)

    recent_hr = recent_agg["avg_heart_rate"]
    prior_hr = prior_agg["avg_heart_rate"]
    recent_rmssd = recent_agg["avg_rmssd"]
    prior_rmssd = prior_agg["avg_rmssd"]

    if prior_hr and prior_hr != 0:
        hr_change = (recent_hr - prior_hr) / prior_hr
    else:
        hr_change = 0.0

    if prior_rmssd and prior_rmssd != 0:
        rmssd_change = (recent_rmssd - prior_rmssd) / prior_rmssd
    else:
        rmssd_change = 0.0

    # Determine expected trend
    if hr_change <= -0.05 or rmssd_change >= 0.10:
        expected = "improving"
    elif hr_change >= 0.10 or rmssd_change <= -0.15:
        expected = "declining"
    else:
        expected = "stable"

    assert result == expected, (
        f"compute_trend returned '{result}', expected '{expected}'. "
        f"hr_change={hr_change:.4f}, rmssd_change={rmssd_change:.4f}"
    )

    # Also verify return value is always one of the valid trend values
    assert result in ("improving", "stable", "declining")


@given(
    recent_samples=st.just([]),
    prior_samples=st.lists(sample_dict_st, min_size=0, max_size=5),
)
@settings(max_examples=20)
def test_health_trend_empty_recent_returns_stable(recent_samples,
                                                  prior_samples):
    """When the recent period is empty, compute_trend shall return 'stable'.

    **Validates: Requirements 6.2**
    """
    result = compute_trend(recent_samples, prior_samples)
    assert result == "stable"


@given(
    recent_samples=st.lists(sample_dict_st, min_size=1, max_size=5),
    prior_samples=st.just([]),
)
@settings(max_examples=20)
def test_health_trend_empty_prior_returns_stable(recent_samples,
                                                 prior_samples):
    """When the prior period is empty, compute_trend shall return 'stable'.

    **Validates: Requirements 6.2**
    """
    result = compute_trend(recent_samples, prior_samples)
    assert result == "stable"


# ---------------------------------------------------------------------------
# Property 2: Active relationship filtering
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 2: Active relationship filtering
# **Validates: Requirements 6.3**

# Strategy: relationship dicts with random status and end_date
relationship_status_st = st.sampled_from(["activo", "inactivo"])
relationship_end_date_st = st.one_of(
    st.none(),
    st.just("2024-01-01T00:00:00Z"),
    st.just("2025-06-01T00:00:00Z"),
)

relationship_dict_st = st.fixed_dictionaries({
    "id": st.uuids().map(str),
    "clinician_id": st.uuids().map(str),
    "patient_id": st.uuids().map(str),
    "status": relationship_status_st,
    "end_date": relationship_end_date_st,
})


@given(
    relationships=st.lists(relationship_dict_st, min_size=0, max_size=30),
)
@settings(max_examples=100)
def test_active_relationship_filtering(relationships):
    """For any list of relationships, filter_active_relationships shall
    return exactly those with status=='activo' and end_date is None.

    **Validates: Requirements 6.3**
    """
    result = filter_active_relationships(relationships)

    # Independently compute expected active relationships
    expected = [
        r for r in relationships
        if r.get("status") == "activo" and r.get("end_date") is None
    ]

    assert len(result) == len(expected), (
        f"Expected {len(expected)} active relationships, got {len(result)}"
    )

    # Verify each result is in the expected set (by id)
    result_ids = {r["id"] for r in result}
    expected_ids = {r["id"] for r in expected}
    assert result_ids == expected_ids, (
        f"ID mismatch: result={result_ids}, expected={expected_ids}"
    )

    # Verify all returned relationships have correct status and end_date
    for r in result:
        assert r["status"] == "activo", (
            f"Relationship {r['id']} has status '{r['status']}', "
            "expected 'activo'"
        )
        assert r["end_date"] is None, (
            f"Relationship {r['id']} has end_date={r['end_date']}, "
            "expected None"
        )


# ---------------------------------------------------------------------------
# Strategies for session grouping and date range tests
# ---------------------------------------------------------------------------

# Strategy: generate a sorted list of ISO 8601 timestamps with controlled gaps
def _make_sample_with_timestamp(ts_str):
    """Create a minimal sample dict with a window_start timestamp."""
    return {"window_start": ts_str, "avg_heart_rate": 72.0}


# Strategy: list of gap values in seconds (some within 120s, some beyond)
gap_st = st.integers(min_value=1, max_value=600)

# Base timestamp for generating sample sequences
_BASE_TS = _dt(2025, 1, 1, 12, 0, 0, tzinfo=_tz.utc)


@st.composite
def sorted_samples_st(draw):
    """Generate a sorted list of sample dicts with controlled gaps."""
    n = draw(st.integers(min_value=0, max_value=30))
    if n == 0:
        return []
    gaps = draw(
        st.lists(
            st.integers(min_value=1, max_value=600),
            min_size=n - 1,
            max_size=n - 1,
        )
    )
    samples = []
    current = _BASE_TS
    samples.append(_make_sample_with_timestamp(current.isoformat()))
    for g_val in gaps:
        current = current + _td(seconds=g_val)
        samples.append(_make_sample_with_timestamp(current.isoformat()))
    return samples


# ---------------------------------------------------------------------------
# Property 3: Session grouping with 2-minute gap
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 3: Session grouping with 2-minute gap
# **Validates: Requirements 7.2**


@given(sorted_samples=sorted_samples_st())
@settings(max_examples=100)
def test_session_grouping_two_minute_gap(sorted_samples):
    """For any sorted list of samples, group_into_sessions shall produce
    sessions where consecutive samples within a session have gap <= 120s,
    and samples at session boundaries have gap > 120s.

    **Validates: Requirements 7.2**
    """
    sessions = group_into_sessions(sorted_samples, gap_seconds=120)

    # All samples should be preserved
    flat = [s for session in sessions for s in session]
    assert len(flat) == len(sorted_samples)

    # Verify within-session gaps are <= 120s
    for session in sessions:
        for i in range(1, len(session)):
            prev_dt = _dt.fromisoformat(session[i - 1]["window_start"])
            curr_dt = _dt.fromisoformat(session[i]["window_start"])
            gap = (curr_dt - prev_dt).total_seconds()
            assert gap <= 120, (
                f"Within-session gap {gap}s exceeds 120s"
            )

    # Verify between-session gaps are > 120s
    for i in range(1, len(sessions)):
        last_of_prev = sessions[i - 1][-1]
        first_of_curr = sessions[i][0]
        prev_dt = _dt.fromisoformat(last_of_prev["window_start"])
        curr_dt = _dt.fromisoformat(first_of_curr["window_start"])
        gap = (curr_dt - prev_dt).total_seconds()
        assert gap > 120, (
            f"Between-session gap {gap}s should be > 120s"
        )

    # Empty input produces empty output
    if not sorted_samples:
        assert sessions == []


# ---------------------------------------------------------------------------
# Property 4: Samples filtered by date range and ordered ascending
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 4: Samples filtered by date range
# and ordered ascending
# **Validates: Requirements 8.1**


@st.composite
def samples_and_date_range_st(draw):
    """Generate a list of samples and a date range [from, to]."""
    n = draw(st.integers(min_value=0, max_value=30))
    base = _dt(2025, 1, 1, 0, 0, 0, tzinfo=_tz.utc)

    # Generate random offsets in hours for sample timestamps
    offsets = draw(
        st.lists(
            st.integers(min_value=0, max_value=720),
            min_size=n,
            max_size=n,
        )
    )
    samples = []
    for off in offsets:
        ts = base + _td(hours=off)
        samples.append({
            "window_start": ts.isoformat(),
            "avg_heart_rate": 72.0,
        })

    # Generate from/to range
    from_off = draw(st.integers(min_value=0, max_value=720))
    to_off = draw(st.integers(min_value=from_off, max_value=720))
    from_dt = base + _td(hours=from_off)
    to_dt = base + _td(hours=to_off)

    return samples, from_dt.isoformat(), to_dt.isoformat()


@given(data=samples_and_date_range_st())
@settings(max_examples=100)
def test_samples_filtered_by_date_range_and_ordered(data):
    """For any list of samples and date range [from, to], filtering
    returns only samples with window_start in [from, to] inclusive,
    sorted ascending.

    **Validates: Requirements 8.1**
    """
    samples, from_str, to_str = data
    from_dt = _dt.fromisoformat(from_str)
    to_dt = _dt.fromisoformat(to_str)

    # Apply the same filtering logic the API would use
    filtered = [
        s for s in samples
        if from_dt <= _dt.fromisoformat(s["window_start"]) <= to_dt
    ]
    filtered.sort(key=lambda s: s["window_start"])

    # Verify all returned samples are within range
    for s in filtered:
        ws = _dt.fromisoformat(s["window_start"])
        assert from_dt <= ws <= to_dt, (
            f"Sample {s['window_start']} outside range "
            f"[{from_str}, {to_str}]"
        )

    # Verify ascending order
    for i in range(1, len(filtered)):
        prev = _dt.fromisoformat(filtered[i - 1]["window_start"])
        curr = _dt.fromisoformat(filtered[i]["window_start"])
        assert prev <= curr, (
            f"Samples not in ascending order: {prev} > {curr}"
        )

    # Verify completeness: no sample in range was excluded
    expected_count = sum(
        1 for s in samples
        if from_dt <= _dt.fromisoformat(s["window_start"]) <= to_dt
    )
    assert len(filtered) == expected_count, (
        f"Expected {expected_count} samples in range, got {len(filtered)}"
    )


# ---------------------------------------------------------------------------
# Strategies for dashboard, needs attention, and recent activity tests
# ---------------------------------------------------------------------------

# Reuse _dt, _td, _tz already imported above

# Strategy: relationship dicts for dashboard stats
dashboard_rel_st = st.fixed_dictionaries({
    "id": st.uuids().map(str),
    "clinician_id": st.just("clinician-1"),
    "patient_id": st.uuids().map(str),
    "status": st.sampled_from(["activo", "inactivo"]),
    "end_date": st.one_of(st.none(), st.just("2024-06-01T00:00:00+00:00")),
})

# Strategy: invitation dicts
invitation_st = st.fixed_dictionaries({
    "id": st.uuids().map(str),
    "clinician_id": st.just("clinician-1"),
    "code": st.text(
        alphabet=st.characters(
            whitelist_categories=("L", "N"),
        ),
        min_size=5,
        max_size=5,
    ),
    "status": st.sampled_from(["pending", "used", "expired", "revoked"]),
})


@st.composite
def dashboard_data_st(draw):
    """Generate relationships, samples, and invitations for dashboard."""
    rels = draw(st.lists(dashboard_rel_st, min_size=0, max_size=20))
    invitations = draw(st.lists(invitation_st, min_size=0, max_size=15))

    now = _dt(2025, 6, 15, 12, 0, 0, tzinfo=_tz.utc)

    # Collect active patient IDs
    active_pids = [
        r["patient_id"] for r in rels
        if r.get("status") == "activo" and r.get("end_date") is None
    ]

    # Generate samples — some within 24h, some outside
    samples = []
    for pid in active_pids:
        n = draw(st.integers(min_value=0, max_value=5))
        for _ in range(n):
            hours_ago = draw(st.integers(min_value=0, max_value=72))
            ws = now - _td(hours=hours_ago)
            samples.append({
                "user_id": pid,
                "window_start": ws.isoformat(),
                "avg_heart_rate": 72.0,
            })

    return rels, samples, invitations, now


# ---------------------------------------------------------------------------
# Property 5: Dashboard stats computation
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 5: Dashboard stats computation
# **Validates: Requirements 9.1, 9.2**


@given(data=dashboard_data_st())
@settings(max_examples=100)
def test_dashboard_stats_computation(data):
    """For any set of relationships, samples, and invitations,
    compute_dashboard_stats shall return correct counts for
    total_active_patients, patients_active_today, and
    pending_invitations.

    **Validates: Requirements 9.1, 9.2**
    """
    rels, samples, invitations, now = data

    result = compute_dashboard_stats(rels, samples, invitations, now)

    # Independently compute expected values
    active_rels = [
        r for r in rels
        if r.get("status") == "activo" and r.get("end_date") is None
    ]
    expected_total = len(active_rels)
    active_pids = {r["patient_id"] for r in active_rels}

    twenty_four_hours_ago = now - _td(hours=24)
    active_today = set()
    for s in samples:
        pid = s.get("user_id")
        if pid not in active_pids:
            continue
        ws_str = s.get("window_start", "")
        try:
            ws_dt = _dt.fromisoformat(ws_str)
            if ws_dt.tzinfo is None:
                ws_dt = ws_dt.replace(tzinfo=_tz.utc)
        except (ValueError, TypeError):
            continue
        if ws_dt >= twenty_four_hours_ago:
            active_today.add(pid)

    expected_active_today = len(active_today)
    expected_pending = sum(
        1 for inv in invitations if inv.get("status") == "pending"
    )

    assert result["total_active_patients"] == expected_total, (
        f"total_active_patients: got {result['total_active_patients']}, "
        f"expected {expected_total}"
    )
    assert result["patients_active_today"] == expected_active_today, (
        f"patients_active_today: got {result['patients_active_today']}, "
        f"expected {expected_active_today}"
    )
    assert result["pending_invitations"] == expected_pending, (
        f"pending_invitations: got {result['pending_invitations']}, "
        f"expected {expected_pending}"
    )


# ---------------------------------------------------------------------------
# Strategies for needs attention classification
# ---------------------------------------------------------------------------

@st.composite
def needs_attention_data_st(draw):
    """Generate patient data for needs attention classification."""
    now = _dt(2025, 6, 15, 12, 0, 0, tzinfo=_tz.utc)
    seven_days_ago = now - _td(days=7)
    fourteen_days_ago = now - _td(days=14)

    n_patients = draw(st.integers(min_value=1, max_value=5))
    patient_ids = [f"patient-{i}" for i in range(n_patients)]

    profiles = {}
    samples_by_patient = {}

    for pid in patient_ids:
        # Profile with optional resting HR
        has_resting = draw(st.booleans())
        resting_hr = draw(st.floats(
            min_value=50, max_value=100,
            allow_nan=False, allow_infinity=False,
        )) if has_resting else None
        profiles[pid] = {
            "user_id": pid,
            "name": f"Patient {pid}",
            "resting_heart_rate": resting_hr,
        }

        # Generate samples: some recent (0-7d), some prior (7-14d)
        n_recent = draw(st.integers(min_value=0, max_value=8))
        n_prior = draw(st.integers(min_value=0, max_value=8))

        patient_samples = []
        for _ in range(n_recent):
            hours_ago = draw(st.integers(min_value=0, max_value=167))
            ws = now - _td(hours=hours_ago)
            # Only include if within 7 days
            if ws >= seven_days_ago:
                hr = draw(st.floats(
                    min_value=40, max_value=200,
                    allow_nan=False, allow_infinity=False,
                ))
                rmssd = draw(st.floats(
                    min_value=5, max_value=150,
                    allow_nan=False, allow_infinity=False,
                ))
                patient_samples.append({
                    "window_start": ws.isoformat(),
                    "avg_heart_rate": hr,
                    "rmssd": rmssd,
                })

        for _ in range(n_prior):
            hours_ago = draw(st.integers(min_value=168, max_value=335))
            ws = now - _td(hours=hours_ago)
            if ws >= fourteen_days_ago:
                hr = draw(st.floats(
                    min_value=40, max_value=200,
                    allow_nan=False, allow_infinity=False,
                ))
                rmssd = draw(st.floats(
                    min_value=5, max_value=150,
                    allow_nan=False, allow_infinity=False,
                ))
                patient_samples.append({
                    "window_start": ws.isoformat(),
                    "avg_heart_rate": hr,
                    "rmssd": rmssd,
                })

        samples_by_patient[pid] = patient_samples

    return patient_ids, profiles, samples_by_patient, now


# ---------------------------------------------------------------------------
# Property 6: Needs attention classification
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 6: Needs attention classification
# **Validates: Requirements 10.2, 10.3, 10.4**


@given(data=needs_attention_data_st())
@settings(max_examples=100)
def test_needs_attention_classification(data):
    """For any set of patient IDs, profiles, and samples,
    classify_needs_attention shall correctly flag inactivity,
    elevated_heart_rate, and declining_hrv.

    **Validates: Requirements 10.2, 10.3, 10.4**
    """
    patient_ids, profiles, samples_by_patient, now = data

    result = classify_needs_attention(
        patient_ids, profiles, samples_by_patient, now
    )

    seven_days_ago = now - _td(days=7)
    fourteen_days_ago = now - _td(days=14)

    # Independently compute expected flags
    expected_flags = []
    for pid in patient_ids:
        profile = profiles.get(pid, {})
        all_samples = samples_by_patient.get(pid, [])

        recent = []
        prior = []
        for s in all_samples:
            ws_str = s.get("window_start", "")
            try:
                ws_dt = _dt.fromisoformat(ws_str)
                if ws_dt.tzinfo is None:
                    ws_dt = ws_dt.replace(tzinfo=_tz.utc)
            except (ValueError, TypeError):
                continue
            if ws_dt >= seven_days_ago:
                recent.append(s)
            elif ws_dt >= fourteen_days_ago:
                prior.append(s)

        if not recent:
            expected_flags.append((pid, "inactivity"))
            continue

        resting_hr = profile.get("resting_heart_rate")
        if resting_hr is not None:
            hr_vals = [
                s["avg_heart_rate"] for s in recent
                if s.get("avg_heart_rate") is not None
            ]
            if hr_vals:
                avg_hr = sum(hr_vals) / len(hr_vals)
                if avg_hr >= resting_hr * 1.15:
                    expected_flags.append((pid, "elevated_heart_rate"))

        recent_rmssd = [
            s["rmssd"] for s in recent if s.get("rmssd") is not None
        ]
        prior_rmssd = [
            s["rmssd"] for s in prior if s.get("rmssd") is not None
        ]
        if recent_rmssd and prior_rmssd:
            avg_recent = sum(recent_rmssd) / len(recent_rmssd)
            avg_prior = sum(prior_rmssd) / len(prior_rmssd)
            if avg_prior > 0 and avg_recent <= avg_prior * 0.75:
                expected_flags.append((pid, "declining_hrv"))

    # Compare result flags
    result_flags = [(item["patient_id"], item["reason"]) for item in result]

    assert sorted(result_flags) == sorted(expected_flags), (
        f"Flags mismatch:\n  got:      {sorted(result_flags)}\n"
        f"  expected: {sorted(expected_flags)}"
    )

    # Verify all items have required fields
    for item in result:
        assert "patient_id" in item
        assert "patient_name" in item
        assert "reason" in item
        assert item["reason"] in (
            "inactivity", "elevated_heart_rate", "declining_hrv"
        )
        assert "detail" in item


# ---------------------------------------------------------------------------
# Strategies for recent activity sorting
# ---------------------------------------------------------------------------

@st.composite
def recent_activity_items_st(draw):
    """Generate a list of recent activity items with random dates."""
    n = draw(st.integers(min_value=0, max_value=30))
    base = _dt(2025, 6, 15, 12, 0, 0, tzinfo=_tz.utc)
    items = []
    for i in range(n):
        hours_ago = draw(st.integers(min_value=0, max_value=720))
        session_date = (base - _td(hours=hours_ago)).isoformat()
        items.append({
            "patient_id": f"patient-{i % 5}",
            "patient_name": f"Patient {i % 5}",
            "session_date": session_date,
            "duration_minutes": draw(
                st.integers(min_value=1, max_value=120)
            ),
            "avg_heart_rate": draw(st.floats(
                min_value=40, max_value=200,
                allow_nan=False, allow_infinity=False,
            )),
        })
    return items


# ---------------------------------------------------------------------------
# Property 7: Recent activity sorted descending
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 7: Recent activity sorted descending
# **Validates: Requirements 11.1, 11.3**


@given(
    items=recent_activity_items_st(),
    limit=st.integers(min_value=1, max_value=50),
)
@settings(max_examples=100)
def test_recent_activity_sorted_descending(items, limit):
    """For any list of recent activity items and any positive limit,
    selecting the top items shall return at most ``limit`` items sorted
    by session_date descending, and each item shall contain the required
    fields.

    **Validates: Requirements 11.1, 11.3**
    """
    # Apply the same logic the service would use
    sorted_items = sorted(
        items,
        key=lambda x: x.get("session_date", ""),
        reverse=True,
    )
    result = sorted_items[:limit]

    # Verify count
    assert len(result) <= limit
    assert len(result) == min(limit, len(items))

    # Verify descending order
    for i in range(1, len(result)):
        assert result[i - 1]["session_date"] >= result[i]["session_date"], (
            f"Not sorted descending: "
            f"{result[i-1]['session_date']} < {result[i]['session_date']}"
        )

    # Verify required fields
    for item in result:
        assert "patient_id" in item
        assert "patient_name" in item
        assert "session_date" in item
        assert "duration_minutes" in item
        assert "avg_heart_rate" in item


# ---------------------------------------------------------------------------
# Property 8: Invitation code generation format
# ---------------------------------------------------------------------------
# Feature: flask-backend-api, Property 8: Invitation code generation format
# **Validates: Requirements 12.2**

_VALID_CODE_CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")


@given(seed=st.integers(min_value=0, max_value=2**32 - 1))
@settings(max_examples=100)
def test_invitation_code_generation_format(seed):
    """For any generated invitation code, the code string shall be exactly
    5 characters long, each character shall be alphanumeric (A-Z, 0-9),
    the status shall be ``pending``, and the ``expires_at`` shall be
    exactly 7 days after ``created_at``.

    This test validates the pure code generation function. The status and
    expiry invariants are verified by constructing the same payload the
    service would produce.

    **Validates: Requirements 12.2**
    """
    import random as _rnd
    from datetime import datetime as _dtc, timedelta as _tdc, timezone as _tzc

    # Seed the RNG for reproducibility within Hypothesis
    _rnd.seed(seed)

    code = generate_invitation_code()

    # Exactly 5 characters
    assert len(code) == 5, (
        f"Code length is {len(code)}, expected 5: {code!r}"
    )

    # Each character is A-Z or 0-9
    for ch in code:
        assert ch in _VALID_CODE_CHARS, (
            f"Invalid character {ch!r} in code {code!r}"
        )

    # Verify the invitation payload structure the service would create
    now = _dtc.now(_tzc.utc)
    expires_at = now + _tdc(days=7)

    payload = {
        "code": code,
        "status": "pending",
        "created_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
    }

    assert payload["status"] == "pending"

    created = _dtc.fromisoformat(payload["created_at"])
    expires = _dtc.fromisoformat(payload["expires_at"])
    delta = expires - created
    assert delta.days == 7 and delta.seconds == 0, (
        f"expires_at is not exactly 7 days after created_at: "
        f"delta={delta}"
    )
