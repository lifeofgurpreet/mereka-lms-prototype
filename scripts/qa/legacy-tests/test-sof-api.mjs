import https from 'https';

const getToken = () => {
  return new Promise((resolve, reject) => {
    const data = "grant_type=client_credentials&client_id=e8edea94-e86f-4dc7-857e-3c5c09bb76d3&scope=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3/.default&client_secret=oyK8Q~Y-kWBebhP6c9cPCkGL0.2JUxk7ungP9bVt";
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
      hostname: "learn.skillourfuture.org",
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
        console.log('Body length:', body.length);
        console.log('Body:', body.substring(0, 500));
        resolve(body);
      });
    });
    req.on('error', reject);
    req.end();
  });
};

const token = await getToken();
console.log('Got skillourfuture token');
await callAPI(token);
