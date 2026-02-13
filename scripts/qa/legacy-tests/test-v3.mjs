import https from 'https';

const getToken = async () => {
  return new Promise((resolve, reject) => {
    const data = "grant_type=client_credentials&client_id=e8edea94-e86f-4dc7-857e-3c5c09bb76d3&scope=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3/.default&client_secret=oyK8Q~Y-kWBebhP6c9cPCkGL0.2JUxk7ungP9bVt";
    const options = {
      hostname: "login.microsoft.com",
      path: "/b1aab053-6242-46ec-9cf8-bd02e63dd2da/oauth2/v2.0/token",
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "Content-Length": Buffer.byteLength(data) }
    };
    
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => resolve(JSON.parse(body).access_token));
    });
    req.write(data);
    req.end();
  });
};

const tryEndpoint = (token, path) => {
  return new Promise((resolve) => {
    const req = https.request({
      hostname: "learn.skillourfuture.org",
      path,
      method: "GET",
      headers: { "Authorization": `Bearer ${token}`, "ClientType": "service" }
    }, (res) => {
      console.log(`${path}: ${res.statusCode}`);
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) console.log('  Data:', body.substring(0, 200));
        resolve();
      });
    });
    req.on('error', () => resolve());
    req.end();
  });
};

const token = await getToken();
await tryEndpoint(token, '/api/v1/Courses');
await tryEndpoint(token, '/api/v2/Courses');
await tryEndpoint(token, '/api/v3/Courses');
await tryEndpoint(token, '/api/v1/organization');
await tryEndpoint(token, '/api');
await tryEndpoint(token, '/');
