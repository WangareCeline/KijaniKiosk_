const { app } = require('./index');
const request = require('supertest');

test('GET /health returns 200 and service status', async () => {
  const res = await request(app).get('/health');
  expect(res.statusCode).toBe(200);
  expect(res.body.status).toBe('broken-on-purpose');
});
