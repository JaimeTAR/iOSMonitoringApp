# MonitoringApp [Test]

[![CI](https://github.com/JaimeTAR/iOSMonitoringApp/actions/workflows/ci.yml/badge.svg)](https://github.com/JaimeTAR/iOSMonitoringApp/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/JaimeTAR/iOSMonitoringApp/graph/badge.svg)](https://codecov.io/gh/JaimeTAR/iOSMonitoringApp)

A physiological monitoring platform with a SwiftUI iOS client and a Flask REST API backend, connected through a hosted Supabase instance.

## Project Structure

```
├── frontend/          # SwiftUI iOS app (Xcode project)
├── backend/           # Flask REST API
│   ├── app/           # Application code
│   │   ├── blueprints/   # Route handlers (auth, clinician, patient)
│   │   ├── middleware/    # JWT auth + role-based access
│   │   ├── models/        # Input validators
│   │   └── services/      # Business logic + Supabase client
│   ├── tests/         # Unit + property-based tests (Hypothesis)
│   ├── helm/          # Helm chart for Minikube
│   ├── Dockerfile
│   └── docker-compose.yml
└── .github/workflows/ # CI pipeline
```

## Prerequisites

- Python 3.12+
- Docker & Docker Compose
- Xcode 15+ (for the iOS frontend)
- A Supabase project with the database schema already set up

Optional for Kubernetes deployment:
- Minikube
- Helm

## Getting Started

### Backend — Local Dev

```bash
cd backend
cp .env.example .env
# Fill in your Supabase credentials in .env
pip install -r requirements.txt
flask --app "app:create_app('development')" run
```

API runs at `http://localhost:5000`.

### Backend — Docker Compose

```bash
cd backend
# Make sure .env is populated
docker-compose up --build
```

### Backend — Minikube + Helm

```bash
minikube start
eval $(minikube docker-env)

cd backend
docker build -t flask-api:latest .

# Create my-values.yaml with your credentials (see helm/flask-api/values.yaml)
helm install flask-api ./helm/flask-api -f ./helm/flask-api/my-values.yaml

minikube service flask-api --url
```

### Frontend

Open `frontend/MonitoringApp.xcodeproj` in Xcode and run on a simulator or device.

## Environment Variables

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Supabase service role key (admin) |
| `SUPABASE_JWT_SECRET` | Supabase JWT signing secret |
| `FLASK_ENV` | `development` or `production` |
| `SECRET_KEY` | Flask secret key for sessions |

Set these in `backend/.env` for local/Docker, or in `backend/helm/flask-api/my-values.yaml` for Kubernetes.

## Running Tests

```bash
cd backend
python -m pytest tests/ -v
python -m flake8 app/ tests/
```

76 tests total — 15 property-based (Hypothesis) + 61 unit tests.

## CI

GitHub Actions runs automatically on push and PR: linting, tests, and Docker image build. See `.github/workflows/ci.yml`.

## API Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/signup` | No | Register with invitation code |
| POST | `/auth/signin` | No | Sign in |
| POST | `/auth/signout` | Yes | Sign out |
| GET | `/auth/session` | Yes | Validate session |
| POST | `/auth/validate-code` | No | Check invitation code |
| GET | `/clinician/<id>/patients` | Clinician | Patient list with trends |
| GET | `/clinician/<id>/patients/<pid>` | Clinician | Patient detail |
| GET | `/clinician/<id>/patients/<pid>/samples` | Clinician | Samples by date range |
| GET | `/clinician/<id>/dashboard` | Clinician | Dashboard stats |
| GET | `/clinician/<id>/needs-attention` | Clinician | Attention flags |
| GET | `/clinician/<id>/recent-activity` | Clinician | Recent sessions |
| GET | `/clinician/<id>/invitations` | Clinician | List invitations |
| POST | `/clinician/<id>/invitations` | Clinician | Generate invitation |
| DELETE | `/clinician/<id>/invitations/<cid>` | Clinician | Revoke invitation |
| PUT | `/clinician/<id>/patients/<pid>/resting-hr` | Clinician | Update resting HR |
| GET | `/clinician/<id>/profile` | Clinician | Clinician profile |
| POST | `/patient/samples` | Patient | Upload samples |
| GET | `/patient/profile` | Patient | Get profile |
| PUT | `/patient/profile` | Patient | Update profile |
| GET | `/health` | No | Health check |
