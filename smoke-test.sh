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

# 7. Rejoin after leave (should succeed now)
echo "7. Rejoin after leave"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\"}" \
  "$BASE_URL/api/room/join")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/join (rejoin)" "$STATUS" "$BODY" 200 '"Joined room successfully"'

# 8. Submit strokes with strokeId, userId, strokeWidth
echo "8. Submit strokes (with strokeId, userId, strokeWidth)"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-001\",\"userId\":\"user-A\",\"strokes\":[{\"x\":10,\"y\":20,\"color\":\"#ff0000\",\"action\":\"move\",\"strokeWidth\":5.0},{\"x\":15,\"y\":25,\"color\":\"#ff0000\",\"action\":\"draw\",\"strokeWidth\":5.0}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 9. Submit second stroke group
echo "9. Submit second stroke group"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-002\",\"userId\":\"user-B\",\"strokes\":[{\"x\":100,\"y\":200,\"color\":\"#rainbow\",\"action\":\"draw\"},{\"x\":105,\"y\":205,\"color\":\"#rainbow\",\"action\":\"draw\"}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (stroke-002)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# 10. Sync — get all strokes (should have 4, with new fields)
echo "10. Sync (all strokes)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=0")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/sync (all)" "$STATUS" "$BODY" 200 '"count":4'
# Verify new fields are present
echo "$BODY" | grep -q '"strokeId"' && echo "       strokeId field present" || echo "       MISSING strokeId field"
echo "$BODY" | grep -q '"userId"' && echo "       userId field present" || echo "       MISSING userId field"
echo "$BODY" | grep -q '"strokeWidth"' && echo "       strokeWidth field present" || echo "       MISSING strokeWidth field"
SERVER_TIME=$(echo "$BODY" | grep -o '"serverTime":[0-9]*' | cut -d: -f2)

# 11. Sync delta (should return 0 new)
echo "11. Sync (delta — empty)"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=$SERVER_TIME")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/sync (delta)" "$STATUS" "$BODY" 200 '"count":0'

# 12. Undo specific stroke
echo "12. Undo stroke-001"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokeId\":\"stroke-001\"}" \
  "$BASE_URL/api/drawing/undo")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/undo (specific)" "$STATUS" "$BODY" 200 '"undoneCount":2'

# 13. Sync after undo — should only have stroke-002 points (2)
echo "13. Sync after undo"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=0")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/sync (after undo)" "$STATUS" "$BODY" 200 '"count":2'

# 14. Undo without strokeId (undoes most recent = stroke-002)
echo "14. Undo most recent"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\"}" \
  "$BASE_URL/api/drawing/undo")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/undo (latest)" "$STATUS" "$BODY" 200 '"undoneCount":2'

# 15. Submit with default strokeWidth (should default to 8.0)
echo "15. Submit with default strokeWidth"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"roomCode\":\"$ROOM_CODE\",\"strokes\":[{\"x\":50,\"y\":50,\"color\":\"#eraser\",\"action\":\"draw\"}]}" \
  "$BASE_URL/api/drawing/submit")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/drawing/submit (defaults)" "$STATUS" "$BODY" 200 '"Strokes saved"'

# Verify default strokeWidth = 8
RESP=$(curl -s "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=0")
echo "$RESP" | grep -q '"strokeWidth":8' && echo "       Default strokeWidth=8 confirmed" || echo "       MISSING default strokeWidth"

# 16. Delete room
echo "16. Delete room"
RESP=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/room/$ROOM_CODE")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "DELETE /api/room/:roomCode" "$STATUS" "$BODY" 200 '"Room deleted"'

# 17. Sync on deleted room (should 404)
echo "17. Sync deleted room"
RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/drawing/sync/$ROOM_CODE?last_timestamp=0")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "GET /api/drawing/sync (deleted)" "$STATUS" "$BODY" 404 '"Room not found'

# 18. Join invalid room
echo "18. Join invalid room"
RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d '{"roomCode":"000000"}' \
  "$BASE_URL/api/room/join")
BODY=$(echo "$RESP" | sed '$d')
STATUS=$(echo "$RESP" | tail -1)
check "POST /api/room/join (bad code)" "$STATUS" "$BODY" 404 '"Room not found'

# Results
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
