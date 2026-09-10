const https = require('https');

const API_IP = '172.67.149.162';
const API_HOST = 'api.jtak.app';

function request(options, data) {
  return new Promise((resolve, reject) => {
    const reqOptions = {
      host: API_IP,
      servername: API_HOST,
      port: 443,
      path: options.path,
      method: options.method || 'GET',
      headers: {
        Host: API_HOST,
        ...(options.headers || {}),
      },
      rejectUnauthorized: false,
    };

    const req = https.request(reqOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed, raw: body });
        } catch (_) {
          resolve({ status: res.statusCode, raw: body });
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    req.end();
  });
}

async function main() {
  // Test search with Lat/Lng Damascus without category
  const res = await request(
    {
      path: '/api/v1/Customer/Products/Search',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      lat: 33.5138,
      lng: 36.2765,
      page: 0,
      take: 20,
    }
  );

  console.log(`Search result status: ${res.status}`);
  const items = res.data || [];
  console.log(`Search returned ${items.length} products:`);
  items.slice(0, 10).forEach((p) => {
    console.log(`  [#${p.id}] ${p.title} | Price: ${p.finalPrice} | MerchantId: ${p.merchantId} | Cat: ${p.categoryId}`);
  });
}

main().catch(console.error);
