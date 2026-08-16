# Serverless Receipt Chain (Week 10 Integration)

## What this is

This simulates the Week 10 serverless receipt chain requirement: kk-payments writes a receipt after a payment event, and a downstream function (kk-notifier) fires in response, processing the receipt.

## Scoping decision

No AWS account, CLI, or Serverless Framework was available in this environment during the capstone build. Rather than skip this requirement, it's implemented as a local simulation:

- `kk-payments-receipts-staging/` stands in for the S3 bucket
- `write-receipt.js` stands in for kk-payments writing a receipt object
- `kk-notifier.js` stands in for the S3-triggered Lambda function, using `fs.watch` to detect new receipt files the same way an S3 event trigger would detect a new object

## Known gap

This is not deployed to a real cloud provider. A production version would replace `fs.watch` with an actual S3 event trigger and deploy `kk-notifier` as a Lambda function via `serverless deploy`. This is documented as a known limitation in the reflection document.

## Running it

Terminal 1: `node kk-notifier.js`

Terminal 2: `node write-receipt.js`

The notifier should log the receipt details within a second of the write.
