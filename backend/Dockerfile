FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV SUPABASE_URL=""
ENV SUPABASE_SERVICE_KEY=""
ENV SUPABASE_JWT_SECRET=""
ENV FLASK_ENV=""

EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:create_app('production')"]
