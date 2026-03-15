#!/bin/bash
# Smoke test for vconnect-backend
# Usage: ./smoke-test.sh [base_url]

BASE_URL="${1:-https://vconnect-backend-zicx.onrender.com}"
PASS=0
FAIL=0

echo "=== vconnect-backend Smoke Test ==="
echo "Target: $BASE_URL"
echo ""

# Helper
check() {
  local label="$1" status="$2" body="$3" expected_status="$4" expected_key="$5"
  if [ "$status" -eq "$expected_status" ] && echo "$body" | grep -q "$expected_key"; then
    echo "  PASS  $label (HTTP $status)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label (HTTP $status) — $body"
    FAIL=$((FAIL + 1))
  fi
}

# 1. Health check
echo "1. Health check"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /health" "$STATUS" "$BODY" 200 '"status":"ok"'

# 2. Create room
echo "2. Create room"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/room/create")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/create" "$STATUS" "$BODY" 201 '"roomCode"'
ROOM_CODE=$(echo "$BODY" | grep -o '"roomCode":"[0-9]*"' | cut -d'"' -f4)
echo "       Room code: $ROOM_CODE"

# 3. CORS preflight
echo "3. CORS preflight"
RESP=$(curl -s -w "\n%{http_code}" -X OPTIONS \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  "$BASE_URL/api/room/create")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
if [ "$STATUS" -eq 204 ] || [ "$STATUS" -eq 200 ]; then
  echo "  PASS  OPTIONS preflight (HTTP $STATUS)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  OPTIONS preflight (HTTP $STATUS) — $BODY"
  FAIL=$((FAIL + 1))
fi

# 4. Join room
echo "4. Join room"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\"}" \
  "$BASE_URL/api/room/join")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/join" "$STATUS" "$BODY" 200 '"Joined room successfully"'

# 5. Join full room (should fail with 409)
echo "5. Join full room"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\"}" \
  "$BASE_URL/api/room/join")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/join (full)" "$STATUS" "$BODY" 409 '"Room is full"'

# 6. Leave room
echo "6. Leave room"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\"}" \
  "$BASE_URL/api/room/leave")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/leave" "$STATUS" "$BODY" 200 '"Left room successfully"'

# 7. Rejoin after leave
echo "7. Rejoin after leave"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\"}" \
  "$BASE_URL/api/room/join")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/join (rejoin)" "$STATUS" "$BODY" 200 '"Joined room successfully"'

# 8. Version check (initial = 0)
echo "8. Version check (initial)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/version/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/version (=0)" "$STATUS" "$BODY" 200 '"snapshotVersion":0'

# 9. Submit strokes with strokeId, userId, strokeWidth
echo "9. Submit strokes (stroke-001)"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-001\",\"userId\":\"user-A\",\"strokes\":[{\"x\":10,\"y\":20,\"color\":\"#ff0000\",\"action\":\"move\",\"strokeWidth\":5.0},{\"x\":15,\"y\":25,\"color\":\"#ff0000\",\"action\":\"draw\",\"strokeWidth\":5.0}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (stroke-001)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 10. Submit second stroke group
echo "10. Submit strokes (stroke-002)"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-002\",\"userId\":\"user-B\",\"strokes\":[{\"x\":100,\"y\":200,\"color\":\"#rainbow\",\"action\":\"draw\"},{\"x\":105,\"y\":205,\"color\":\"#rainbow\",\"action\":\"draw\"}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (stroke-002)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 11. Version should be 2
echo "11. Version check (=2)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/version/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/version (=2)" "$STATUS" "$BODY" 200 '"snapshotVersion":2'

# 12. Snapshot — 4 visible strokes
echo "12. Snapshot (4 strokes)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/snapshot (4)" "$STATUS" "$BODY" 200 '"count":4'
echo "$BODY" | grep -q '"snapshotVersion"' && echo "       snapshotVersion present" || echo "       MISSING snapshotVersion"

# 13. Sync — get all strokes (should also have 4)
echo "13. Sync (all strokes)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=0")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/sync (all)" "$STATUS" "$BODY" 200 '"count":4'
echo "$BODY" | grep -q '"strokeId"' && echo "       strokeId field present" || echo "       MISSING strokeId"
echo "$BODY" | grep -q '"userId"' && echo "       userId field present" || echo "       MISSING userId"
echo "$BODY" | grep -q '"strokeWidth"' && echo "       strokeWidth field present" || echo "       MISSING strokeWidth"
SERVER_TIME=$(echo "$BODY" | grep -o '"serverTime":[0-9]*' | cut -d: -f2)

# 14. Sync delta (empty)
echo "14. Sync (delta — empty)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=$SERVER_TIME")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/sync (delta)" "$STATUS" "$BODY" 200 '"count":0'

# 15. Submit undo marker — should remove stroke-002 from snapshot
echo "15. Submit undo marker"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"undo-1\",\"userId\":\"user-B\",\"strokes\":[{\"x\":0,\"y\":0,\"color\":\"#000\",\"action\":\"undo\"}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (undo marker)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 16. Snapshot after undo — 2 visible (stroke-001 only)
echo "16. Snapshot after undo marker"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/snapshot (after undo)" "$STATUS" "$BODY" 200 '"count":2'

# 17. Submit clear action
echo "17. Submit clear"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"clear-1\",\"userId\":\"user-A\",\"strokes\":[{\"x\":0,\"y\":0,\"color\":\"#000\",\"action\":\"clear\"}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (clear)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 18. Snapshot after clear — 0 visible
echo "18. Snapshot after clear"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/snapshot (after clear)" "$STATUS" "$BODY" 200 '"count":0'

# 19. Submit new strokes after clear
echo "19. Submit stroke-003 (after clear)"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-003\",\"userId\":\"user-A\",\"strokes\":[{\"x\":50,\"y\":50,\"color\":\"#eraser\",\"action\":\"draw\"}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (stroke-003)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 20. Snapshot — 1 visible after clear
echo "20. Snapshot (1 after clear)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/snapshot (1)" "$STATUS" "$BODY" 200 '"count":1'

# 21. DELETE last stroke group
echo "21. Delete last stroke group"
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/drawing/strokes/$ROOM_CODE/last")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "DELETE /api/drawing/strokes/.../last" "$STATUS" "$BODY" 200 '"deletedCount":1'

# 22. Snapshot after delete — 0
echo "22. Snapshot after delete"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/snapshot (0 after delete)" "$STATUS" "$BODY" 200 '"count":0'

# 23. Delete on empty — should fail
echo "23. Delete last (empty)"
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/drawing/strokes/$ROOM_CODE/last")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "DELETE /api/drawing/strokes/.../last (empty)" "$STATUS" "$BODY" 400 '"No strokes to delete"'

# 24. Undo via dedicated endpoint
echo "24. Submit stroke-004 for undo test"
curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-004\",\"userId\":\"user-A\",\"strokes\":[{\"x\":1,\"y\":1,\"color\":\"#fff\",\"action\":\"draw\"}]}" \
  "$BASE_URL/api/drawing/submit" > /dev/null
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-004\"}" \
  "$BASE_URL/api/drawing/undo")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/undo (specific)" "$STATUS" "$BODY" 200 '"undoneCount":1'

# 25. Default strokeWidth
echo "25. Default strokeWidth"
curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-005\",\"strokes\":[{\"x\":1,\"y\":1,\"color\":\"#000\",\"action\":\"draw\"}]}" \
  "$BASE_URL/api/drawing/submit" > /dev/null
RESP=$(curl -s "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
if echo "$RESP" | grep -q '"strokeWidth":8'; then
  echo "  PASS  Default strokeWidth=8"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Default strokeWidth — $RESP"
  FAIL=$((FAIL + 1))
fi

# 26. Delete room
echo "26. Delete room"
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/room/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "DELETE /api/room/:roomCode" "$STATUS" "$BODY" 200 '"Room deleted"'

# 27. Snapshot on deleted room
echo "27. Snapshot deleted room"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/snapshot/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/snapshot (deleted)" "$STATUS" "$BODY" 404 '"Room not found'

# 28. Version on deleted room
echo "28. Version deleted room"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/version/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/version (deleted)" "$STATUS" "$BODY" 404 '"Room not found'

# Results
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
