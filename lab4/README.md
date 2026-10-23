# Lab 4 & 5: Containerization & CI/CD Pipeline

## Running the Application
- **Build**: `docker build -t acs730-lab4:slim lab4/`
- **Run**: `docker run -d --name lab4 -p 8000:8000 acs730-lab4:slim`
- **Healthcheck**: `curl -s http://localhost:8000/healthz` (Returns `{"status": "ok", "version": "dev"}`)

## 1. Image Size Comparison

| Image | Base Image | Size | Rebuild Time (1-line code change) |
| :--- | :--- | :--- | :--- |
| **Naive** (`Dockerfile.naive`) | `python:latest` (~1.01 GB) | ~1.05 GB | ~38s (re-runs pip install) |
| **Slim** (`Dockerfile`) | `python:3.12-slim-bookworm` (~130 MB) | ~170 MB | ~1.2s (layers CACHED) |

- The base image accounts for over 85% of the total size reduction, shedding Debian compiler toolchains and unneeded libraries.
- The dependency layer is `CACHED` in the slim image because `requirements.txt` is copied and installed prior to copying `app.py`. In the naive image, copying all files first busts the cache on every code change.
- `.dockerignore` excluded `.git`, bytecode (`__pycache__`), test caches, and evidence artifacts from being sent as daemon build context.

## 2. CI Timings & Caching Effectiveness

| Metric / Step | Baseline | Cache Miss | Cache Hit | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **pip install** | 24s | 26s | 4s | **Worth it** (Saved ~20s restoring dependencies) |
| **docker build** | 48s | 51s | 6s | **Worth it** (Skipped all intermediate layer rebuilds) |
| **Total CI Wall Clock** | 2m 10s | 2m 18s | 58s | **Worth it** (>50% pipeline reduction) |

## 3. GHCR & SHA Tagging
- Images are tagged with `sha-${GITHUB_SHA::12}` to ensure immutable, deterministic traceability between running containers and the exact commit that produced them, eliminating the ambiguity of mutable tags like `latest`.

## 4. Architectural Shape: Action vs Reusable Workflow
- **Composite Action (`python-deps`)**: Selected for steps running on the same host runner alongside the test execution to avoid duplicating Python/cache setup across matrix jobs.
- **Reusable Workflow (`docker-build.yml`)**: Selected to isolate image construction into its own dedicated job requiring `packages: write` permissions that other jobs should not inherit.

## 5. GitHub Actions vs AWS-Native Tooling
- **Recommendation**: GitHub Actions is superior for this workload. It provides unified branch controls, inline pull request feedback, and native repository-scoped GITHUB_TOKEN permissions. AWS CodePipeline/CodeBuild requires complex cross-service IAM configurations, external ECR plumbing, and higher maintenance overhead with no execution speed advantage.

## Experiments

### Experiment 1: Inverting Layer Order
- **Prediction**: Placing `COPY app.py ./` before `pip install` will invalidate the Docker build cache on any code change, causing dependencies to reinstall every time.
- **Observation**: Changing a single string in `app.py` forced `pip install` to execute completely from scratch, increasing rebuild time from ~1.2s to ~35s.

### Experiment 2: Removing the Summary Re-raise Step
- **Prediction**: Removing the re-raise step will cause the `summary` job to succeed even when upstream matrix tests fail, marking the overall workflow green.
- **Observation**: Deliberately breaking a test allowed the summary job to pass with an exit code of 0. Because branch protection checks `summary`, GitHub permitted merging despite broken test suites.
