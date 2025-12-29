import https from 'https';

const getToken = () => {
  return new Promise((resolve, reject) => {
    const data = "grant_type=client_credentials&client_id=f16cdc2f-c1a6-417f-992b-4370e81775e8&scope=api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4/.default&client_secret=uM58Q~z3CaKcP1gp2khd6_-VfCWuL_JEJyEeocXh";
    const options = {
      hostname: "login.microsoft.com",
      path: "/b1aab053-6242-46ec-9cf8-bd02e63dd2da/oauth2/v2.0/token",
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": Buffer.byteLength(data)
      }
    };
    
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        const json = JSON.parse(body);
        resolve(json.access_token);
      });
    });
    req.write(data);
    req.end();
  });
};

const callAPI = (token) => {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "undp.biji-biji.com",
      path: "/api/v1/organization?page=1&pageSize=5",
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "ClientType": "service"
      }
    };
    
    const req = https.request(options, (res) => {
      console.log('Status:', res.statusCode);
      console.log('Headers:', JSON.stringify(res.headers, null, 2));
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        console.log('Body:', body);
        resolve(body);
      });
    });
    req.on('error', reject);
    req.end();
  });
};

const token = await getToken();
console.log('Got token');
await callAPI(token);
