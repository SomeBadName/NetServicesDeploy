NetServicesDeploy
=================

Centralized, reusable GitHub Actions workflows for building, publishing, and deploying Docker-based .NET services on a self-hosted runner.

## Why use this?

* One deployment engine for all services
* Consistent Docker builds and GHCR publishing
* Predictable server layout and runtime files
* Environment-based secrets (prod, stage, etc.)
* Works across many independent repositories (no monorepo required)
* Scales as the number of services grows

## How it works (high level)

On every push to a service repository, the workflow:

1. Builds the Docker image from the service repository.
2. Pushes the image to GitHub Container Registry (GHCR).
3. Creates/updates the service stack folder on the server.
4. Generates the runtime `.env` file.
5. Renders `docker-compose.yml`.
6. Restarts the container with Docker Compose.
7. Runs a health check.

## Requirements

### Server

* Linux server with Docker and Docker Compose v2+
* GitHub Actions self-hosted runner
  * Runner user belongs to the `docker` group.
  * Runner user has write access to `/opt/stacks`.
  * Recommended one-time setup:

    ```bash
    sudo mkdir -p /opt/stacks
    sudo chown -R <runner-user>:<runner-user> /opt/stacks
    ```

### GitHub

* Service repositories under the same organization
* GHCR enabled
* Reusable workflows allowed at the org level

## Server layout

Each deployed service lives under:

```text
/opt/stacks/<service_name>/
├── docker-compose.yml
└── .env
```

> ⚠️ These files are managed by the workflow. Do not edit them manually.

## Secrets model (important)

* The workflow uses GitHub **Environments** (e.g., `prod`).
* Secrets are defined in the environment and mapped through five generic placeholders: `$S1` … `$S5`.
* The workflow never needs to know provider-specific names (MinIO, Spotify, etc.), keeping the deploy logic fully generic.

## Using the reusable workflow in a service repository

1. **Ensure your service has a Dockerfile**
   * Recommended path: `./Dockerfile`
   * If different, set `dockerfile_path` accordingly.

2. **Create an environment**
   * In the service repository: `Settings → Environments → New environment → prod`
   * Add required secrets (example):
     * `MINIO_ACCESS_KEY`
     * `MINIO_SECRET_KEY`

3. **Add the deploy workflow**
   * Create `.github/workflows/deploy.yml` with contents similar to:

```yaml
name: Deploy FileUploader

on:
  push:
    branches: [ "master" ]

permissions:
  contents: read
  packages: write

jobs:
  deploy:
    uses: SomeBadName/NetServicesDeploy/.github/workflows/deploy-dotnet-docker.yml@master
    with:
      environment_name: prod
      service_name: fileuploader
      host_port: "7000"
      container_port: "8080"
      health_path: "/health"

      env_vars: |
        ASPNETCORE_ENVIRONMENT=Production
        ASPNETCORE_URLS=http://0.0.0.0:8080
        Minio__Endpoint=http://monforserver.tail8cdaec.ts.net:9000
        Minio__BucketName=storage
        Minio__UseSSL=false

      env_secrets: |
        Minio__AccessKey=$S1
        Minio__SecretKey=$S2

      secret1_name: MINIO_ACCESS_KEY
      secret2_name: MINIO_SECRET_KEY
      secret3_name: ""
      secret4_name: ""
      secret5_name: ""
```

### Secret mapping model

* **Environment secrets**
  * `MINIO_ACCESS_KEY`
  * `MINIO_SECRET_KEY`

* **Workflow mapping**
  * `secret1_name: MINIO_ACCESS_KEY`
  * `secret2_name: MINIO_SECRET_KEY`

* **Runtime .env result**
  * `Minio__AccessKey=<real value>`
  * `Minio__SecretKey=<real value>`

> The reusable workflow never knows what MinIO is.

## Default conventions

Recommended standards for all services:

* `service_name` uses lowercase only.
* Containers listen on port `8080` internally.
* Choose a unique host port per service.
* Health endpoint: `/health`
* Always set `ASPNETCORE_URLS=http://0.0.0.0:8080`

## Troubleshooting

**Dockerfile not found**

* Confirm the Dockerfile exists in the repo root, or set `dockerfile_path` explicitly.

**Health check fails**

Run on the server:

```bash
docker ps
docker logs -n 200 <service_name>
curl http://127.0.0.1:<host_port>/health
```

**GHCR error: repository name must be lowercase**

* Ensure `service_name` is lowercase. (Org name is automatically lowercased by the workflow.)

## Quick start checklist (new service)

* Add Dockerfile.
* Create `prod` environment.
* Add required secrets.
* Add deploy workflow.
* Push to `master`.
* Verify health endpoint.
