#!/bin/bash
set -euo pipefail

TARGET="$1"
CSV_PATH="$2"
BATCH_SIZE="${3:-2000}"
NAMESPACE="${4:-mereka-lms}"
TOTAL=$(( $(wc -l < "$CSV_PATH") - 1 ))
OFFSET="${5:-0}"
MAX_RETRIES=10
RETRY_DELAY=30

echo "Starting $TARGET import: total=$TOTAL batch_size=$BATCH_SIZE start_offset=$OFFSET"

get_pod() {
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

upload_files() {
    local pod="$1"
    echo "  Uploading files to pod $pod..."
    kubectl cp scripts/migrations/kajabi/openedx_bulk_import.py \
        "$NAMESPACE/$pod:/tmp/openedx_bulk_import.py"
    kubectl cp "$CSV_PATH" \
        "$NAMESPACE/$pod:/tmp/$(basename "$CSV_PATH")"
}

LAST_POD=""

while [ "$OFFSET" -lt "$TOTAL" ]; do
    REMAINING=$(( TOTAL - OFFSET ))
    BATCH=$(( REMAINING < BATCH_SIZE ? REMAINING : BATCH_SIZE ))
    echo "-> Batch offset=$OFFSET size=$BATCH ($(date +%H:%M:%S))"

    ATTEMPT=0
    while true; do
        POD=$(get_pod)
        if [ -z "$POD" ]; then
            ATTEMPT=$((ATTEMPT + 1))
            echo "  ! No pod found, waiting ${RETRY_DELAY}s ($ATTEMPT/$MAX_RETRIES)"
            sleep "$RETRY_DELAY"
            if [ "$ATTEMPT" -ge "$MAX_RETRIES" ]; then
                echo "FATAL: No pod after $MAX_RETRIES attempts. Last offset: $OFFSET"
                exit 1
            fi
            continue
        fi

        if [ "$POD" != "$LAST_POD" ]; then
            echo "  Pod changed: $LAST_POD -> $POD"
            upload_files "$POD" || {
                ATTEMPT=$((ATTEMPT + 1))
                echo "  ! Upload failed, waiting ${RETRY_DELAY}s ($ATTEMPT/$MAX_RETRIES)"
                sleep "$RETRY_DELAY"
                continue
            }
            LAST_POD="$POD"
        fi

        OUTPUT=$(kubectl exec -n "$NAMESPACE" "$POD" -- \
            python /tmp/openedx_bulk_import.py \
            "$TARGET" --csv "/tmp/$(basename "$CSV_PATH")" \
            --settings tutor.production \
            --offset "$OFFSET" --limit "$BATCH" 2>&1) && {
            echo "  OK $OUTPUT"
            NEW_OFFSET=$(echo "$OUTPUT" | grep -oP 'last=\K[0-9]+' || echo "")
            if [ -n "$NEW_OFFSET" ] && [ "$NEW_OFFSET" -gt "$OFFSET" ]; then
                OFFSET="$NEW_OFFSET"
            else
                OFFSET=$((OFFSET + BATCH))
            fi
            break
        } || {
            ATTEMPT=$((ATTEMPT + 1))
            echo "  ! Failed ($ATTEMPT/$MAX_RETRIES): $OUTPUT"
            sleep "$RETRY_DELAY"
            if [ "$ATTEMPT" -ge "$MAX_RETRIES" ]; then
                echo "FATAL: Batch at offset=$OFFSET failed $MAX_RETRIES times"
                exit 1
            fi
            LAST_POD=""
        }
    done
done

echo "All $TARGET batches completed. Total=$TOTAL final_offset=$OFFSET"
