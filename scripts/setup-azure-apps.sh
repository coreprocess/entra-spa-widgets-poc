#!/bin/bash

set -e

command -v jq >/dev/null 2>&1 || { echo >&2 "❌ jq is required but not installed. Aborting."; exit 1; }
command -v uuidgen >/dev/null 2>&1 || { echo >&2 "❌ uuidgen is required but not installed. Aborting."; exit 1; }

CURRENT_ISO_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
APP_NAME_PREFIX="Pre-Auth-App-Test $CURRENT_ISO_TIMESTAMP"

echo "🔐 Fetching tenant ID..."
TENANT_ID=$(az account show --query tenantId -o tsv)
GRAPH_API="https://graph.microsoft.com/v1.0"
echo "✅ Tenant ID: $TENANT_ID"

# === Function to enforce v2 tokens ===
set_access_token_version() {
  local OBJECT_ID=$1
  echo "⚙️ Setting access token version for app $OBJECT_ID"
  az rest --method PATCH --uri "$GRAPH_API/applications/$OBJECT_ID" \
    --body '{ "api": { "requestedAccessTokenVersion": 2 } }'
}

#############################################
# Create Portal SPA App
#############################################
PORTAL_NAME="$APP_NAME_PREFIX Portal SPA App"
echo "📦 Creating $PORTAL_NAME"
PORTAL_APP=$(az rest --method POST --uri "$GRAPH_API/applications" --body "{
  \"displayName\": \"$PORTAL_NAME\",
  \"signInAudience\": \"AzureADMyOrg\",
  \"spa\": {
    \"redirectUris\": [\"http://localhost:3000\"]
  },
  \"isFallbackPublicClient\": true
}")

PORTAL_CLIENT_ID=$(echo "$PORTAL_APP" | jq -r '.appId')
PORTAL_OBJECT_ID=$(echo "$PORTAL_APP" | jq -r '.id')

set_access_token_version "$PORTAL_OBJECT_ID"

echo "🌐 Setting identifier URI for Portal..."
az ad app update --id "$PORTAL_OBJECT_ID" --set identifierUris="['api://$PORTAL_CLIENT_ID']"

PORTAL_SCOPE_ID=$(uuidgen)
echo "🔧 Adding scope to Portal..."
az rest --method PATCH --uri "$GRAPH_API/applications/$PORTAL_OBJECT_ID" --body "{
  \"api\": {
    \"oauth2PermissionScopes\": [
      {
        \"id\": \"$PORTAL_SCOPE_ID\",
        \"type\": \"User\",
        \"value\": \"access_as_user\",
        \"isEnabled\": true,
        \"adminConsentDisplayName\": \"Access Portal as user\",
        \"adminConsentDescription\": \"Allow the app to access Portal backend on behalf of the signed-in user.\"
      }
    ]
  }
}"

#############################################
# Create Widget1 App
#############################################
WIDGET1_NAME="$APP_NAME_PREFIX Widget1 App"
echo "📦 Creating $WIDGET1_NAME"
WIDGET1_APP=$(az ad app create --display-name "$WIDGET1_NAME")
WIDGET1_CLIENT_ID=$(echo "$WIDGET1_APP" | jq -r '.appId')
WIDGET1_OBJECT_ID=$(echo "$WIDGET1_APP" | jq -r '.id')

set_access_token_version "$WIDGET1_OBJECT_ID"

echo "🌐 Setting identifier URI for Widget1..."
az ad app update --id "$WIDGET1_OBJECT_ID" --set identifierUris="['api://$WIDGET1_CLIENT_ID']"

WIDGET1_SCOPE_ID=$(uuidgen)
echo "🔧 Adding scope to Widget1..."
az rest --method PATCH --uri "$GRAPH_API/applications/$WIDGET1_OBJECT_ID" --body "{
  \"api\": {
    \"oauth2PermissionScopes\": [
      {
        \"id\": \"$WIDGET1_SCOPE_ID\",
        \"type\": \"User\",
        \"value\": \"access_as_user\",
        \"isEnabled\": true,
        \"adminConsentDisplayName\": \"Access Widget1 as user\",
        \"adminConsentDescription\": \"Allow the app to access Widget1 on behalf of the signed-in user.\"
      }
    ]
  }
}"

echo "⏳ Waiting for Graph to register Widget1 scopes..."
sleep 8

echo "🔗 Pre-authorizing Portal for Widget1..."
az rest --method PATCH --uri "$GRAPH_API/applications/$WIDGET1_OBJECT_ID" --body "{
  \"api\": {
    \"preAuthorizedApplications\": [
      {
        \"appId\": \"$PORTAL_CLIENT_ID\",
        \"delegatedPermissionIds\": [\"$WIDGET1_SCOPE_ID\"]
      }
    ]
  }
}"

#############################################
# Create Widget2 App
#############################################
WIDGET2_NAME="$APP_NAME_PREFIX Widget2 App"
echo "📦 Creating $WIDGET2_NAME"
WIDGET2_APP=$(az ad app create --display-name "$WIDGET2_NAME")
WIDGET2_CLIENT_ID=$(echo "$WIDGET2_APP" | jq -r '.appId')
WIDGET2_OBJECT_ID=$(echo "$WIDGET2_APP" | jq -r '.id')

set_access_token_version "$WIDGET2_OBJECT_ID"

echo "🌐 Setting identifier URI for Widget2..."
az ad app update --id "$WIDGET2_OBJECT_ID" --set identifierUris="['api://$WIDGET2_CLIENT_ID']"

WIDGET2_SCOPE_ID=$(uuidgen)
echo "🔧 Adding scope to Widget2..."
az rest --method PATCH --uri "$GRAPH_API/applications/$WIDGET2_OBJECT_ID" --body "{
  \"api\": {
    \"oauth2PermissionScopes\": [
      {
        \"id\": \"$WIDGET2_SCOPE_ID\",
        \"type\": \"User\",
        \"value\": \"access_as_user\",
        \"isEnabled\": true,
        \"adminConsentDisplayName\": \"Access Widget2 as user\",
        \"adminConsentDescription\": \"Allow the app to access Widget2 on behalf of the signed-in user.\"
      }
    ]
  }
}"

echo "⏳ Waiting for Graph to register Widget2 scopes..."
sleep 8

echo "🔗 Pre-authorizing Portal for Widget2..."
az rest --method PATCH --uri "$GRAPH_API/applications/$WIDGET2_OBJECT_ID" --body "{
  \"api\": {
    \"preAuthorizedApplications\": [
      {
        \"appId\": \"$PORTAL_CLIENT_ID\",
        \"delegatedPermissionIds\": [\"$WIDGET2_SCOPE_ID\"]
      }
    ]
  }
}"

#############################################
# Write shared config.js
#############################################
CONFIG_CONTENT="export const config = {
  tenantId: \"$TENANT_ID\",
  clientId: {
    portal: \"$PORTAL_CLIENT_ID\",
    widget1: \"$WIDGET1_CLIENT_ID\",
    widget2: \"$WIDGET2_CLIENT_ID\"
  },
  scopes: {
    portal: \"api://$PORTAL_CLIENT_ID/access_as_user\",
    widget1: \"api://$WIDGET1_CLIENT_ID/access_as_user\",
    widget2: \"api://$WIDGET2_CLIENT_ID/access_as_user\"
  }
};"

CONFIG_PATHS=(
  "./portal/app/config.js"
  "./portal/service/config.js"
  "./widget1/app/config.js"
  "./widget1/service/config.js"
  "./widget2/app/config.js"
  "./widget2/service/config.js"
)

echo "📝 Writing config.js to all app and service folders..."
for path in "${CONFIG_PATHS[@]}"; do
  mkdir -p "$(dirname "$path")"
  echo "$CONFIG_CONTENT" > "$path"
  echo "✔ Wrote $path"
done

#############################################
# Output Summary
#############################################
echo ""
echo "🎉 Azure App Registrations Complete!"
echo "🔑 Tenant ID: $TENANT_ID"
echo ""
echo "📘 Portal:"
echo "  App Name:     $PORTAL_NAME"
echo "  Client ID:    $PORTAL_CLIENT_ID"
echo "  Scope:        api://$PORTAL_CLIENT_ID/access_as_user"
echo ""
echo "📗 Widget1:"
echo "  App Name:     $WIDGET1_NAME"
echo "  Client ID:    $WIDGET1_CLIENT_ID"
echo "  Scope:        api://$WIDGET1_CLIENT_ID/access_as_user"
echo ""
echo "📙 Widget2:"
echo "  App Name:     $WIDGET2_NAME"
echo "  Client ID:    $WIDGET2_CLIENT_ID"
echo "  Scope:        api://$WIDGET2_CLIENT_ID/access_as_user"
echo ""
echo "📁 config.js written to:"
printf "  - %s\n" "${CONFIG_PATHS[@]}"
