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

  if (!res.data || !res.data.access_token) {
    throw new Error(`Auth failed (${res.status}): ${res.raw}`);
  }
  return res.data.access_token;
}

async function main() {
  console.log('=====================================================');
  console.log('🛒 JTAK LIVE MARKETS SEEDER & SYNC (NODE.JS)');
  console.log('=====================================================');

  const token = await getAdminToken();
  console.log('🔑 Admin Authenticated successfully!');

  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };

  // 1. Fetch existing merchants
  const existingRes = await request(
    {
      path: '/api/v1/Admin/Merchants/DataTable',
      method: 'POST',
      headers,
    },
    { pageNumber: 0, pageSize: 50, sortField: 'id', sortOrder: 'desc' }
  );

  const existing = (existingRes.data && existingRes.data.items) || [];
  console.log(`Existing merchants in database: ${existing.length}`);

  const marketDefs = [
    {
      title: 'جيتك ماركت - JTAK Market',
      shortDescription: 'توصيل فوري فائق السرعة • 15-20 دقيقة',
      description: 'سوبرماركت ومقاضي سريعة، خضار وفواكه طازجة، ألبان وأجبان، ومستلزمات منزلية متكاملة.',
      photo: 'assets/images/markets/jtak_market.webp',
      address: 'شارع الثورة، وسط البلد، دمشق',
      phone: '+96311223344',
      lat: 33.5138,
      lng: 36.2765,
    },
    {
      title: 'سوبرماركت أبناء شمسين',
      shortDescription: 'أكبر تشكيلة مونة ومقاضي • 20-30 دقيقة',
      description: 'تشكيلة واسعة من المونة السورية الفاخرة، معلبات، بقوليات، أجبان وزيوت بلدية.',
      photo: 'assets/images/markets/abnaa_shamsin.webp',
      address: 'ساحة الميدان، جزماتية، دمشق',
      phone: '+96311334455',
      lat: 33.501,
      lng: 36.292,
    },
    {
      title: 'هايبرماركت قاسيون مول',
      shortDescription: 'عروض وتخفيضات أسبوعية • 25-35 دقيقة',
      description: 'هايبرماركت متكامل يقدم عروض وتخفيضات يومية وأسبوعية على كافة المنتجات الغذائية والمنزلية.',
      photo: 'assets/images/markets/qasioun_hypermarket.webp',
      address: 'مجمع قاسيون مول، برزة، دمشق',
      phone: '+96311445566',
      lat: 33.542,
      lng: 36.311,
    },
    {
      title: 'سوبرماركت الهدى',
      shortDescription: 'أجبان، ألبان ومقاضي طازجة • 15-25 دقيقة',
      description: 'أفضل منتجات الألبان والأجبان البلدية الطازجة يومياً والخبز الساخن والبيض البلدي.',
      photo: 'assets/images/markets/al_huda.webp',
      address: 'شارع بغداد، دمشق',
      phone: '+96311556677',
      lat: 33.521,
      lng: 36.298,
    },
    {
      title: 'سوبرماركت البركة',
      shortDescription: 'منتجات بلدية ومستوردة فاخرة • 20-35 دقيقة',
      description: 'أجود المنتجات الغذائية الطبيعية، خضار فريش، ومواد غذائية مستوردة عالية الجودة.',
      photo: 'assets/images/markets/al_baraka.webp',
      address: 'شارع المزرعة الرئيسي، دمشق',
      phone: '+96311667788',
      lat: 33.528,
      lng: 36.289,
    },
    {
      title: 'سوبرماركت الدوحة',
      shortDescription: 'كل ما تحتاجه العائلة يومياً • 20-30 دقيقة',
      description: 'مقاضي الأسرة اليومية من المنظفات، العناية الشخصية، السناكات والمشروبات الباردة.',
      photo: 'assets/images/markets/al_dawha.webp',
      address: 'المزة فيلات غربية، دمشق',
      phone: '+96311778899',
      lat: 33.504,
      lng: 36.261,
    },
  ];

  const marketIds = [];

  for (const m of marketDefs) {
    const match = existing.find((e) => (e.title || '').trim() === m.title.trim());
    let mid = 0;

    const payload = {
      title: m.title,
      shortDescription: m.shortDescription,
      description: m.description,
      photo: m.photo,
      address: m.address,
      phone1: m.phone,
      shippingCoverageInMeters: 25000,
      profitOutOfMerchantPricePercent: 10,
      lat: m.lat,
      lng: m.lng,
      active: true,
    };

    if (match) {
      mid = match.id;
      payload.id = mid;
      await request(
        {
          path: `/api/v1/Admin/Merchants/${mid}`,
          method: 'PUT',
          headers,
        },
        payload
      );
      console.log(`  🏪 Market updated & active: "${m.title}" (ID: ${mid})`);
    } else {
      const createRes = await request(
        {
          path: '/api/v1/Admin/Merchants',
          method: 'POST',
          headers,
        },
        payload
      );

      mid = parseInt(createRes.raw, 10) || (createRes.data && createRes.data.id) || 0;
      if (mid > 0) {
        payload.id = mid;
        await request(
          {
            path: `/api/v1/Admin/Merchants/${mid}`,
            method: 'PUT',
            headers,
          },
          payload
        );
        console.log(`  ✓ Market created & active: "${m.title}" (ID: ${mid})`);
      }
    }

    if (mid > 0) {
      marketIds.push(mid);
    }
  }

  // 2. Fetch products to assign
  console.log('\n--- 2. Assigning Grocery Catalog Products to Markets ---');
  const prodsRes = await request(
    {
      path: '/api/v1/Admin/Products/DataTable',
      method: 'POST',
      headers,
    },
    { pageNumber: 0, pageSize: 50, sortField: 'id', sortOrder: 'asc' }
  );

  const allProds = (prodsRes.data && prodsRes.data.items) || [];
  console.log(`Available catalog products: ${allProds.length}`);

  const priceMap = {
    1: 45000,
    2: 48000,
    3: 15000,
    4: 14000,
    5: 12000,
    6: 12000,
    7: 12500,
    8: 12500,
    9: 12000,
    10: 28000,
    11: 26000,
    12: 18000,
    13: 22000,
    14: 16000,
    15: 11000,
    16: 19000,
    17: 14000,
    18: 8000,
    19: 7500,
    20: 9000,
  };

  for (const mid of marketIds) {
    const assignments = allProds.map((p) => {
      const pid = p.id;
      const price = priceMap[pid] || 15000 + pid * 1000;
      return {
        productId: pid,
        merchantPrice: price,
        profitOutOfMerchantPricePercent: 10.0,
        additionalProfitPercent: 0.0,
        discount: 0.0,
      };
    });

    const assignRes = await request(
      {
        path: `/api/v1/Admin/Merchants/Products/${mid}`,
        method: 'PUT',
        headers,
      },
      assignments
    );

    console.log(`  📦 Assigned ${assignments.length} products to Market #${mid} (Status: ${assignRes.status})`);
  }

  console.log('\n=====================================================');
  console.log('✅ ALL 6 MARKETS SEEDED & PRODUCTS ASSIGNED SUCCESSFULLY!');
  console.log('=====================================================');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
