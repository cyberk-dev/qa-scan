/**
 * Dummy test app for QA Scan E2E testing
 * Run: bun test-app/server.ts
 * Serves: http://localhost:4000
 */

const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Test App</title></head>
<body>
  <h1>Product Detail</h1>
  <main>
    <section aria-label="Product Info">
      <h2 id="product-name">Moisturizer SPF 50</h2>
      <p>A daily moisturizer with sun protection.</p>
      <span aria-label="Price">$24.99</span>
    </section>

    <section aria-label="Ingredients">
      <h3>Ingredients Analysis</h3>
      <ul role="list" aria-label="Beneficial ingredients">
        <li>Niacinamide — Brightening</li>
        <li>Hyaluronic Acid — Hydration</li>
        <li>Vitamin E — Antioxidant</li>
      </ul>
    </section>

    <section aria-label="Actions">
      <button type="button" onclick="addToRoutine()">Add to Routine</button>
      <button type="button" onclick="analyze()">Analyze Product</button>
    </section>

    <div id="status" role="status" aria-live="polite"></div>
    <div id="analysis" hidden>
      <h3>AI Analysis</h3>
      <p>This product is suitable for daily use. SPF 50 provides excellent UV protection.</p>
    </div>
  </main>

  <script>
    function addToRoutine() {
      document.getElementById('status').textContent = 'Added to your routine!';
    }
    function analyze() {
      const btn = event.target;
      btn.disabled = true;
      btn.textContent = 'Analyzing...';
      setTimeout(() => {
        document.getElementById('analysis').hidden = false;
        btn.textContent = 'Analyze Product';
        btn.disabled = false;
        document.getElementById('status').textContent = 'Analysis complete';
      }, 1000);
    }
  </script>
</body>
</html>`;

Bun.serve({
  port: 4000,
  fetch(req) {
    const url = new URL(req.url);

    if (url.pathname === '/') {
      return new Response(html, { headers: { 'content-type': 'text/html' } });
    }

    if (url.pathname === '/api/products/123') {
      return Response.json({
        id: 123,
        name: 'Moisturizer SPF 50',
        price: 24.99,
        ingredients: [
          { name: 'Niacinamide', effect: 'Brightening' },
          { name: 'Hyaluronic Acid', effect: 'Hydration' },
          { name: 'Vitamin E', effect: 'Antioxidant' },
        ],
      });
    }

    if (url.pathname === '/api/products/123/analyze') {
      return Response.json({
        verdict: 'good',
        score: 8.5,
        summary: 'Suitable for daily use with excellent UV protection.',
      });
    }

    return new Response('Not found', { status: 404 });
  },
});

console.log('🧪 Test app running at http://localhost:4000');
