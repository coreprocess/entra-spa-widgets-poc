window.addEventListener("message", async (event) => {
  if (event.origin !== "http://localhost:3000") return; // Basic origin check

  if (event.data?.type === "auth-token") {
    const token = event.data.token;
    console.log("Widget1 received token:", token);

    try {
      const response = await fetch("http://localhost:3101/demo", {
        headers: {
          Authorization: `Bearer ${token}`
        }
      });

      const data = await response.text();
      document.getElementById("token-status").innerText = data;
    } catch (err) {
      console.error("Widget1 API call failed:", err);
      document.getElementById("token-status").innerText = "API call failed";
    }
  }
});
