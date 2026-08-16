// kk-notifier: simulates a serverless function triggered by writes to the
// kk-payments-receipts-staging bucket. In production this would be an
// S3-triggered Lambda; here it watches a local directory standing in for
// that bucket, for local demonstration without live AWS credentials.
const fs = require('fs');
const path = require('path');

const BUCKET_DIR = path.join(__dirname, 'kk-payments-receipts-staging');

console.log(`kk-notifier watching ${BUCKET_DIR} for new receipts...`);

fs.watch(BUCKET_DIR, (eventType, filename) => {
  if (eventType === 'rename' && filename && filename.endsWith('.json')) {
    const filePath = path.join(BUCKET_DIR, filename);
    if (fs.existsSync(filePath)) {
      const receipt = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      console.log(`[kk-notifier] Receipt chain fired for ${filename}`);
      console.log(`  Transaction: ${receipt.transactionId}`);
      console.log(`  Amount: ${receipt.amount}`);
      console.log(`  Timestamp: ${receipt.timestamp}`);
      console.log(`  Status: receipt processed successfully`);
    }
  }
});
