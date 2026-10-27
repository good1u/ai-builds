#!/usr/bin/env bash
# Builds the Data 360 side of Deployment Copilot through the Connect REST API.
# Run from the project root after Data 360 is turned on (Setup > Data Cloud Setup > Get Started)
# and after Deployment_Copilot_D360_Connector is deployed.
#   bash data360/setup.sh <org-alias>
set -euo pipefail
ORG="${1:?usage: bash data360/setup.sh <org-alias>}"
API=/services/data/v68.0/ssot
post() { sf api request rest "$API/$1" -o "$ORG" --method POST --body "@$2" >/dev/null && echo "ok   $1 <- $2"; }

# 1. Let the CRM connector user read the two custom objects.
#    Without this the stream API says the custom fields are "missing a value".
CONNECTOR_USER=$(sf data query -o "$ORG" --json \
  -q "SELECT Assignee.Username FROM PermissionSetAssignment WHERE PermissionSet.Name = 'sfdc_a360_sfcrm_data_extract' LIMIT 1" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['records'][0]['Assignee']['Username'])")
sf org assign permset -o "$ORG" --name Deployment_Copilot_D360_Connector --on-behalf-of "$CONNECTOR_USER" || true

# 2. Data streams (Salesforce CRM connector). Field names drop "__c" for "_c"; Data 360 adds its own "__c".
post data-streams data360/stream-adoption-metric.json
post data-streams data360/stream-engagement.json

# 3. Custom data model objects, and the mappings onto them.
post data-model-objects data360/dmo-adoption-metric.json
post data-model-objects data360/dmo-copilot-engagement.json
post "data-model-object-mappings?dataspace=default" data360/map-adoption-metric.json
post "data-model-object-mappings?dataspace=default" data360/map-copilot-engagement.json

# 4. The calculated insight, from the SQL file.
python3 - > /tmp/weekly-adoption-ci.json <<'PY'
import json
print(json.dumps({
    "apiName": "Weekly_Adoption", "displayName": "Weekly Adoption",
    "description": "Adoption rate and containment rate per engagement per week, from Adoption Metric records ingested from CRM.",
    "expression": open("data360/Weekly_Adoption.ci.sql").read(),
    "definitionType": "CALCULATED_METRIC", "dataSpaceName": "default", "publishScheduleInterval": "NotScheduled"}))
PY
post calculated-insights /tmp/weekly-adoption-ci.json

# 5. First runs. Ingestion takes a few minutes; run the insight again once the DMO has rows.
EMPTY='{"mode":"raw","raw":""}'
for s in Adoption_Metric_Home Engagement_Home; do
  sf api request rest "$API/data-streams/$s/actions/run" -o "$ORG" --method POST --body "{\"dataStreamNames\":[\"$s\"]}" >/dev/null && echo "ok   run $s"
done
echo "When Adoption_Metric__dlm has rows, run the insight:"
echo "  sf api request rest $API/calculated-insights/Weekly_Adoption__cio/actions/run -o $ORG --method POST --body '$EMPTY'"
