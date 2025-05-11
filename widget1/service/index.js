// ./widget1/service/index.js

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const jwksRsa = require('jwks-rsa');
const { config } = require('./config.js');

const app = express();
const PORT = 3101;

const jwks = jwksRsa({
  jwksUri: `https://login.microsoftonline.com/${config.tenantId}/discovery/v2.0/keys`
});

function getKey(header, callback) {
  jwks.getSigningKey(header.kid, function (err, key) {
    if (err) {
      console.error("Error getting signing key:", err);
      return callback(err);
    }
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

app.use(cors({
  origin: 'http://localhost:3001',
  methods: ['GET'],
  allowedHeaders: ['Authorization']
}));

app.get('/demo', (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).send("Missing token");
  }

  const token = authHeader.split(" ")[1];

  jwt.verify(token, getKey, {
    audience: config.clientId.widget1,
    issuer: `https://login.microsoftonline.com/${config.tenantId}/v2.0`,
    algorithms: ["RS256"]
  }, (err, decoded) => {
    if (err) {
      return res.status(401).send("Invalid token");
    }

    if (decoded.scp !== config.scopes.widget1.split('/').pop()) {
      return res.status(401).send("Invalid scope");
    }

    console.log("Widget1 token valid for user:", decoded.preferred_username);
    res.send("✅ Widget1 service accessed securely");
  });
});

app.listen(PORT, () => {
  console.log(`Widget1 Service running at http://localhost:${PORT}`);
});
