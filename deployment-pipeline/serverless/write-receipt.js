// write-receipt: simulates kk-payments writing a receipt to the staging
// bucket after a successful payment event.
const fs = require('fs');
const path = require('path');

const BUCKET_DIR = path.join(__dirname, 'kk-payments-receipts-staging');
const receipt = {
  transactionId: `txn-${Date.now()}`,
  amount: (Math.random() * 5000 + 100).toFixed(2),
  timestamp: new Date().toISOString(),
  service: 'kijanikiosk-payments',
  environment: 'staging'
};

const filename = `receipt-${receipt.transactionId}.json`;
fs.writeFileSync(path.join(BUCKET_DIR, filename), JSON.stringify(receipt, null, 2));
console.log(`kk-payments wrote receipt: ${filename}`);
