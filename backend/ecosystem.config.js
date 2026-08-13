// PM2 process manager config — alternative to Docker for a plain VM deploy.
// `pm2 start ecosystem.config.js --env production`
//
// api: instances defaults to 1 (fork mode) for a single-VM deploy without
// Redis — automation.js/history.js/notifications.js/earnings.js hold
// module-level state (in-memory settings cache, the sweep() interval) that
// assumed a single process before this file's REDIS_URL support existed.
// Set REDIS_URL and bump instances (cluster mode requires it — see
// events/bus.js and queue.js) to run more than one; without it, running
// >1 instance means N independent automation engines racing on the same
// orders and SSE clients only seeing events from whichever instance they
// happened to connect to.
//
// worker: a separate BullMQ consumer process (src/worker.js) — only
// useful with REDIS_URL set; without it there's no queue for a separate
// process to pull from, so leave `worker` stopped (`pm2 stop worker`) in
// that configuration.
module.exports = {
  apps: [
    {
      name: 'daily-api',
      script: 'src/app.js',
      instances: process.env.REDIS_URL ? 2 : 1,
      exec_mode: process.env.REDIS_URL ? 'cluster' : 'fork',
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      watch: false,
      max_memory_restart: '400M',
      kill_timeout: 10000, // matches app.js's own graceful-shutdown deadline
      env_production: {
        NODE_ENV: 'production',
      },
    },
    {
      name: 'daily-worker',
      script: 'src/worker.js',
      instances: 2,
      exec_mode: 'fork', // worker.js manages its own BullMQ Worker concurrency internally, doesn't need PM2 cluster mode
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      watch: false,
      max_memory_restart: '300M',
      kill_timeout: 10000,
      env_production: {
        NODE_ENV: 'production',
      },
    },
  ],
};
