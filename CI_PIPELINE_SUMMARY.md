# Developer's Guide to the CI/CD Pipeline

This pipeline ensures code quality and automated deployment for the Next.js service. It triggers on pushes or pull requests to the `main` branch.

## Overview
- **Triggers**: Changes to `main` branch.
- **Environments**: Uses the `production` environment for deployment approval.
- **Concurrency**: Cancels in-progress workflows if a new one is triggered.

## Jobs Breakdown

### 1. Source Test Job
- **Purpose**: Catch code errors early.
- **Steps**: 
  - Checkout code and setup Node.js (v20).
  - Install dependencies with `npm ci`.
  - Run linting (`npm run lint`) and tests (`npm test`).
  - Upload test reports and build artifacts.
- **Why**: Validates code before building and deploying.

### 2. Package Build Job
- **Purpose**: Create and secure the Docker image.
- **Depends on**: Source Test job.
- **Steps**: 
  - Build the Next.js app (`npm run build`).
  - Setup Docker and login to GHCR (GitHub Container Registry).
  - Build and push Docker image tagged with commit SHA and `latest`.
  - Scan image with Trivy for HIGH/CRITICAL vulnerabilities.
  - Upload build artifacts.
- **Why**: Ensures application is packaged and scanned for security issues.

### 3. Deploy Production Job
- **Purpose**: Deploy to production with zero downtime.
- **Depends on**: Package Build job.
- **Steps**: 
  - Checkout code for SSH setup.
  - Connect to EC2 host via SSH and pull the new Docker image.
  - Run a new container with environment variables (e.g., Supabase keys).
  - Perform health checks to verify application status.
  - Replace the old container with the new one.
  - Clean up unused Docker images.
- **Why**: Automates deployment while minimizing downtime.

## Flow and Connections
- Jobs run sequentially: Source Test → Package Build → Deploy Production.
- Each job depends on the previous one, ensuring quality gates are met.

## Tips for Developers
- Run tests locally before pushing to avoid pipeline failures.
- Monitor security scans and fix vulnerabilities promptly.
- For deployment issues, verify EC2 host access and secret configurations.

This pipeline streamlines development and deployment for the Next.js service.