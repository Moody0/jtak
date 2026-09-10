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
        try { resolve({ status: res.statusCode, data: JSON.parse(body) }); }
        catch (_) { resolve({ status: res.statusCode, raw: body }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(typeof data === 'string' ? data : JSON.stringify(data));
    req.end();
  });
}

async function getAdminToken() {
  const form = 'grant_type=password&username=admin@jtak.app&password=P@ssw0rd&scope=offline_access';
  const res = await request(
    {
      path: '/connect/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(form),
      },
    },
    form
  );
  return res.data.access_token;
}

async function main() {
  const token = await getAdminToken();
  const res = await request(
    {
      path: '/api/v1/Admin/Products/DataTable',
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    },
    { pageNumber: 0, pageSize: 5, sortField: 'id', sortOrder: 'desc' }
  );

  console.log('Sample Products from Admin:');
  console.log(JSON.stringify(res.data.items, null, 2));
}

main().catch(console.error);
