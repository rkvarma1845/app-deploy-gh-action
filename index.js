import express from 'express'
import os from 'os'

const app = express()
const PORT = process.env.PORT ?? 8080
const ENV = process.env.NODE_ENV ?? 'development'

// ─── Middleware ───────────────────────────────────────────
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Request logger
app.use((req, res, next) => {
    const timestamp = new Date().toISOString()
    console.log(`[${timestamp}] ${req.method} ${req.url}`)
    next()
})

// ─── Routes ───────────────────────────────────────────────
app.get('/', (req, res) => {
    return res.status(200).json({
        success: true,
        message: 'Hello from the server v2 deploy',
        version: process.env.npm_package_version ?? '1.0.0',
    })
})

// Health check route
app.get('/health', (req, res) => {
    return res.status(200).json({
        success: true,
        status: 'ok',
        environment: ENV,
        uptime: `${Math.floor(process.uptime())}s`,
        hostname: os.hostname(),
        timestamp: new Date().toISOString(),
    })
})

// ─── 404 Handler ──────────────────────────────────────────
app.use((req, res) => {
    return res.status(404).json({
        success: false,
        message: `Route '${req.url}' not found`,
    })
})

// ─── Global Error Handler ─────────────────────────────────
app.use((err, req, res, next) => {
    console.error(`[ERROR] ${err.message}`)
    return res.status(err.status ?? 500).json({
        success: false,
        message: err.message ?? 'Internal Server Error',
    })
})

// ─── Start Server ─────────────────────────────────────────
app.listen(PORT, () => {
    console.log('─────────────────────────────────────')
    console.log(`🚀 Server running on PORT ${PORT}`)
    console.log(`🌍 Environment : ${ENV}`)
    console.log(`🔗 URL         : http://localhost:${PORT}`)
    console.log(`❤️  Health      : http://localhost:${PORT}/health`)
    console.log('─────────────────────────────────────')
})