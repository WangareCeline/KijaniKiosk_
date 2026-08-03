import express from 'express';

const app = express();
const PORT: number = process.env.PORT ? parseInt(process.env.PORT) : 3001;
const VERSION: string = process.env.VERSION || 'unknown';

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', version: VERSION, service: 'kijanikiosk-payments' });
});

app.listen(PORT, () => {
  console.log(`kijanikiosk-payments ${VERSION} listening on port ${PORT}`);
});
