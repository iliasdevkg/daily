const client = require('prom-client');

// Default Node.js process metrics (CPU, heap, event loop lag, GC) plus a
// handful of app-specific ones. Exposed at GET /metrics for Prometheus to
// scrape — see monitoring/prometheus.yml.
const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry, prefix: 'daily_' });

const httpRequestDuration = new client.Histogram({
  name: 'daily_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [registry],
});

const httpRequestsTotal = new client.Counter({
  name: 'daily_http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [registry],
});

const automationActionsTotal = new client.Counter({
  name: 'daily_automation_actions_total',
  help: 'Automation rule firings, by rule',
  labelNames: ['action'],
  registers: [registry],
});

const automationErrorsTotal = new client.Counter({
  name: 'daily_automation_errors_total',
  help: 'Automation failures logged to automation_errors',
  labelNames: ['step'],
  registers: [registry],
});

const queueJobsTotal = new client.Counter({
  name: 'daily_queue_jobs_total',
  help: 'Background queue jobs, by queue and outcome',
  labelNames: ['queue', 'outcome'], // outcome: completed | failed | dead_letter
  registers: [registry],
});

const ordersCreatedTotal = new client.Counter({
  name: 'daily_orders_created_total',
  help: 'Orders created',
  registers: [registry],
});

// req.route.path (e.g. '/:id/status') keeps cardinality bounded — labeling
// by the raw URL would create a new metric series per order ID and blow up
// Prometheus's memory over time.
function httpMetricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const route = req.route?.path ? `${req.baseUrl}${req.route.path}` : req.path;
    const seconds = Number(process.hrtime.bigint() - start) / 1e9;
    const labels = { method: req.method, route, status_code: res.statusCode };
    httpRequestDuration.observe(labels, seconds);
    httpRequestsTotal.inc(labels);
  });
  next();
}

module.exports = {
  registry,
  httpMetricsMiddleware,
  automationActionsTotal,
  automationErrorsTotal,
  queueJobsTotal,
  ordersCreatedTotal,
};
