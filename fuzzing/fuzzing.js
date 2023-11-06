const http = require('http');
const crypto = require("crypto");
const hostname = '0.0.0.0';
const port = 3080;

function random(to, from = 0) { 
    return Math.floor(Math.random() * (to - from + 1) + from);
}

const headers = ["Content-Type", "Proxy-Authenticate", "WWW-Authenticate", "Location"];
const server = http.createServer((req, res) => {
    let sentHeaders = [];
    const shuffledHeaders = headers.slice()
    .map(value => ({ value, sort: Math.random() }))
    .sort((a, b) => a.sort - b.sort)
    .map(({ value }) => value);
    const total = random(shuffledHeaders.length);
    for (let i = 0; i < total; i++) {
        const header = shuffledHeaders[i];
        const val = Math.random() < 0.5 ?
         crypto.randomBytes(20).toString('hex')  :
         Math.floor(Math.random() * 100);
        sentHeaders.push({ header, val });
        res.setHeader(header, val);
    }

    res.statusCode = Math.floor(Math.random() * 300 + 200);;

    res.end(`${JSON.stringify({
        statusCode: res.statusCode,
        headers: sentHeaders
    }, null, 4)}\n`);
});
server.listen(port, hostname, () => {
    console.log(`Server running at https://${hostname}:${port}/`);
});
