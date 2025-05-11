// ./portal/app/index.js

import { config } from './config.js';

const msalConfig = {
  auth: {
    clientId: config.clientId.portal,
    authority: `https://login.microsoftonline.com/${config.tenantId}`,
    redirectUri: "http://localhost:3000"
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false
  }
};

const msalInstance = new msal.PublicClientApplication(msalConfig);

async function signIn() {
  try {
    console.log("🔐 Signing in...");
    const loginResponse = await msalInstance.loginPopup({
      scopes: ["User.Read"],
    });

    console.log("🔐 Acquired token for graph:", loginResponse.accessToken);

    const account = loginResponse.account;
    console.log("✅ Signed in as:", account.username);

    console.log("🔐 Acquiring token for portal...");
    const tokenPortal = await msalInstance.acquireTokenSilent({
      account,
      scopes: [config.scopes.portal]
    });

    console.log("🔐 Acquired token for portal:", tokenPortal.accessToken);

    console.log("🔐 Acquiring token for widget1...");
    const tokenWidget1 = await msalInstance.acquireTokenSilent({
      account,
      scopes: [config.scopes.widget1]
    });

    console.log("🔐 Acquired token for widget1:", tokenWidget1.accessToken);

    console.log("🔐 Acquiring token for widget2...");
    const tokenWidget2 = await msalInstance.acquireTokenSilent({
      account,
      scopes: [config.scopes.widget2]
    });

    console.log("🔐 Acquired token for widget2:", tokenWidget2.accessToken);

    document.getElementById("widget1").contentWindow.postMessage(
      { type: "auth-token", token: tokenWidget1.accessToken },
      "http://localhost:3001"
    );

    document.getElementById("widget2").contentWindow.postMessage(
      { type: "auth-token", token: tokenWidget2.accessToken },
      "http://localhost:3002"
    );

    console.log("📨 Tokens sent to widgets.");

    console.log("🔐 Calling portal's own backend...");
    const response = await fetch("http://localhost:3100/demo", {
      headers: {
        Authorization: `Bearer ${tokenPortal.accessToken}`
      }
    });

    const text = await response.text();
    console.log("📦 Portal service response:", text);

    document.getElementById("portal-response").innerText = text;
  } catch (err) {
    console.error("❌ Login or token acquisition failed:", err);
  }
}

document.getElementById("signin-btn").addEventListener("click", signIn);
