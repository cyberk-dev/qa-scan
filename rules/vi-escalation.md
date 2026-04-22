# QA Scan — Vietnamese Escalation Rule

**Scope:** Mọi qa-* agents trong qa-scan pipeline.
**Intent:** User-facing prompts PHẢI tiếng Việt. Machine status blocks giữ EN (để orchestrator parse).

---

## 1. Trigger Matrix

| Agent Status | `--auto` mode | `--interactive` mode |
|--------------|---------------|----------------------|
| `DONE` | Không hỏi | Có thể confirm (tuỳ config) |
| `DONE_WITH_CONCERNS[observational]` | Log, bỏ qua | Log, có thể bỏ qua |
| `DONE_WITH_CONCERNS[correctness]` | **PHẢI hỏi** | **PHẢI hỏi** |
| `NEEDS_CONTEXT` | **PHẢI hỏi** | **PHẢI hỏi** |
| `BLOCKED` | **PHẢI hỏi** | **PHẢI hỏi** |

**Non-interactive env var:** `QA_SCAN_NONINTERACTIVE=1` → BLOCKED/NEEDS_CONTEXT auto-abort với VERDICT=ABORTED (no prompt). Dùng cho CI/cron.

---

## 2. Tool Priority

1. **Claude:** `AskUserQuestion` (primary) — render structured question với options
2. **Gemini / Antigravity:** Markdown block với numbered options (fallback, no native tool)
3. **Cấm:** hỏi không có diagnosis, hỏi kiểu "bạn muốn gì?" — phải có **Chẩn Đoán** + **Đề Xuất Sửa** trước

---

## 3. Question Schema (AskUserQuestion)

```json
{
  "questions": [{
    "question": "<VI, kết thúc dấu ?>",
    "header": "<VI ≤12 ký tự>",
    "multiSelect": false,
    "options": [
      { "label": "<VI ngắn, 1-5 chữ>", "description": "<VI giải thích hậu quả>" }
    ]
  }]
}
```

**Rules:**
- `question` / `header` / `label` / `description`: **100% tiếng Việt**
- Technical terms EN cho phép trong backticks: `` `LINEAR_API_KEY` ``, `` `port 3000` ``
- 2–4 options. Option cuối: **"Huỷ / Abort"** khi là terminal decision
- First option = recommended fix; thêm `(Khuyến nghị)` vào label
- Status block JSON Schema bên trên, không đổi tên field

---

## 4. Markdown Fallback (Gemini/Antigravity)

Khi `AskUserQuestion` không available:

```markdown
## {Icon} {Tiêu đề VI}

**{Context một dòng}**

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Chẩn Đoán

| Mục | Kết quả | Ghi chú |
|-----|---------|---------|
| ... | ... | ... |

**Nguyên Nhân Gốc:** {root cause VI}

### Đề Xuất Sửa

{Đề xuất cụ thể VI}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Lựa chọn:**
1. {Option VI} (Khuyến nghị) — {mô tả}
2. {Option VI} — {mô tả}
3. Huỷ — {hậu quả}

Trả lời bằng số (1/2/3):
```

---

## 5. Templates T1-T7

Templates được tham chiếu bằng ID (`→ Template T3`). Agents KHÔNG inline nội dung template, chỉ reference ID.

### T1 — Pre-flight Failure

**Trigger:** `qa-orchestrator` Step -1 preflight check fail (Linear/GitNexus/Playwright MCP down)

**Diagnosis keys:** `mcp_name`, `tool_check_result`, `api_key_present`, `network_reachable`, `process_running`

**Template (AskUserQuestion):**
```json
{
  "question": "Pre-flight check thất bại cho `{mcp_name}`. Bạn muốn xử lý thế nào?",
  "header": "Pre-flight Fail",
  "multiSelect": false,
  "options": [
    { "label": "Sửa thủ công (Khuyến nghị)", "description": "Tôi tự fix theo chẩn đoán ở trên, sau đó retry scan" },
    { "label": "Nhập dữ liệu thủ công", "description": "Bỏ qua MCP, paste nội dung issue trực tiếp" },
    { "label": "Huỷ scan", "description": "Stop pipeline, VERDICT=ABORTED" }
  ]
}
```

**Kèm theo (markdown ABOVE prompt):**
```
## ⚠️ Pre-flight Check Failed: {mcp_name}

### Chẩn Đoán
| Mục | Kết quả | Ghi chú |
|-----|---------|---------|
| MCP responding | {✓/❌} | {detail} |
| API key present | {✓/❌} | {detail} |
| Network reachable | {✓/❌} | {detail} |
| Process running | {✓/❌} | {detail} |

**Nguyên Nhân Gốc:** {root cause}

### Đề Xuất Sửa
```bash
{fix command}
```
```

---

### T2 — Issue Confidence Thấp

**Trigger:** `qa-issue-analyzer` trả confidence < 0.5 HOẶC thiếu kịch bản test

**Template:**
```json
{
  "question": "Phân tích issue có độ tin cậy thấp ({confidence}%). Bạn muốn tiếp tục thế nào?",
  "header": "Confidence Thấp",
  "multiSelect": false,
  "options": [
    { "label": "Chỉnh sửa kịch bản (Khuyến nghị)", "description": "Cung cấp mô tả chi tiết hơn, analyzer sẽ phân tích lại" },
    { "label": "Tiếp tục với kịch bản hiện tại", "description": "Chấp nhận độ tin cậy thấp, có thể dẫn tới FAIL/PARTIAL" },
    { "label": "Huỷ scan", "description": "Issue quá mơ hồ, nên test thủ công" }
  ]
}
```

**Kèm theo:**
```
## 📋 Phân Tích Issue (Confidence: {confidence}%)

**TÍNH NĂNG:** {feature_area}
**KỊCH BẢN TEST:**
1. {scenario_1}
2. {scenario_2}

**HÀNH VI MONG ĐỢI:** {expected_behavior}

⚠️ Độ tin cậy thấp — cần xác nhận kỹ.
```

---

### T3 — Scout Không Tìm Thấy Files

**Trigger:** `qa-code-scout` trả về 0 files (GitNexus unavailable + grep miss)

**Template:**
```json
{
  "question": "Scout không tìm thấy code liên quan tới `{feature_area}`. Bạn muốn xử lý thế nào?",
  "header": "Scout Rỗng",
  "multiSelect": false,
  "options": [
    { "label": "Cung cấp đường dẫn file (Khuyến nghị)", "description": "Paste danh sách file path liên quan" },
    { "label": "Chạy GitNexus index lại", "description": "npx gitnexus analyze — retry scout sau index" },
    { "label": "Bỏ qua, chỉ test theo scenario", "description": "Generate test không có code context → chất lượng thấp hơn" },
    { "label": "Huỷ scan", "description": "Feature area không tồn tại trong repo" }
  ]
}
```

---

### T4 — Env Bootstrap Fail

**Trigger:** `qa-env-bootstrap` (Step 0a) fail — thiếu secret / port conflict không resolve được / services không start

**Template:**
```json
{
  "question": "Env bootstrap lỗi: `{error_type}`. Bạn muốn xử lý thế nào?",
  "header": "Env Fail",
  "multiSelect": false,
  "options": [
    { "label": "Cung cấp secret / fix config (Khuyến nghị)", "description": "Prompt nhập các biến thiếu, lưu vào `~/.qa-scan/secrets/{repo}.yaml`" },
    { "label": "Kill process chiếm port", "description": "Force kill `lsof -ti:{port}` — CẢNH BÁO: có thể phá dev session khác" },
    { "label": "Tiếp tục với PARTIAL", "description": "Skip env setup, test với server hiện có nếu 200 OK" },
    { "label": "Huỷ scan", "description": "Env không sẵn sàng, test sau" }
  ]
}
```

**Kèm theo (ví dụ):**
```
## 🔧 Env Bootstrap Failed

**Loại lỗi:** {error_type}
- Missing secrets: {list}
- Port conflict: `port {port}` đang bị `pid {owner_pid}` (cwd: `{owner_cwd}`) chiếm
- Service không start: `{service_name}` healthcheck timeout {timeout}s

**Đề Xuất Sửa:** {recommendation}
```

---

### T5 — Test Generation Invalid

**Trigger:** `qa-test-generator` trả test file không parse được / thiếu assertions / invalid selectors

**Template:**
```json
{
  "question": "Test file sinh ra không hợp lệ: `{reason}`. Bạn muốn xử lý thế nào?",
  "header": "Test Gen Fail",
  "multiSelect": false,
  "options": [
    { "label": "Retry với context khác (Khuyến nghị)", "description": "Cung cấp thêm code context / test example, regenerate" },
    { "label": "Tôi viết test thủ công", "description": "Paste test Playwright vào `evidence/{issue}/test.spec.ts`" },
    { "label": "Bỏ qua test generation", "description": "Verdict = PARTIAL, manual verify required" }
  ]
}
```

---

### T6 — Test Run Fail 3×

**Trigger:** `qa-test-runner` fail 3 lần liên tiếp (timeout, crash, selector miss)

**Template:**
```json
{
  "question": "Test run fail 3 lần: `{last_error}`. Bạn muốn xử lý thế nào?",
  "header": "Test Run Fail",
  "multiSelect": false,
  "options": [
    { "label": "Xem trace + edit test (Khuyến nghị)", "description": "Mở Playwright trace viewer, sửa selector/assertion" },
    { "label": "Tăng timeout + retry", "description": "timeout 30s → 60s, retry 1 lần nữa" },
    { "label": "Report FAIL với evidence hiện có", "description": "Verdict = FAIL, submit báo cáo kèm video/trace" },
    { "label": "Huỷ scan", "description": "Pipeline không thể proceed" }
  ]
}
```

---

### T7 — Verifier Phát Hiện Gap Nghiêm Trọng

**Trigger:** `qa-coverage-verifier` / `qa-adversarial-verifier` phát hiện coverage gap > 50% HOẶC adversarial probe expose critical vuln

**Template:**
```json
{
  "question": "Verifier phát hiện gap nghiêm trọng: `{gap_summary}`. Verdict đề xuất: `{suggested_verdict}`. Bạn muốn xử lý thế nào?",
  "header": "Gap Critical",
  "multiSelect": false,
  "options": [
    { "label": "Thêm test cho gap (Khuyến nghị)", "description": "Regenerate test với scenarios bổ sung, re-run" },
    { "label": "Ghi nhận gap + tiếp tục", "description": "Verdict = PARTIAL, gap được note trong report" },
    { "label": "Override verdict thành PASS", "description": "⚠️ Chấp nhận rủi ro, document lý do bắt buộc" },
    { "label": "Huỷ scan", "description": "Cần redesign test approach" }
  ]
}
```

---

## 6. Do / Don't

| ✅ Do | ❌ Don't |
|------|----------|
| Tiếng Việt cho mọi user-facing text | Mix EN trong option label |
| `AskUserQuestion` khi tool available | Tự viết markdown khi có AskUserQuestion |
| Chẩn đoán trước khi hỏi | Hỏi blind "bạn muốn gì?" |
| Option "Huỷ" luôn có mặt | Force user continue |
| Status block giữ EN (`**Status:** BLOCKED`) | Dịch status → phá protocol |
| Max 3 retries rồi escalate BLOCKED | Retry vô hạn |
| Reference template bằng ID (`→ Template T3`) | Inline template content vào agent |
| Technical terms trong backticks | Dịch technical terms tạo ambiguity |

---

## 7. Integration Checklist (Maintainer)

- [ ] Claude agent header có dòng: `Load: .claude/rules/qa-scan/vi-escalation.md`
- [ ] Gemini agent prompt có block VI Escalation Rule với lệnh read `.gemini/rules/qa-scan/vi-escalation.md`
- [ ] `qa-orchestrator.md` Escalation Ladder reference rule này (không inline template)
- [ ] `install.sh` cp `rules/*.md` vào cả `.claude/rules/qa-scan/` + `.gemini/rules/qa-scan/`
- [ ] Smoke test: trigger BLOCKED → verify T1 render đúng VI
