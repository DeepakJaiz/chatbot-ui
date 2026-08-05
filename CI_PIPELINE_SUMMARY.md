## Pipeline Walkthrough for Developers

### Overview
This is a full CI/CD pipeline for a Next.js service that builds, tests, scans, and deploys a Dockerized application. Jobs run sequentially with dependencies to ensure quality at each stage.

### Stage 1: Code Quality (`validate-code`)
**Purpose**: Enforce coding standards before any testing or building.
- Runs ESLint for code quality checks
- Verifies Prettier formatting consistency
- Performs TypeScript type checking
- Uses Node.js 20 with npm caching for faster installs

### Stage 2: Unit Tests (`test-unit`)
**Purpose**: Validate business logic and catch regressions.
- Runs Jest tests with coverage reporting
- Uploads test reports and build artifacts (`dist/`) as GitHub artifacts
- Runs only after code quality passes

### Stage 3: Build & Security (`build-package`)
**Purpose**: Create deployable artifacts and validate security.
- Builds the Next.js production bundle
- Builds a Docker image using GitHub Actions cache
- **Security scan**: Uses Trivy to check for critical/high vulnerabilities in the image
- **Conditional push**: Only pushes the image to GHCR on main branch pushes
- Tags images with both commit SHA and `latest`

### Stage 4: Production Deploy (`deploy-ec2`)
**Purpose**: Deploy to production with safety checks.
- **Condition**: Only runs on pushes to `main` (not PRs)
- **Environment**: Uses `production` environment for approval gates
- **Concurrency**: Uses `deploy-production` group to prevent parallel deployments
- **Deployment process**:
  1. Logs into GHCR with GitHub token
  2. Pulls the new Docker image
  3. Stops and removes existing container
  4. Starts new container with environment variables and resource limits (512MB RAM, 1 CPU)
  5. Runs health checks (10 attempts, 3s delay)
  6. **Automatic rollback**: If health checks fail, stops container and exits with error

### Workflow Concurrency
- Uses `group: workflow-ref` to cancel in-progress runs for the same branch
- Prevents redundant deployments when multiple pushes happen quickly

### Key Connections
1. `validate-code` → `test-unit` → `build-package` (sequential dependency)
2. `build-package` → `deploy-ec2` (only for main branch pushes)
3. Artifacts flow: Test reports → Build artifacts → Docker image → EC2 deployment

### Local Development Notes
- Run `npm run lint`, `npm run format:check`, and `npm run type-check` to validate locally
- Tests: `npm test -- --coverage --ci`
- Build: `npm run build`
- Docker: Image is built with multi-stage caching via GitHub Actions cache
