/**
 * Render Stub API Server
 * Required packages: express, child_process (builtin)
 *
 * Usage: node render_stub.js [--port 3001] [--batch_generate]
 */

const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(express.json());

const PORT = process.argv.includes('--port')
  ? parseInt(process.argv[process.argv.indexOf('--port') + 1])
  : 3001;

const PYTHON_ENGINE = path.join(__dirname, '..', '..', 'emoji_avatar_engine.py');

// Check if Python engine exists
const hasPythonEngine = fs.existsSync(PYTHON_ENGINE);

/**
 * Render single frame
 */
app.post('/render', async (req, res) => {
  const params = req.body;

  if (hasPythonEngine) {
    // Call Python engine
    const args = [
      PYTHON_ENGINE,
      '--emoji', params.emoji || 'smile',
      '--seconds', '0.1',
      '--fps', '1',
      '--out', '/tmp/render_output.png',
      '--dry_run'
    ];

    const python = spawn('python', args);

    let output = '';
    python.stdout.on('data', (data) => { output += data; });
    python.stderr.on('data', (data) => { output += data; });

    python.on('close', (code) => {
      if (code === 0) {
        res.json({
          success: true,
          message: 'Rendered via Python engine',
          params: params
        });
      } else {
        res.status(500).json({ error: 'Render failed', output });
      }
    });
  } else {
    // Simulate render (canvas fallback)
    res.json({
      success: true,
      message: 'Simulated render (Python engine not available)',
      params: params,
      simulated: true
    });
  }
});

/**
 * Render animation sequence
 */
app.post('/render-sequence', async (req, res) => {
  const { emoji, seconds, fps, computeHeavy } = req.body;

  if (hasPythonEngine) {
    const outputPath = `/tmp/animation_${Date.now()}.mp4`;
    const args = [
      PYTHON_ENGINE,
      '--emoji', emoji || 'smile',
      '--seconds', String(seconds || 3),
      '--fps', String(fps || 30),
      '--out', outputPath
    ];

    if (computeHeavy) {
      args.push('--compute_heavy');
    }

    const python = spawn('python', args);

    python.on('close', (code) => {
      if (code === 0 && fs.existsSync(outputPath)) {
        res.json({ success: true, path: outputPath });
      } else {
        res.status(500).json({ error: 'Animation render failed' });
      }
    });
  } else {
    res.json({
      success: true,
      message: 'Simulated sequence render',
      frames: Math.floor((seconds || 3) * (fps || 30))
    });
  }
});

/**
 * Batch generate endpoint (heavy compute)
 */
app.post('/batch-generate', async (req, res) => {
  const { count, computeHeavy } = req.body;
  const n = count || 10;

  if (!hasPythonEngine) {
    return res.status(400).json({
      error: 'Python engine required for batch generation'
    });
  }

  const args = [
    PYTHON_ENGINE,
    '--batch_generate', String(n)
  ];

  if (computeHeavy) {
    args.push('--compute_heavy');
  }

  console.log(`Starting batch generation of ${n} animations...`);

  const python = spawn('python', args);

  python.stdout.on('data', (data) => {
    console.log(`[batch] ${data}`);
  });

  python.stderr.on('data', (data) => {
    console.error(`[batch error] ${data}`);
  });

  python.on('close', (code) => {
    if (code === 0) {
      res.json({
        success: true,
        message: `Generated ${n} animations`,
        outputDir: 'batch_outputs/'
      });
    } else {
      res.status(500).json({ error: 'Batch generation failed' });
    }
  });
});

/**
 * Generate thumbnails
 */
app.post('/generate-thumbs', async (req, res) => {
  if (!hasPythonEngine) {
    return res.status(400).json({
      error: 'Python engine required'
    });
  }

  const python = spawn('python', [PYTHON_ENGINE, '--generate_thumbs']);

  python.on('close', (code) => {
    if (code === 0) {
      res.json({ success: true, message: 'Thumbnails generated' });
    } else {
      res.status(500).json({ error: 'Thumbnail generation failed' });
    }
  });
});

/**
 * Health check
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    pythonEngine: hasPythonEngine,
    timestamp: new Date().toISOString()
  });
});

// CORS for development
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

app.listen(PORT, () => {
  console.log(`Render API server running on port ${PORT}`);
  console.log(`Python engine available: ${hasPythonEngine}`);
});
