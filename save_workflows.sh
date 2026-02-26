#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'
ok() { echo -e "${GREEN}    $1${NC}"; }

echo ""
echo "#####################################"
echo " Exporting workflows from n8n"
echo "#####################################"

# Export all workflows to /n8n_workflows
docker exec autonomous-workflow-n8n \
  n8n export:workflow --all --separate --output=/workflows/ 2>/dev/null

# Rename each file from ID to workflow name
for file in ./n8n_workflows/*.json; do
  if [ -f "$file" ]; then
    NAME=$(cat "$file" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])" 2>/dev/null)
    if [ -n "$NAME" ]; then
      SAFE_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')
      NEW_PATH="./n8n_workflows/${SAFE_NAME}.json"
      if [ "$file" != "$NEW_PATH" ]; then
        mv "$file" "$NEW_PATH"

        python3 -c "
        import json
        with open('${NEW_PATH}') as f:
            d = json.load(f)
        for field in ['updatedAt', 'createdAt', 'shared']:
            d.pop(field, None)

        # Move id to end for readability
        workflow_id = d.pop('id', None)
        if workflow_id:
            d['id'] = workflow_id

        workflow_tags = d.pop('tags', None)
        if workflow_tags:
            d['tags'] = workflow_tags

        with open('${NEW_PATH}', 'w') as f:
            json.dump(d, f, indent=2)
        "
        ok "Saved: ${SAFE_NAME}.json"
      fi
    fi
  fi
done

echo ""

