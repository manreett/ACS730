# ACS730 midterm practice image. Task 1.
FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. Dedicated non-root user setup
RUN useradd --create-home --uid 10001 appuser

# 2. Layer caching: install dependencies first
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 3. Source code layer last
COPY app.py ./

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:app"]
