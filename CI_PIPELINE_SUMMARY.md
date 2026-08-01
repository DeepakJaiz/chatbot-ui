# CI/CD Pipeline Walkthrough

## Overview
This GitHub Actions pipeline automates quality checks, containerization, and deployment for a Next.js application. It runs on pushes to `main`, pull requests, and manual triggers.

## Jobs & Flow

### 1. `validate-code` (Lint)
**Purpose:** Catches code style and potential errors early.
- Uses Node.js 22 to run `npm ci` and `npm run lint`.
- **Exit strategy:** Fails if linting errors are found, blocking subsequent jobs.

### 2. `test-unit` (Unit Tests)
**Purpose:** Validates business logic.
- Runs `npm test` and uploads test reports and build artifacts (`dist/`, `reports/`) for debugging.
- **Note:** Uses `always()` condition to upload artifacts even if tests fail.

### 3. `build-push` (Build, Scan & Push)
**Purpose:** Creates a production-ready container image.
- **Dependencies:** Requires both `validate-code` and `test-unit` to pass.
- Builds a Docker image with BuildKit caching, tags it with the commit SHA and `latest`.
- **Security:** Scans the image with Trivy for HIGH/CRITICAL vulnerabilities; fails the pipeline if found.
- Pushes to GitHub Container Registry (GHCR).

### 4. `deploy-ec2` (Deploy to Production)
**Purpose:** Deploys the new image to the EC2 instance.
- **Dependencies:** Requires successful `build-push`.
- **Environment:** Protected by `production` environment (may require manual approval).
- **Deployment process (on EC2):**
  1. Logs into GHCR, pulls the new image.
  2. Tags the current running image as `:rollback` for safety.
  3. Stops and removes the old container, then runs the new one with resource limits (`512m` RAM, `0.5` CPU), non-root user, and health check.
  4. Performs 10 health-check attempts against `/api/health`. On failure, stops the container and rolls back to the previous image.
  5. Cleans up old Docker images.

## Connectivity & Environment
- **Environment variables:** Consistent settings (Node version, image name, ports) are defined at the workflow level.
- **Concurrency:** Pull request runs are cancelled when new commits are pushed to avoid redundant runs.
- **Secrets required:** `EC2_HOST`, `EC2_SSH_KEY` for deployment; `GITHUB_TOKEN` for GHCR login.

## Key Considerations
- **Failure handling:** Each job is isolated; a failure in any step stops subsequent jobs (except artifact uploads in test).
- **Rollback mechanism:** Automatic, but relies on the previous image being available. Manual intervention may be needed for complete recovery.
- **Security:** Image scanning is a hard gate; deployment requires protected environment approval.

This pipeline enforces quality and security but requires careful management of production secrets and environments.