const express = require('express');
const app = express();

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'kijanikiosk-payments' });
});

function startServer(port = 3000) {
  return app.listen(port, () => {
    console.log(`kijanikiosk-payments listening on port ${port}`);
  });
}

if (require.main === module) {
  startServer();
}

module.exports = { app, startServer };
