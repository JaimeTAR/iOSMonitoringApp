"""Clinician service — patient list with trends, aggregates, and helpers.

Provides business logic for clinician-facing endpoints. Pure static
functions (compute_trend, compute_aggregates, filter_active_relationships)
are independently testable without Supabase.
"""

import random
import string
from datetime import datetime, timedelta, timezone

from app.errors import error_response
from app.models.validators import validate_heart_rate
from app.services.supabase_client import get_supabase


def compute_trend(recent_samples, prior_samples):
    """Compute health trend by comparing recent vs prior sample averages.

    Args:
        recent_samples: List of sample dicts (recent 7-day period).
        prior_samples: List of sample dicts (prior 7-day period).

    Returns:
        One of ``'improving'``, ``'stable'``, or ``'declining'``.

    Logic:
        - If either period is empty, return ``'stable'``.
        - improving: HR decreased ≥5% (change ≤ -0.05) OR
          RMSSD increased ≥10% (change ≥ 0.10).
        - declining: HR increased ≥10% (change ≥ 0.10) OR
          RMSSD decreased ≥15% (change ≤ -0.15).
        - stable: otherwise.
    """
    if not recent_samples or not prior_samples:
        return "stable"

    recent_agg = compute_aggregates(recent_samples)
    prior_agg = compute_aggregates(prior_samples)

    recent_hr = recent_agg["avg_heart_rate"]
    prior_hr = prior_agg["avg_heart_rate"]
    recent_rmssd = recent_agg["avg_rmssd"]
    prior_rmssd = prior_agg["avg_rmssd"]

    # Compute percentage changes (guard against zero division)
    if prior_hr and prior_hr != 0:
        hr_change = (recent_hr - prior_hr) / prior_hr
    else:
        hr_change = 0.0

    if prior_rmssd and prior_rmssd != 0:
        rmssd_change = (recent_rmssd - prior_rmssd) / prior_rmssd
    else:
        rmssd_change = 0.0

    # Check improving first
    if hr_change <= -0.05 or rmssd_change >= 0.10:
        return "improving"

    # Check declining
    if hr_change >= 0.10 or rmssd_change <= -0.15:
        return "declining"

    return "stable"


def compute_aggregates(samples):
    """Compute average heart rate and average RMSSD from a list of samples.

    Args:
        samples: List of sample dicts with ``avg_heart_rate`` and
            optional ``rmssd`` keys.

    Returns:
        Dict with ``avg_heart_rate`` and ``avg_rmssd``. Values are
        ``None`` when no valid data is available.
    """
    if not samples:
        return {"avg_heart_rate": None, "avg_rmssd": None}

    hr_values = [
        s["avg_heart_rate"]
        for s in samples
        if s.get("avg_heart_rate") is not None
    ]
    rmssd_values = [
        s["rmssd"]
        for s in samples
        if s.get("rmssd") is not None
    ]

    avg_hr = sum(hr_values) / len(hr_values) if hr_values else None
    avg_rmssd = sum(rmssd_values) / len(rmssd_values) if rmssd_values else None

    return {"avg_heart_rate": avg_hr, "avg_rmssd": avg_rmssd}


def filter_active_relationships(relationships):
    """Filter relationships to only active ones.

    Args:
        relationships: List of relationship dicts.

    Returns:
        List of relationships where status == "activo" and
        end_date is None.
    """
    return [
        r for r in relationships
        if r.get("status") == "activo" and r.get("end_date") is None
    ]


def get_patients(clinician_id):
    """Fetch active patients for a clinician with 7-day trends.

    Queries active relationships (status=activo, end_date=None),
    fetches patient profiles and 14-day samples, then computes
    7-day aggregates and health trends.

    Args:
        clinician_id: The clinician's user ID.

    Returns:
        A list of patient summary dicts.
    """
    sb = get_supabase()

    # Fetch active relationships
    rel_result = (
        sb.table("clinician_patients")
        .select("*")
        .eq("clinician_id", clinician_id)
        .eq("status", "activo")
        .is_("end_date", "null")
        .execute()
    )

    active_rels = rel_result.data or []
    if not active_rels:
        return []

    patient_ids = [r["patient_id"] for r in active_rels]

    # Fetch profiles for all active patients
    profiles_result = (
        sb.table("user_profile")
        .select("*")
        .in_("user_id", patient_ids)
        .execute()
    )
    profiles_by_id = {
        p["user_id"]: p for p in (profiles_result.data or [])
    }

    # Fetch 14-day samples for trend computation
    now = datetime.now(timezone.utc)
    fourteen_days_ago = now - timedelta(days=14)
    seven_days_ago = now - timedelta(days=7)

    samples_result = (
        sb.table("physiological_samples")
        .select("*")
        .in_("user_id", patient_ids)
        .gte("window_start", fourteen_days_ago.isoformat())
        .execute()
    )
    all_samples = samples_result.data or []

    # Group samples by patient
    samples_by_patient = {}
    for s in all_samples:
        pid = s["user_id"]
        samples_by_patient.setdefault(pid, []).append(s)

    # Build patient summaries
    summaries = []
    for pid in patient_ids:
        profile = profiles_by_id.get(pid, {})
        patient_samples = samples_by_patient.get(pid, [])

        # Split into recent (0-7 days) and prior (7-14 days)
        recent = []
        prior = []
        for s in patient_samples:
            ws = s.get("window_start", "")
            if isinstance(ws, str):
                try:
                    ws_dt = datetime.fromisoformat(ws)
                    if ws_dt.tzinfo is None:
                        ws_dt = ws_dt.replace(tzinfo=timezone.utc)
                except (ValueError, TypeError):
                    continue
            else:
                ws_dt = ws

            if ws_dt >= seven_days_ago:
                recent.append(s)
            else:
                prior.append(s)

        agg = compute_aggregates(recent)
        trend = compute_trend(recent, prior)

        # Determine last active date
        last_active = None
        if patient_samples:
            dates = []
            for s in patient_samples:
                ws = s.get("window_start")
                if ws:
                    dates.append(ws)
            if dates:
                last_active = max(dates)

        summaries.append({
            "id": pid,
            "name": profile.get("name"),
            "last_active_date": last_active,
            "avg_heart_rate_7d": agg["avg_heart_rate"],
            "avg_rmssd_7d": agg["avg_rmssd"],
            "trend": trend,
        })

    return summaries


def group_into_sessions(sorted_samples, gap_seconds=120):
    """Group consecutive samples into sessions using a gap threshold.

    Args:
        sorted_samples: List of sample dicts sorted by ``window_start``
            ascending. Each sample must have a ``window_start`` key
            containing an ISO 8601 string.
        gap_seconds: Maximum gap in seconds between consecutive samples
            within the same session. Defaults to 120 (2 minutes).

    Returns:
        A list of lists, where each inner list is a session of
        consecutive samples.
    """
    if not sorted_samples:
        return []

    sessions = []
    current_session = [sorted_samples[0]]

    for i in range(1, len(sorted_samples)):
        prev_ws = sorted_samples[i - 1].get("window_start", "")
        curr_ws = sorted_samples[i].get("window_start", "")

        try:
            prev_dt = datetime.fromisoformat(prev_ws)
            curr_dt = datetime.fromisoformat(curr_ws)
        except (ValueError, TypeError):
            # If we can't parse, start a new session
            sessions.append(current_session)
            current_session = [sorted_samples[i]]
            continue

        gap = (curr_dt - prev_dt).total_seconds()

        if gap <= gap_seconds:
            current_session.append(sorted_samples[i])
        else:
            sessions.append(current_session)
            current_session = [sorted_samples[i]]

    sessions.append(current_session)
    return sessions


def build_overview(samples):
    """Compute a 7-day overview from a list of samples.

    Args:
        samples: List of sample dicts with ``window_start``,
            ``avg_heart_rate``, ``rmssd``, ``sdnn`` keys.

    Returns:
        Dict with ``avg_heart_rate_7d``, ``avg_rmssd_7d``,
        ``avg_sdnn_7d``, ``session_count_7d``, ``total_minutes_7d``,
        ``daily_heart_rates``, and ``daily_rmssd``.
        Returns None if samples is empty.
    """
    if not samples:
        return None

    # Sort samples by window_start for session grouping
    sorted_samples = sorted(samples, key=lambda s: s.get("window_start", ""))

    # Compute averages
    hr_values = [
        s["avg_heart_rate"] for s in samples
        if s.get("avg_heart_rate") is not None
    ]
    rmssd_values = [
        s["rmssd"] for s in samples
        if s.get("rmssd") is not None
    ]
    sdnn_values = [
        s["sdnn"] for s in samples
        if s.get("sdnn") is not None
    ]

    avg_hr = sum(hr_values) / len(hr_values) if hr_values else None
    avg_rmssd = (
        sum(rmssd_values) / len(rmssd_values) if rmssd_values else None
    )
    avg_sdnn = (
        sum(sdnn_values) / len(sdnn_values) if sdnn_values else None
    )

    # Group into sessions
    sessions = group_into_sessions(sorted_samples)
    session_count = len(sessions)
    total_minutes = len(samples)  # Each sample is a 1-minute window

    # Build daily series
    daily_hr = {}
    daily_rmssd_map = {}
    for s in samples:
        ws = s.get("window_start", "")
        try:
            dt = datetime.fromisoformat(ws)
            date_key = dt.date().isoformat()
        except (ValueError, TypeError):
            continue

        if s.get("avg_heart_rate") is not None:
            daily_hr.setdefault(date_key, []).append(s["avg_heart_rate"])
        if s.get("rmssd") is not None:
            daily_rmssd_map.setdefault(date_key, []).append(s["rmssd"])

    daily_heart_rates = sorted(
        [
            {"date": d, "value": sum(vals) / len(vals)}
            for d, vals in daily_hr.items()
        ],
        key=lambda x: x["date"],
    )
    daily_rmssd = sorted(
        [
            {"date": d, "value": sum(vals) / len(vals)}
            for d, vals in daily_rmssd_map.items()
        ],
        key=lambda x: x["date"],
    )

    return {
        "avg_heart_rate_7d": avg_hr,
        "avg_rmssd_7d": avg_rmssd,
        "avg_sdnn_7d": avg_sdnn,
        "session_count_7d": session_count,
        "total_minutes_7d": total_minutes,
        "daily_heart_rates": daily_heart_rates,
        "daily_rmssd": daily_rmssd,
    }


def get_patient_detail(patient_id):
    """Fetch patient profile and 7-day overview.

    Args:
        patient_id: The patient's user ID.

    Returns:
        Dict with ``profile`` and ``overview`` keys. Overview is None
        if no samples exist in the last 7 days.
    """
    sb = get_supabase()

    # Fetch profile
    profile_result = (
        sb.table("user_profile")
        .select("*")
        .eq("user_id", patient_id)
        .execute()
    )
    profile = (
        profile_result.data[0] if profile_result.data else {}
    )

    # Fetch 7-day samples
    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)

    samples_result = (
        sb.table("physiological_samples")
        .select("*")
        .eq("user_id", patient_id)
        .gte("window_start", seven_days_ago.isoformat())
        .order("window_start", desc=False)
        .execute()
    )
    samples = samples_result.data or []

    overview = build_overview(samples)

    return {
        "profile": profile,
        "overview": overview,
    }


def get_patient_samples(patient_id, from_date, to_date):
    """Fetch patient samples within a date range.

    Args:
        patient_id: The patient's user ID.
        from_date: Start of range (ISO 8601 string).
        to_date: End of range (ISO 8601 string).

    Returns:
        List of sample dicts ordered by window_start ascending.
    """
    sb = get_supabase()

    result = (
        sb.table("physiological_samples")
        .select("*")
        .eq("user_id", patient_id)
        .gte("window_start", from_date)
        .lte("window_start", to_date)
        .order("window_start", desc=False)
        .execute()
    )

    return result.data or []


# -------------------------------------------------------------------
# Dashboard stats, needs attention, recent activity (Task 12)
# -------------------------------------------------------------------


def compute_dashboard_stats(relationships, samples, invitations, now):
    """Compute dashboard statistics from raw data (pure function).

    Args:
        relationships: List of clinician-patient relationship dicts.
        samples: List of physiological sample dicts (all patients).
        invitations: List of invitation code dicts.
        now: Current datetime (timezone-aware).

    Returns:
        Dict with ``total_active_patients``, ``patients_active_today``,
        and ``pending_invitations``.
    """
    # Count active relationships (status=activo, end_date=None)
    active_rels = filter_active_relationships(relationships)
    total_active = len(active_rels)
    active_patient_ids = {r["patient_id"] for r in active_rels}

    # Count patients active in last 24h
    twenty_four_hours_ago = now - timedelta(hours=24)
    active_today_ids = set()
    for s in samples:
        pid = s.get("user_id")
        if pid not in active_patient_ids:
            continue
        ws = s.get("window_start", "")
        if isinstance(ws, str):
            try:
                ws_dt = datetime.fromisoformat(ws)
                if ws_dt.tzinfo is None:
                    ws_dt = ws_dt.replace(tzinfo=timezone.utc)
            except (ValueError, TypeError):
                continue
        else:
            ws_dt = ws
        if ws_dt >= twenty_four_hours_ago:
            active_today_ids.add(pid)

    # Count pending invitations
    pending = sum(
        1 for inv in invitations if inv.get("status") == "pending"
    )

    return {
        "total_active_patients": total_active,
        "patients_active_today": len(active_today_ids),
        "pending_invitations": pending,
    }


def classify_needs_attention(patient_ids, profiles, samples_by_patient, now):
    """Classify patients needing attention (pure function).

    Args:
        patient_ids: List of active patient IDs.
        profiles: Dict mapping patient_id to profile dict.
        samples_by_patient: Dict mapping patient_id to list of samples.
        now: Current datetime (timezone-aware).

    Returns:
        List of attention item dicts with ``patient_id``,
        ``patient_name``, ``reason``, and ``detail``.
    """
    seven_days_ago = now - timedelta(days=7)
    fourteen_days_ago = now - timedelta(days=14)
    items = []

    for pid in patient_ids:
        profile = profiles.get(pid, {})
        patient_name = profile.get("name", "Unknown")
        all_samples = samples_by_patient.get(pid, [])

        # Parse sample timestamps and split into recent / prior
        recent_samples = []
        prior_samples = []
        latest_ws = None

        for s in all_samples:
            ws = s.get("window_start", "")
            if isinstance(ws, str):
                try:
                    ws_dt = datetime.fromisoformat(ws)
                    if ws_dt.tzinfo is None:
                        ws_dt = ws_dt.replace(tzinfo=timezone.utc)
                except (ValueError, TypeError):
                    continue
            else:
                ws_dt = ws

            if latest_ws is None or ws_dt > latest_ws:
                latest_ws = ws_dt

            if ws_dt >= seven_days_ago:
                recent_samples.append(s)
            elif ws_dt >= fourteen_days_ago:
                prior_samples.append(s)

        # 1. Inactivity: no samples in last 7 days
        if not recent_samples:
            if latest_ws is not None:
                days_since = (now - latest_ws).days
            else:
                days_since = None
            detail = (
                f"No activity for {days_since} days"
                if days_since is not None
                else "No recorded activity"
            )
            items.append({
                "patient_id": pid,
                "patient_name": patient_name,
                "reason": "inactivity",
                "detail": detail,
            })
            continue  # skip other checks if inactive

        # 2. Elevated heart rate: 7-day avg HR >= resting * 1.15
        resting_hr = profile.get("resting_heart_rate")
        if resting_hr is not None:
            hr_values = [
                s["avg_heart_rate"] for s in recent_samples
                if s.get("avg_heart_rate") is not None
            ]
            if hr_values:
                avg_hr = sum(hr_values) / len(hr_values)
                if avg_hr >= resting_hr * 1.15:
                    items.append({
                        "patient_id": pid,
                        "patient_name": patient_name,
                        "reason": "elevated_heart_rate",
                        "detail": (
                            f"7-day avg HR {avg_hr:.1f} bpm "
                            f"exceeds resting {resting_hr:.1f} bpm "
                            f"by ≥15%"
                        ),
                    })

        # 3. Declining HRV: recent 7-day avg RMSSD <= prior * 0.75
        recent_rmssd = [
            s["rmssd"] for s in recent_samples
            if s.get("rmssd") is not None
        ]
        prior_rmssd = [
            s["rmssd"] for s in prior_samples
            if s.get("rmssd") is not None
        ]
        if recent_rmssd and prior_rmssd:
            avg_recent = sum(recent_rmssd) / len(recent_rmssd)
            avg_prior = sum(prior_rmssd) / len(prior_rmssd)
            if avg_prior > 0 and avg_recent <= avg_prior * 0.75:
                items.append({
                    "patient_id": pid,
                    "patient_name": patient_name,
                    "reason": "declining_hrv",
                    "detail": (
                        f"7-day avg RMSSD {avg_recent:.1f} ms "
                        f"dropped ≥25% from prior {avg_prior:.1f} ms"
                    ),
                })

    return items


def get_dashboard_stats(clinician_id):
    """Fetch dashboard statistics for a clinician.

    Args:
        clinician_id: The clinician's user ID.

    Returns:
        Dict with ``total_active_patients``, ``patients_active_today``,
        and ``pending_invitations``.
    """
    sb = get_supabase()
    now = datetime.now(timezone.utc)

    # Fetch relationships
    rel_result = (
        sb.table("clinician_patients")
        .select("*")
        .eq("clinician_id", clinician_id)
        .execute()
    )
    relationships = rel_result.data or []

    # Fetch samples for active patients in last 24h
    active_rels = filter_active_relationships(relationships)
    patient_ids = [r["patient_id"] for r in active_rels]

    samples = []
    if patient_ids:
        twenty_four_hours_ago = now - timedelta(hours=24)
        samples_result = (
            sb.table("physiological_samples")
            .select("*")
            .in_("user_id", patient_ids)
            .gte("window_start", twenty_four_hours_ago.isoformat())
            .execute()
        )
        samples = samples_result.data or []

    # Fetch invitations
    inv_result = (
        sb.table("clinician_invitation_codes")
        .select("*")
        .eq("clinician_id", clinician_id)
        .execute()
    )
    invitations = inv_result.data or []

    return compute_dashboard_stats(relationships, samples, invitations, now)


def get_needs_attention(clinician_id):
    """Fetch patients needing attention for a clinician.

    Args:
        clinician_id: The clinician's user ID.

    Returns:
        List of attention item dicts.
    """
    sb = get_supabase()
    now = datetime.now(timezone.utc)

    # Fetch active relationships
    rel_result = (
        sb.table("clinician_patients")
        .select("*")
        .eq("clinician_id", clinician_id)
        .eq("status", "activo")
        .is_("end_date", "null")
        .execute()
    )
    active_rels = rel_result.data or []
    if not active_rels:
        return []

    patient_ids = [r["patient_id"] for r in active_rels]

    # Fetch profiles
    profiles_result = (
        sb.table("user_profile")
        .select("*")
        .in_("user_id", patient_ids)
        .execute()
    )
    profiles = {
        p["user_id"]: p for p in (profiles_result.data or [])
    }

    # Fetch 14-day samples for all patients
    fourteen_days_ago = now - timedelta(days=14)
    samples_result = (
        sb.table("physiological_samples")
        .select("*")
        .in_("user_id", patient_ids)
        .gte("window_start", fourteen_days_ago.isoformat())
        .execute()
    )
    all_samples = samples_result.data or []

    samples_by_patient = {}
    for s in all_samples:
        pid = s["user_id"]
        samples_by_patient.setdefault(pid, []).append(s)

    return classify_needs_attention(
        patient_ids, profiles, samples_by_patient, now
    )


def get_recent_activity(clinician_id, limit=10):
    """Fetch recent monitoring sessions across all active patients.

    Args:
        clinician_id: The clinician's user ID.
        limit: Maximum number of sessions to return (default 10).

    Returns:
        List of recent activity item dicts sorted by session_date
        descending.
    """
    sb = get_supabase()

    # Fetch active relationships
    rel_result = (
        sb.table("clinician_patients")
        .select("*")
        .eq("clinician_id", clinician_id)
        .eq("status", "activo")
        .is_("end_date", "null")
        .execute()
    )
    active_rels = rel_result.data or []
    if not active_rels:
        return []

    patient_ids = [r["patient_id"] for r in active_rels]

    # Fetch profiles
    profiles_result = (
        sb.table("user_profile")
        .select("*")
        .in_("user_id", patient_ids)
        .execute()
    )
    profiles = {
        p["user_id"]: p for p in (profiles_result.data or [])
    }

    # Fetch recent samples ordered by window_start desc
    samples_result = (
        sb.table("physiological_samples")
        .select("*")
        .in_("user_id", patient_ids)
        .order("window_start", desc=True)
        .execute()
    )
    all_samples = samples_result.data or []

    if not all_samples:
        return []

    # Group samples by patient, then into sessions
    samples_by_patient = {}
    for s in all_samples:
        pid = s["user_id"]
        samples_by_patient.setdefault(pid, []).append(s)

    # Build session list across all patients
    all_sessions = []
    for pid, patient_samples in samples_by_patient.items():
        # Sort ascending for session grouping
        sorted_samples = sorted(
            patient_samples,
            key=lambda s: s.get("window_start", ""),
        )
        sessions = group_into_sessions(sorted_samples)
        profile = profiles.get(pid, {})

        for session in sessions:
            if not session:
                continue
            # Session date is the first sample's window_start
            session_date = session[0].get("window_start")
            duration_minutes = len(session)
            hr_values = [
                s["avg_heart_rate"] for s in session
                if s.get("avg_heart_rate") is not None
            ]
            avg_hr = (
                sum(hr_values) / len(hr_values) if hr_values else None
            )
            all_sessions.append({
                "patient_id": pid,
                "patient_name": profile.get("name"),
                "session_date": session_date,
                "duration_minutes": duration_minutes,
                "avg_heart_rate": avg_hr,
            })

    # Sort by session_date descending and limit
    all_sessions.sort(
        key=lambda x: x.get("session_date", ""),
        reverse=True,
    )

    return all_sessions[:limit]


# -------------------------------------------------------------------
# Invitation management (Task 13)
# -------------------------------------------------------------------


def generate_invitation_code():
    """Generate a random 5-character alphanumeric code (A-Z, 0-9).

    Returns:
        A 5-character uppercase alphanumeric string.
    """
    return "".join(
        random.choices(string.ascii_uppercase + string.digits, k=5)
    )


def get_invitations(clinician_id):
    """Fetch all invitation codes for a clinician.

    Args:
        clinician_id: The clinician's user ID.

    Returns:
        List of invitation code dicts ordered by created_at descending.
    """
    sb = get_supabase()

    result = (
        sb.table("clinician_invitation_codes")
        .select("*")
        .eq("clinician_id", clinician_id)
        .order("created_at", desc=True)
        .execute()
    )

    return result.data or []


def generate_invitation(clinician_id):
    """Generate a new invitation code for a clinician.

    Creates a 5-char alphanumeric code with status ``pending`` and
    an expiration date 7 days from now.

    Args:
        clinician_id: The clinician's user ID.

    Returns:
        The created invitation code dict.
    """
    sb = get_supabase()

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=7)
    code = generate_invitation_code()

    result = (
        sb.table("clinician_invitation_codes")
        .insert({
            "clinician_id": clinician_id,
            "code": code,
            "status": "pending",
            "created_at": now.isoformat(),
            "expires_at": expires_at.isoformat(),
        })
        .execute()
    )

    return result.data[0] if result.data else {}


def revoke_invitation(clinician_id, code_id):
    """Revoke an invitation code.

    Args:
        clinician_id: The clinician's user ID.
        code_id: The invitation code record ID.

    Returns:
        The updated invitation code dict on success, or a Flask
        error response on failure.
    """
    sb = get_supabase()

    # Fetch the invitation code
    result = (
        sb.table("clinician_invitation_codes")
        .select("*")
        .eq("id", code_id)
        .execute()
    )

    if not result.data:
        return error_response(
            "not_found", "Invitation code not found", 404
        )

    invitation = result.data[0]

    # Check ownership
    if invitation.get("clinician_id") != clinician_id:
        return error_response(
            "forbidden",
            "You do not have permission to revoke this code",
            403,
        )

    # Check status is pending
    if invitation.get("status") != "pending":
        return error_response(
            "code_not_revocable",
            "Only pending invitation codes can be revoked",
            400,
        )

    # Update status to revoked
    update_result = (
        sb.table("clinician_invitation_codes")
        .update({"status": "revoked"})
        .eq("id", code_id)
        .execute()
    )

    return update_result.data[0] if update_result.data else {}


# -------------------------------------------------------------------
# Resting HR update and clinician profile (Task 14)
# -------------------------------------------------------------------


def update_resting_hr(clinician_id, patient_id, bpm):
    """Update a patient's resting heart rate baseline.

    Args:
        clinician_id: The clinician's user ID.
        patient_id: The patient's user ID.
        bpm: The new resting heart rate value.

    Returns:
        The updated user_profile dict on success, or a Flask
        error response on failure.
    """
    if not validate_heart_rate(bpm):
        return error_response(
            "invalid_heart_rate",
            "Heart rate must be between 30 and 220 bpm",
            400,
        )

    sb = get_supabase()

    # Check clinician-patient relationship exists
    rel_result = (
        sb.table("clinician_patients")
        .select("*")
        .eq("clinician_id", clinician_id)
        .eq("patient_id", patient_id)
        .eq("status", "activo")
        .is_("end_date", "null")
        .execute()
    )

    if not rel_result.data:
        return error_response(
            "forbidden",
            "You do not have permission to update this patient",
            403,
        )

    # Update resting_heart_rate in user_profile
    update_result = (
        sb.table("user_profile")
        .update({"resting_heart_rate": bpm})
        .eq("user_id", patient_id)
        .execute()
    )

    return update_result.data[0] if update_result.data else {}


def get_profile(user_id):
    """Fetch a user profile by user ID.

    Args:
        user_id: The user's ID.

    Returns:
        The user_profile dict on success, or a Flask error response
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
