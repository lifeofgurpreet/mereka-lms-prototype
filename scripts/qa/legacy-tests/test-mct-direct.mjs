import https from 'https';

const getToken = async () => {
  return new Promise((resolve) => {
    const data = "grant_type=client_credentials&client_id=e8edea94-e86f-4dc7-857e-3c5c09bb76d3&scope=api://e8edea94-e86f-4dc7-857e-3c5c09bb76d3/.default&client_secret=oyK8Q~Y-kWBebhP6c9cPCkGL0.2JUxk7ungP9bVt";
    const req = https.request({
      hostname: "login.microsoft.com",
      path: "/b1aab053-6242-46ec-9cf8-bd02e63dd2da/oauth2/v2.0/token",
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "Content-Length": Buffer.byteLength(data) }
    }, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => resolve(JSON.parse(body).access_token));
    });
    req.write(data);
    req.end();
  });
};

const token = await getToken();
console.log('Testing mctindonesia.azurewebsites.net...');
const req = https.request({
  hostname: "mctindonesia.azurewebsites.net",
  path: "/api/v1/Courses?page=1&pageSize=5",
  method: "GET",
  headers: { "Authorization": `Bearer ${token}`, "ClientType": "service" }
}, (res) => {
  console.log('Status:', res.statusCode);
  console.log('Headers:', JSON.stringify(res.headers, null, 2));
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    if (body) console.log('Body:', body.substring(0, 500));
  });
});
req.end();
