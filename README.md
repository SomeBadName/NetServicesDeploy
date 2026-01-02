# Platform Deployment Workflows

This repository hosts reusable deployment helpers.

## Reusable Docker deployment workflow

The workflow `.github/workflows/deploy-dotnet-docker.yml` builds a Docker image, pushes it to GHCR, and deploys it with Docker Compose on a self-hosted runner.

### Inputs
- `service_name` (required): Name of the service/container.
- `host_port` (required): Host port to expose.
- `container_port` (optional, default `8080`): Container port to expose.
- `stack_dir` (optional): Target directory for the stack (defaults to `/opt/stacks/<service_name>`).
- `dockerfile_path` (optional, default `./DockerFile`): Path to the Dockerfile.
- `health_path` (optional, default `/health`): Path used for the local health check.
- `env_vars` (optional): Additional environment variables to append to the generated `.env` file (e.g. `"APP_ENV=prod\nLOG_LEVEL=info"`).
- `env_secrets` (optional): Secret environment variables to append to the generated `.env` file (pass values from the caller workflow, e.g. `"DB_PASSWORD=${{ secrets.DB_PASSWORD }}"`).

### Example usage
```yaml
jobs:
  deploy:
    uses: org/repo/.github/workflows/deploy-dotnet-docker.yml@main
    with:
      service_name: my-service
      host_port: "8080"
      env_vars: |
        APP_ENV=prod
        LOG_LEVEL=info
      env_secrets: |
        DB_PASSWORD=${{ secrets.DB_PASSWORD }}
    secrets: inherit
```
