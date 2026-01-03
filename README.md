NetServicesDeploy centralizes build + deploy for Docker-based .NET services using a self-hosted GitHub Actions runner.
Service repositories remain minimal: code + Dockerfile + a tiny caller workflow.

What this gives you

One deployment engine for all services

Consistent GHCR image publishing

Consistent server layout (/opt/stacks/<service>/…)

No SSH scripts, no manual server deploy steps

Environment-based secrets (prod/stage/etc.)

Works across many independent repositories (not monorepo)

Requirements
Server

Docker installed

Docker Compose v2+

GitHub Actions self-hosted runner installed on the server

Runner user:

is in the docker group

can write to /opt/stacks

Recommended one-time setup:

sudo mkdir -p /opt/stacks
sudo chown -R <runner-user>:<runner-user> /opt/stacks

GitHub

Repositories are under the same org

GHCR enabled

Reusable workflows allowed in org settings

How it works

On push (service repo):

Build Docker image from repo

Push image to GHCR
ghcr.io/<org>/<service_name>:latest and :sha

Create/update server folder:
/opt/stacks/<service_name>/

Write runtime .env file:

IMAGE reference

env_vars (non-secret)

env_secrets (templated from Environment secrets)

Generate docker-compose.yml

docker compose pull && docker compose up -d

Health check at:
http://127.0.0.1:<host_port><health_path>

Server layout

For each deployed service:

/opt/stacks/<service_name>/
├── docker-compose.yml
└── .env


The workflow owns these files; do not edit manually.

Using the reusable workflow in a service repo
1) Ensure you have a Dockerfile

Recommended: repository root contains:

./Dockerfile


If yours differs, set dockerfile_path.

2) Create an Environment (e.g. prod)

Service repo:

Settings → Environments → prod

Add secrets required by that service (e.g. MINIO_ACCESS_KEY)

3) Add the caller workflow

Create .github/workflows/deploy.yml:

name: Deploy MyService

on:
  push:
    branches: [ "master" ]

permissions:
  contents: read
  packages: write

jobs:
  deploy:
    uses: <ORG_NAME>/NetServicesDeploy/.github/workflows/deploy-dotnet-docker.yml@master
    with:
      environment_name: prod
      service_name: myservice
      host_port: "7100"
      container_port: "8080"
      health_path: "/health"

      env_vars: |
        ASPNETCORE_ENVIRONMENT=Production
        ASPNETCORE_URLS=http://0.0.0.0:8080
        SomeConfig__BaseUrl=https://example.com

      env_secrets: |
        SomeConfig__ClientSecret=$S1

      secret1_name: SOME_CONFIG_CLIENT_SECRET
      secret2_name: ""
      secret3_name: ""
      secret4_name: ""
      secret5_name: ""

Secrets mapping model (important)

The reusable workflow does not know provider-specific secret names (MinIO/Spotify/etc.).
Instead it supports 5 placeholders $S1..$S5.

You decide:

which Environment secret name fills $S1 via secret1_name

which config key gets that value via env_secrets

Example:

Environment secret:

MINIO_ACCESS_KEY

Caller mapping:

secret1_name: MINIO_ACCESS_KEY

env_secrets: Minio__AccessKey=$S1

Recommended conventions

service_name must be lowercase (Docker/GHCR requirement)

Container listens on 8080 internally

Map external ports per service using host_port

Always set ASPNETCORE_URLS=http://0.0.0.0:8080 in env_vars

Troubleshooting

Dockerfile not found

Ensure file exists at ./Dockerfile or pass dockerfile_path

Health check fails

Confirm service is up:

docker ps
docker logs -n 200 <service_name>
curl -i http://127.0.0.1:<host_port><health_path>


GHCR repository name must be lowercase

Use lowercase service_name and org names are lowercased automatically in workflow

Quick-start checklist for a new service

 Add Dockerfile at repo root

 Create Environment prod with needed secrets

 Add minimal caller workflow

 Push to master

 Verify curl http://127.0.0.1:<port>/health
