/**
 * Linear Webhook Bridge — Auto-trigger QA Scan
 *
 * Receives webhooks when Linear issues move to "QA" status.
 * Validates signature, extracts issue ID, triggers qa-scan.
 *
 * Usage:
 *   bun run .agents/qa-scan/scripts/linear-webhook-bridge.ts
 *
 * Env vars:
 *   LINEAR_WEBHOOK_SECRET — HMAC secret from Linear webhook settings
 *   PORT — Server port (default: 3456)
 *
 * Expose locally:
 *   npx cloudflared tunnel --url http://localhost:3456
 */
import { Hono } from 'hono';
import { createHmac } from 'node:crypto';
import { exec } from 'node:child_process';

const app = new Hono();

// Track cooldowns: issueId → last trigger timestamp
const cooldowns = new Map<string, number>();
const COOLDOWN_MS = 300_000; // 5 minutes

/** Verify Linear webhook HMAC-SHA256 signature */
function verifySignature(rawBody: string, signature: string | undefined): boolean {
  const secret = process.env.LINEAR_WEBHOOK_SECRET;
  if (!secret || !signature) return false;
  const hmac = createHmac('sha256', secret);
  const digest = hmac.update(rawBody).digest('hex');
  return signature === digest;
}

/** Check if payload is a QA status transition */
function isQATransition(payload: any): boolean {
  return (
    payload.type === 'Issue' &&
    payload.action === 'update' &&
    payload.data?.state?.name === 'QA'
  );
}

/** Check cooldown to prevent re-triggering */
function checkCooldown(issueId: string): boolean {
  const lastTrigger = cooldowns.get(issueId);
  if (lastTrigger && Date.now() - lastTrigger < COOLDOWN_MS) {
    return false; // Still in cooldown
  }
  cooldowns.set(issueId, Date.now());
  return true;
}

// Health check
app.get('/health', (c) => c.json({ status: 'ok', service: 'qa-scan-webhook-bridge' }));

// Linear webhook endpoint
app.post('/webhook/linear', async (c) => {
  const rawBody = await c.req.text();
  const signature = c.req.header('Linear-Signature');

  // Verify signature
  if (!verifySignature(rawBody, signature)) {
    console.warn('Invalid webhook signature');
    return c.json({ error: 'Invalid signature' }, 401);
  }

  const payload = JSON.parse(rawBody);

  // Only process QA transitions
  if (!isQATransition(payload)) {
    return c.json({ status: 'ignored', reason: 'Not a QA transition' });
  }

  const issueId = payload.data?.identifier; // e.g., "SKIN-101"
  const branchName = payload.data?.branchName;

  if (!issueId) {
    return c.json({ error: 'No issue identifier' }, 400);
  }

  // Check cooldown
  if (!checkCooldown(issueId)) {
    console.log(`${issueId} — cooldown active, skipping`);
    return c.json({ status: 'cooldown', issueId });
  }

  console.log(`QA Scan triggered for ${issueId} (branch: ${branchName || 'unknown'})`);

  // Trigger qa-scan asynchronously (don't block webhook response)
  // The agent command varies per system — this is the Claude Code example
  const command = `echo "Issue ${issueId} moved to QA. Run: /qa-scan ${issueId}"`;
  exec(command, (error, stdout, stderr) => {
    if (error) console.error(`Trigger failed: ${error.message}`);
    else console.log(`Triggered: ${stdout.trim()}`);
  });

  return c.json({ status: 'triggered', issueId, branchName });
});

const port = Number(process.env.PORT) || 3456;
console.log(`QA Scan Webhook Bridge listening on port ${port}`);
console.log(`   POST /webhook/linear — Linear webhook endpoint`);
console.log(`   GET  /health — Health check`);

export default { port, fetch: app.fetch };
