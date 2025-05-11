// ./portal/service/index.js

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const jwksRsa = require('jwks-rsa');
const { config } = require('./config.js');

const app = express();
const PORT = 3100;

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
  origin: 'http://localhost:3000',
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
    audience: config.clientId.portal,
    issuer: `https://login.microsoftonline.com/${config.tenantId}/v2.0`,
    algorithms: ["RS256"]
  }, (err, decoded) => {
    if (err) {
      return res.status(401).send("Invalid token");
    }

    if (decoded.scp !== config.scopes.portal.split('/').pop()) {
      return res.status(401).send("Invalid scope");
    }

    console.log("Token valid for user:", decoded.preferred_username);
    res.send("✅ Portal service accessed securely");
  });
});

app.listen(PORT, () => {
  console.log(`Portal Service running at http://localhost:${PORT}`);
});
