# CI/CD Pipeline Walkthrough

## Overview
This pipeline runs on every push to `main` and all pull requests targeting `main`. It follows a sequential flow: quality → testing → building → deployment.

## Jobs Breakdown

### 1. Validate: Code Quality
**Purpose:** Enforces consistent code style and catches syntax errors early.
**What happens:**
- Installs `black`, `isort`, and `flake8`
- Checks formatting (`black --check .`), import ordering (`isort --check-only .`), and linting (`flake8 .`)
- **Must pass** before any tests run

### 2. Test: Unit Tests
**Purpose:** Validates application logic works as expected.
**Depends on:** `validate-code`
**What happens:**
- Runs `pytest` with coverage tracking
- Generates XML reports (JUnit and coverage)
- Uploads test results and coverage as artifacts
- **Critical for merge** – all tests must pass

### 3. Build Docker Image
**Purpose:** Creates a versioned container image for deployment.
**Depends on:** Both validation and tests
**Condition:** Only runs on pushes to main (not PRs), skipped if commit contains `[skip ci]`
**What happens:**
- Builds image using Docker Buildx with layer caching
- Pushes to GitHub Container Registry (ghcr.io) with:
  - SHA-based tag (immutable)
  - `latest` tag (mutable)
- Runs Trivy security scan for CRITICAL/HIGH vulnerabilities
- Uploads security scan results to GitHub Security tab

### 4. Deploy to EC2
**Purpose:** Deploys the new container to production with zero downtime.
**Depends on:** Successful Docker build
**Condition:** Same as build (main pushes only)
**Requires:** `production` environment approval
**What happens:**
1. **Pulls** the new image on EC2 server
2. **Stops & removes** old container (if exists)
3. **Starts new container** with:
   - Health check endpoint (`/health`)
   - Restart policy (`unless-stopped`)
   - Port mapping (7777 → 8000)
4. **Runs health checks** for up to 30 seconds (10 attempts)
5. **Success path:** Renames container to production name
6. **Failure path:** Rolls back and exits with error
7. **Cleanup:** Prunes unused Docker images

## Concurrency Control
- Workflow group based on branch – only one run per branch at a time
- In-progress runs are cancelled when new ones start

## Required Secrets
- `EC2_HOST` – Production server hostname
- `EC2_USER` – SSH username for deployment
- `EC2_SSH_KEY` – Private SSH key for server access

## Key Design Decisions
1. **Fail fast:** Code quality failures stop the entire pipeline
2. **Artifact retention:** Test results and security scans are preserved for debugging
3. **Health check loop:** 10 retries with 3-second intervals ensures stability
4. **Image pruning:** Keeps server clean by removing old images automatically