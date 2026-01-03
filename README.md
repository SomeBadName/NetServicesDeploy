NetServicesDeploy

NetServicesDeploy provides a centralized, reusable GitHub Actions workflow to build, publish, and deploy Docker-based .NET services using a self-hosted runner.

Each service lives in its own repository.
All deployment logic lives here.

No SSH scripts.
No manual server steps.
No duplicated pipelines.

What this solves

One deployment engine for all services

Consistent Docker builds and GHCR publishing

Consistent server layout

Environment-based secrets (prod, stage, etc.)

Works with many independent repositories (no monorepo)

Designed to scale as the number of services grows

Architecture overview

On every push to a service repository:

Docker image is built from the service repo

Image is pushed to GitHub Container Registry (GHCR)

Server stack folder is created/updated

Runtime .env file is generated

docker-compose.yml is rendered

Container is restarted using docker compose

Health check is executed

Requirements
Server

Linux server

Docker installed

Docker Compose v2+

GitHub Actions self-hosted runner

Runner user:

belongs to the docker group

has write access to /opt/stacks

Recommended one-time setup:

sudo mkdir -p /opt/stacks
sudo chown -R <runner-user>:<runner-user> /opt/stacks

GitHub

Repositories under the same organization

GHCR enabled

Reusable workflows allowed at org level

Server layout

Each deployed service is stored under:

/opt/stacks/<service_name>/
├── docker-compose.yml
└── .env


⚠️ These files are managed by the workflow.
Do not edit them manually.

How secrets work (important)

This workflow uses GitHub Environments.

Each service repo defines an environment (e.g. prod)

Secrets live inside that environment

The reusable workflow does not know provider names (MinIO, Spotify, etc.)

Secrets are mapped using 5 generic placeholders: $S1 … $S5

This keeps the deploy logic fully generic.

Using the reusable workflow in a service repo
1. Ensure your service has a Dockerfile

Recommended:

./Dockerfile


If not, you can specify a custom path using dockerfile_path.

2. Create an Environment

In the service repository:

Settings → Environments → New environment → prod


Add secrets required by the service, for example:

MINIO_ACCESS_KEY

MINIO_SECRET_KEY

3. Add the deploy workflow

Create:

.github/workflows/deploy.yml


Example:

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

Secret mapping model

Environment secrets:

MINIO_ACCESS_KEY
MINIO_SECRET_KEY


Workflow mapping:

secret1_name: MINIO_ACCESS_KEY
secret2_name: MINIO_SECRET_KEY


Runtime .env result:

Minio__AccessKey=<real value>
Minio__SecretKey=<real value>


The reusable workflow never knows what MinIO is.

Default conventions

Recommended standards for all services:

service_name → lowercase only

Container listens on port 8080

Host port is chosen per service

Health endpoint → /health

Always set:

ASPNETCORE_URLS=http://0.0.0.0:8080

Troubleshooting
Dockerfile not found

Ensure Dockerfile exists in repo root
or

Set dockerfile_path explicitly

Health check fails

On the server:

docker ps
docker logs -n 200 <service_name>
curl http://127.0.0.1:<host_port>/health

GHCR error: repository name must be lowercase

Ensure service_name is lowercase

Org name is automatically lowercased by the workflow

Quick start checklist (new service)

 Add Dockerfile

 Create prod environment

 Add required secrets

 Add deploy workflow

 Push to master

 Verify health endpoint
