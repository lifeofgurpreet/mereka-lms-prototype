import https from 'https';

const getToken = () => {
  return new Promise((resolve, reject) => {
    // Skillourfuture app requesting token for itself
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
        if (json.access_token) {
          const payload = JSON.parse(Buffer.from(json.access_token.split('.')[1], 'base64').toString());
          console.log('Token claims:', JSON.stringify({aud: payload.aud, appid: payload.appid, roles: payload.roles}, null, 2));
          resolve(json.access_token);
        } else {
          console.log('Token error:', json);
          reject(new Error('No token'));
        }
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
      path: "/api/v1/Courses?page=1&pageSize=5",
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "ClientType": "service"
      }
    };
    
    const req = https.request(options, (res) => {
      console.log('API Status:', res.statusCode);
      if (res.statusCode === 200) {
        let body = '';
        res.on('data', (chunk) => body += chunk);
        res.on('end', () => {
          const data = JSON.parse(body);
          console.log('Success! Courses:', data.length || 'N/A');
          console.log('First course:', JSON.stringify(data[0] || data, null, 2).substring(0, 300));
          resolve(body);
        });
      } else {
        console.log('WWW-Authenticate:', res.headers['www-authenticate']);
        resolve(null);
      }
    });
    req.on('error', reject);
    req.end();
  });
};

const token = await getToken();
await callAPI(token);
