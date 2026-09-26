#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
scanner_url="${FACE_ANALYSIS_URL:-}"
if [ -z "$scanner_url" ]; then
  scanner_ip=$(ipconfig getifaddr en0 2>/dev/null || true)
  if [ -z "$scanner_ip" ]; then
    echo 'Set FACE_ANALYSIS_URL to the analysis server URL.' >&2
    exit 1
  fi
  scanner_url="http://$scanner_ip:8000"
fi
if ! curl --fail --silent --max-time 5 "$scanner_url/health" >/dev/null; then
  echo "Analysis server is unavailable: $scanner_url" >&2
  echo 'Start ../face-shape-prediction-lab/start-local.command first.' >&2
  exit 1
fi
echo "Face analysis server: $scanner_url"
exec flutter run "--dart-define=FACE_ANALYSIS_URL=$scanner_url" "$@"
