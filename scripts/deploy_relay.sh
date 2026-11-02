#!/usr/bin/env bash
# Deploys the live transcription relay (relay/) to Cloud Run in southamerica-east1, next to the
# functions, and prints the URL the app needs (docs/MODELS.md § Realtime).
#
#   scripts/deploy_relay.sh [project]        # default: ronda-uy
#
# Once, before the first deploy: the Meta key as a Secret Manager secret the service reads,
# the same one the functions use:
#   gcloud secrets create MODEL_API_KEY --replication-policy=automatic   # if it doesn't exist
#   printf '%s' "$MODEL_API_KEY" | gcloud secrets versions add MODEL_API_KEY --data-file=-
# and the service account's rights: Secret Manager Secret Accessor, Firebase Authentication
# Viewer (ID tokens) and Cloud Datastore User (users/{uid}.terms).
#
# Then build the app with the URL this prints:
#   --dart-define=LIVE_TRANSCRIPT_URL=wss://<service>-<hash>-rj.a.run.app/v1/live
# With no URL the app records as before and reads the note with `extract`.
set -euo pipefail

project="${1:-ronda-uy}"
cd "$(dirname "$0")/../relay"

gcloud run deploy ronda-relay \
  --project "$project" \
  --region southamerica-east1 \
  --source . \
  --allow-unauthenticated \
  --min-instances 1 \
  --max-instances 3 \
  --concurrency 40 \
  --timeout 300 \
  --cpu 1 --memory 256Mi \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$project" \
  --set-secrets "MODEL_API_KEY=MODEL_API_KEY:latest"

url="$(gcloud run services describe ronda-relay --project "$project" --region southamerica-east1 --format 'value(status.url)')"
echo
echo "Relay: $url"
echo "App:   --dart-define=LIVE_TRANSCRIPT_URL=${url/https:/wss:}/v1/live"
