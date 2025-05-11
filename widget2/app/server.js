const express = require('express');
const path = require('path');
const app = express();
const PORT = 3002;

app.use(express.static(path.join(__dirname)));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Widget2 running on http://localhost:${PORT}`);
});
