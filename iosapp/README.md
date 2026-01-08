# Komal - Therapeutic SEL App for Children

**Knowledge-Oriented Mental-Health & Affective Learning**

Hyper-personalized virtual humans for child therapy and social-emotional learning (SEL) for ages 3.5-15.

## 🎯 What is Komal?

Komal is a mobile and web-based application that provides:

- **Virtual avatars** for therapeutic and SEL interventions
- **AI-based games** and interactive modules for attention, concentration, emotional regulation, and social skills
- **Parent/guardian tracking** of behavioral and engagement metrics using eye-tracking, voice tracking, touch-tracking, and micro-expression analysis
- **Dashboards and reports** summarizing child's interaction, engagement patterns, and progress over time

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build
```

## 📁 Project Structure

```
komal/
├── ARCHITECTURE.md           # Complete system architecture
├── DATABASE_SCHEMA.md        # Database schema & data models
├── ML_README.md              # ML infrastructure docs
├── README.md                 # This file
│
├── src/
│   ├── contexts/
│   │   └── AuthContext.jsx   # Authentication & profile management
│   │
│   ├── services/
│   │   └── db.js            # IndexedDB service (offline-first)
│   │
│   ├── tracking/            # Core ML tracking systems
│   │   ├── eyeTracking.js   # Eye tracking & attention metrics
│   │   ├── touchTracking.js # Touch patterns & motor behavior
│   │   └── voiceTracking.js # Voice analysis & confidence
│   │
│   ├── hooks/
│   │   ├── useSession.js        # Unified session tracking
│   │   ├── useFaceDetection.js  # Micro-expression analysis
│   │   ├── useMLWorker.js       # ML Web Worker interface
│   │   └── ...
│   │
│   ├── components/
│   │   ├── avatar/
│   │   │   └── Avatar.jsx       # Virtual avatar system
│   │   ├── common/
│   │   │   └── MoodChecker.jsx  # Emoji mood selector
│   │   └── ...
│   │
│   ├── pages/
│   │   ├── Auth/
│   │   │   └── SignIn.jsx       # Authentication (phone/email/Apple)
│   │   ├── Learner/
│   │   │   └── Home.jsx         # Child interface
│   │   └── Parent/
│   │       └── Dashboard.jsx    # Parent analytics
│   │
│   ├── ml/                      # ML infrastructure
│   ├── utils/ml/                # Battery management, caching
│   └── workers/                 # Web Workers for background ML
│
└── public/
    └── models/                  # ONNX models (to be added)
```

## 🎨 Core Features Implemented

### ✅ Authentication & Profiles
- **Sign In/Up**: Phone (OTP), Email, Apple Sign-In, Guest mode
- **Languages**: English, Hindi, Bengali
- **Learner Profiles**: Age, gender, focus areas, sensitivity settings
- **Parent Profiles**: PIN/Face ID protected access
- **Session Management**: Auto-login within 20 minutes

### ✅ Client-Side ML Tracking (Battery-Efficient)

#### 1. Eye Tracking (`src/tracking/eyeTracking.js`)
- **Attention Score**: % time fixating on relevant content
- **Concentration Stability**: Saccade frequency analysis
- **Social Gaze Index**: Eye contact with avatar
- **Exploration vs Avoidance**: Comfort with stimuli
- **Gaze Heatmaps**: Visual attention patterns

#### 2. Micro-Expression Analysis
- **7 Emotions**: Happy, Sad, Angry, Fearful, Surprised, Disgusted, Neutral
- **Affect Diversity**: Range of emotions shown
- **Frustration Tolerance**: Recovery time from negative affect
- **Empathy Response**: Reaction to avatar distress

#### 3. Touch Tracking (`src/tracking/touchTracking.js`)
- **Goal-Directed Accuracy**: Successful vs random taps
- **Hesitation Detection**: Anxiety, compulsive checking
- **Touch Pressure**: Impulsivity vs control (3D Touch on iOS)
- **Self-Soothing Gestures**: Stress-reduction behaviors
- **Touch Heatmaps**: Interaction hotspots

#### 4. Voice Tracking (`src/tracking/voiceTracking.js`)
- **Vocal Activity**: % of session speaking
- **Pitch Variation**: Emotional arousal indicators
- **Speech Rate**: Confidence, anxiety markers
- **Pause Analysis**: Hesitation patterns
- **Confidence Score**: Derived from voice characteristics

### ✅ Session Management
- **Unified Tracking**: Combines all 4 tracking systems
- **Engagement Quality**: 0-10 score based on all metrics
- **Offline Storage**: IndexedDB for privacy
- **Background Sync**: Uploads when online
- **Real-time Metrics**: Live tracking during session

### ✅ Virtual Avatar System
- **Animal Avatars**: Bear, Cat, Dog, Rabbit
- **Human Avatars**: Boy, Girl, Teacher
- **Emotions**: Neutral, Happy, Excited, Sad, Surprised, Thinking
- **Speech Bubbles**: Animated messages
- **Talking Animation**: Visual feedback

### ✅ User Interfaces

#### Learner Interface
- Child-friendly design with large touch targets
- 5 emoji mood checker
- Focus areas: Social, Language, Cognitive, Emotional, Life Skills
- Real-time engagement display
- Avatar interaction

#### Parent Dashboard
- Weekly statistics
- Session history
- Engagement quality tracking
- Multi-learner support
- Email reports (placeholder)

## 🔋 Battery Optimization

All ML tracking is battery-efficient:

- **Adaptive FPS**: 10 FPS charging → 5 FPS low battery
- **Battery API**: Automatic throttling based on level
- **Web Workers**: Background processing doesn't block UI
- **Single-threaded WASM**: More efficient than multi-thread
- **Target**: < 5% battery drain per 30min session

## 🔒 Privacy & Security

- ✅ **All ML runs client-side** - no video/audio sent to servers
- ✅ **Encrypted local storage** (IndexedDB)
- ✅ **PIN/Face ID** for parent access
- ✅ **COPPA compliant** design
- ✅ **GDPR ready** - data export & deletion

## 📱 Device Compatibility

| Feature | iOS Safari | Android Chrome | Desktop |
|---------|-----------|----------------|---------|
| Face Detection | ✅ (16+) | Fallback | Fallback |
| Eye Tracking | ✅ | ✅ | ✅ |
| Touch Tracking | ✅ | ✅ | Mouse events |
| Voice Tracking | ✅ | ✅ | ✅ |
| 3D Touch | ✅ | ❌ | ❌ |
| Battery API | ❌ | ✅ | ✅ |
| IndexedDB | ✅ | ✅ | ✅ |

## 🎯 SEL Framework (Harvard CASEL)

Tracks 5 core competencies:

1. **Self-Awareness**: Recognizing emotions, identifying triggers
2. **Self-Management**: Emotion regulation, impulse control, coping
3. **Social Awareness**: Empathy, perspective-taking, social cues
4. **Relationship Skills**: Communication, cooperation, conflict resolution
5. **Responsible Decision-Making**: Problem-solving, evaluating consequences

## 📊 Parent Reports

### Session Snapshot (After Each Session)
- Completed/Total tasks
- Engagement quality (0-10)
- Key skill practiced
- Highlights and observations
- Quick metrics (attention, emotion, touch, voice)

### Weekly Progress Report
- Trends over 7 days
- Improvement areas
- Home practice suggestions
- Next tiny goals

### Extended Monthly Report
- Detailed analytics across all domains
- Eye-tracking patterns
- Micro-expression analysis
- Touch and voice metrics
- SEL progress across 5 domains
- Clinician review zone
- Escalation flags

## 🚧 Next Steps for Developer

### Phase 1: Complete Core Features
- [ ] Profile creation/editing UI
- [ ] Settings management
- [ ] Focus area selection flow
- [ ] Guest mode implementation

### Phase 2: Enhance ML Tracking
- [ ] Integrate WebGazer.js for accurate eye tracking
- [ ] Add ONNX models for emotion recognition
- [ ] Implement speech recognition (optional)
- [ ] Calibration flows for eye tracking

### Phase 3: Build Activity Modules
- [ ] Social skills games
- [ ] Emotion recognition activities
- [ ] Language practice modules
- [ ] Cognitive development exercises
- [ ] Life skills simulations

### Phase 4: Reports & Analytics
- [ ] Report generation engine
- [ ] PDF export
- [ ] Email delivery
- [ ] SEL metrics calculation
- [ ] Trend analysis
- [ ] Clinician notes

### Phase 5: Backend Integration
- [ ] AWS Cognito auth
- [ ] DynamoDB data sync
- [ ] S3 for assets
- [ ] Lambda functions
- [ ] API Gateway

### Phase 6: Testing & Polish
- [ ] Test on real iOS devices
- [ ] Test on Android devices
- [ ] Accessibility audit
- [ ] Performance optimization
- [ ] Battery drain testing
- [ ] User testing with children

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete system architecture and design
- **[DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)** - Data models and storage strategy
- **[ML_README.md](ML_README.md)** - ML infrastructure and battery optimization

## 🛠 Technology Stack

**Frontend:**
- React 19
- Material-UI v7
- Framer Motion
- React Router v7
- React Native (Expo) for mobile customizer

**ML & Analytics:**
- ONNX Runtime Web / WASM
- TensorFlow Lite (on-device)
- PyTorch (training)
- Optuna (hyperparameter tuning)
- scikit-learn (preprocessing)
- Web Audio API
- Touch/Pointer Events
- Battery API

**Storage:**
- IndexedDB (client-side)
- DynamoDB (cloud backup)
- Redis (caching, secure KV)
- Supabase (aggregated analytics)

**Infrastructure:**
- Docker + Kubernetes
- SLURM (HPC training)
- AWS Spot Instances
- GitHub Actions CI/CD

**Backend:**
- AWS Cognito
- AWS Lambda
- AWS API Gateway
- AWS S3
- AWS DynamoDB
- FastAPI (inference services)

---

## 📂 ML Scripts & Pipelines (90+ Scripts)

The `scripts/` directory contains production-ready pipelines for training, optimization, and deployment. Here's what's implemented:

### Core Training & Hyperparameter Tuning

| Script | Purpose | Key Techniques |
|--------|---------|----------------|
| `optuna_hpo_distributed.py` | Distributed hyperparameter search | Optuna TPE sampler, Hyperband pruning, PostgreSQL storage |
| `train_emotion_classifier.py` | 7-emotion classifier | MobileNetV3, FER2013 + AffectNet datasets, ~72% accuracy |
| `train_attention_model.py` | Gaze-based attention scoring | MediaPipe landmarks, LSTM sequence model |
| `train_voice_confidence.py` | Voice confidence estimation | OpenSMILE features, pitch/energy analysis |
| `continual_fine_tuner.py` | Online learning with drift detection | Elastic weight consolidation, KS drift tests |
| `federated_aggregator.py` | Privacy-preserving federated learning | FedAvg, secure aggregation placeholders |
| `curriculum_sampler.py` | Curriculum learning | Competence-based sampling, anti-curriculum support |
| `knowledge_distillation_trainer.py` | Model compression | Soft targets, temperature scaling, 4-8x compression |

### Dataset & Feature Engineering

| Script | Purpose | Key Techniques |
|--------|---------|----------------|
| `dataset_ingestion.py` | Raw data to feature store | Parquet output, schema validation |
| `audio_feature_extractor.py` | Voice/audio processing | MFCC, spectral features, chunked processing |
| `video_frame_sampler.py` | Smart frame extraction | Scene detection, quality filtering |
| `embedding_generator.py` | Dense embeddings | SentenceTransformers, CLIP, batched inference |
| `multimodal_feature_fuser.py` | Cross-modal fusion | Late fusion, attention-based combination |
| `synthetic_augmentor.py` | Data augmentation | Mixup, cutout, spec augment, time warping |
| `missing_data_extrapolate_service.py` | Imputation service | Kalman smoothing, Transformer-based, hybrid |

### Model Optimization & Compression

| Script | Purpose | Key Techniques |
|--------|---------|----------------|
| `quantize_for_mobile.py` | 8-bit quantization | TFLite dynamic range, INT8 calibration |
| `onnx_exporter.py` | PyTorch to ONNX | Operator fusing, shape inference |
| `prune_model.py` | Structured pruning | L1-unstructured, iterative magnitude |
| `knowledge_distillation_trainer.py` | Teacher-student distillation | KL divergence, soft labels |
| `sparse_embedding_compressor.py` | Embedding compression | Product quantization, Huffman coding |
| `on_device_pruner.py` | Online pruning | Magnitude-based, sparsity scheduling |
| `quant_profile_generator.py` | Calibration datasets | Representative samples, coverage metrics |

### Deployment & Inference

| Script | Purpose | Key Techniques |
|--------|---------|----------------|
| `batch_inference_service.py` | Batch predictions | Async processing, GPU batching |
| `streaming_inference.py` | Real-time inference | WebSocket, chunked audio |
| `model_versioning_registry.py` | Model registry | Semantic versioning, A/B testing support |
| `ab_test_allocator.py` | Traffic splitting | Deterministic hashing, gradual rollout |
| `edge_delegate_selector.py` | Hardware delegation | GPU/NPU/CPU runtime selection |
| `lazy_model_loader.py` | Memory optimization | Shard-based lazy loading, LRU eviction |

### Cost Optimization (30 Scripts)

These scripts focus on reducing cloud spend, bandwidth, and compute costs:

| Script | Purpose | Savings Target |
|--------|---------|----------------|
| `delta_ota_patcher.py` | Binary diff updates | 80-95% bandwidth reduction |
| `model_diff_deployer.sh` | CI delta builder | Automated diff generation |
| `embedding_cache_service.py` | LRU + LSH dedup | 50%+ compute reduction |
| `adaptive_fidelity_scheduler.py` | Dynamic FPS/resolution | Battery-aware throttling |
| `spot_training_scheduler.py` | Spot instance training | 60-80% cost vs on-demand |
| `cheap_simulation_generator.py` | Procedural data gen | Reduce real data needs |
| `fifo_upload_compressor.py` | Zstd + encryption | 60-80% upload reduction |
| `delta_checkpointing.py` | Incremental checkpoints | 70-90% storage reduction |
| `warm_cache_prefetcher.py` | Predictive caching | Reduced cold starts |
| `low_power_inference_mode.py` | Energy budgeting | <5% battery per session |
| `cdn_asset_optimizer.py` | WebP/AVIF/LQIP | 40-60% image bandwidth |
| `delta_sync_client.py` | Rsync-like sync | Minimal transfer |
| `batch_metrics_aggregator.py` | Telemetry batching | 90% upload reduction |
| `cost_simulator_for_planning.py` | Infra cost modeling | Budget forecasting |
| `lite_model_ab_test.py` | Privacy-preserving A/B | Differential privacy |
| `gradual_rollout_controller.py` | Cost-aware deployment | Threshold monitoring |
| `billing_and_quota_guard.py` | Spend monitoring | Auto-throttling + alerts |
| `adaptive_model_resolution.py` | Complexity routing | Route simple inputs to tiny models |
| `client_prefetch_policy_generator.py` | Per-device budgets | Battery/network aware |
| `cheap_validation_sampler.py` | Core-set selection | K-center, herding algorithms |

### Security & Compliance

| Script | Purpose | Compliance |
|--------|---------|------------|
| `audit_and_autodelete_pipeline.py` | Secure deletion | GDPR Article 17, 3-pass overwrite |
| `safe_retention_policy_enforcer.py` | Data retention | Configurable per-table policies |
| `session_validation_and_schema_enforcer.py` | Schema validation | JSON Schema, required fields |
| `secure_delete_kv_store.py` | Redis secure delete | Memory-mapped overwrite |
| `deletion_notification_and_compliance_report.py` | Compliance reporting | HMAC signatures, audit trail |
| `robust_error_handling_patch.py` | AST code injection | Automatic try-catch wrapping |
| `imputation_confidence_calibrator.py` | Uncertainty quantification | Isotonic regression, Platt scaling |

### Infrastructure

| File | Purpose |
|------|---------|
| `Dockerfile` | Container build |
| `k8s/` | Kubernetes manifests |
| `slurm/` | HPC job scripts |
| `.github/workflows/ci_cd_unit_tests_and_linter_pipeline.yaml` | CI/CD pipeline |
| `config/retention.yaml` | Retention policies |

---

## 🎭 Emoji Avatar Engine

The `emoji_avatar_engine/` provides a 2.5D emoji-style avatar system for child-friendly therapeutic interactions.

**Components:**
- `emoji_avatar_engine.py` - Core rendering with Pillow, configurable parts
- `emoji_web_customizer/` - React-based web customizer with canvas preview
- `emoji_mobile_customizer/` - React Native (Expo) touch-friendly customizer
- `dashboard_demo/` - Streamlit guardian dashboard with PDF/CSV reports

**Features:**
- 12 skin tones, 10 hairstyles, 8 eye shapes, 7 mouth expressions
- Accessory system (glasses, hats, earrings)
- Expression morphing (happy → sad transitions)
- Batch rendering for ML training datasets
- Export to PNG with transparency

---

## 📊 Datasets & Benchmarks

The training pipelines support these datasets:

| Dataset | Task | Notes |
|---------|------|-------|
| FER2013 | Emotion classification | 7 classes, 35k images, ~72% baseline |
| AffectNet | Emotion classification | 8 classes, 450k images |
| RAVDESS | Audio emotion | 24 actors, 8 emotions |
| CREMA-D | Audio emotion | 7,442 clips |
| Custom Komal | Engagement scoring | Internal, privacy-compliant |

**Preprocessing:**
- Face detection with MTCNN/RetinaFace
- 5-point landmark alignment
- Histogram equalization
- Class balancing via oversampling

---

## 🔬 Research Techniques Implemented

### Machine Learning

- **Continual Learning**: Elastic weight consolidation (EWC), rehearsal buffers
- **Federated Learning**: FedAvg algorithm, differential privacy
- **Curriculum Learning**: Competence-based sampling, self-paced weighting
- **Knowledge Distillation**: Temperature scaling, attention transfer
- **Hyperparameter Optimization**: TPE, Hyperband pruning, multi-objective

### Signal Processing

- **Audio**: MFCC, mel spectrograms, pitch tracking (CREPE-style)
- **Video**: Optical flow, temporal gradients, scene detection
- **Fusion**: Late fusion, attention-weighted combination

### Compression

- **Quantization**: PTQ (post-training), QAT (quantization-aware)
- **Pruning**: Magnitude-based, structured channel pruning
- **Distillation**: Soft targets, intermediate layer matching

### Privacy

- **On-device ML**: All inference client-side
- **Differential Privacy**: Laplace mechanism for analytics
- **Secure Deletion**: DoD 5220.22-M style overwrite
- **Aggregation**: Only anonymized metrics uploaded

---

## 📈 Model Accuracy Targets

| Model | Task | Target | Notes |
|-------|------|--------|-------|
| Emotion Classifier | 7-class | 72-75% | MobileNetV3-Small |
| Attention Scorer | Regression | MAE < 0.15 | LSTM on gaze features |
| Voice Confidence | Regression | MAE < 0.12 | MLP on OpenSMILE |
| Engagement Quality | 0-10 scale | MAE < 0.8 | Multi-modal fusion |

Note: Accuracies are on held-out test sets. Production models use TFLite/ONNX with INT8 quantization (slight accuracy drop ~1-2%).

---

## 🏃 Running the Scripts

Most scripts support common arguments:

```bash
# Training with HPO
python scripts/optuna_hpo_distributed.py \
  --study_name emotion_v2 \
  --n_trials 100 \
  --n_jobs 4

# Quantize for mobile
python scripts/quantize_for_mobile.py \
  --input_model models/emotion.pt \
  --output models/emotion_int8.tflite

# Delta OTA patching
python scripts/delta_ota_patcher.py \
  --old_version 1.0.0 \
  --new_version 1.1.0 \
  --output patches/

# Billing guard (simulation)
python scripts/billing_and_quota_guard.py \
  --budget_limit 1000 \
  --simulate

# Validation sampling
python scripts/cheap_validation_sampler.py \
  --input embeddings.npy \
  --n_samples 50 \
  --method k_center
```

See individual script `--help` for full options.

---

## 📋 Configuration Files

| File | Purpose |
|------|---------|
| `config/retention.yaml` | Data retention policies per table |
| `config/device_profiles.json` | Device capability profiles |
| `k8s/*.yaml` | Kubernetes deployment configs |
| `slurm/*.sh` | HPC job templates |

---

## 🧪 Testing

```bash
# Run unit tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=scripts --cov-report=html

# Lint
flake8 scripts/ --max-line-length=120
black scripts/ --check
```

CI runs automatically on push via `.github/workflows/ci_cd_unit_tests_and_linter_pipeline.yaml`.

## 🤝 Contributing

This is a therapeutic app for children. Please ensure:

1. **Child Safety First**: All features must be safe and age-appropriate
2. **Privacy**: No data collection without explicit consent
3. **Accessibility**: Support for diverse needs (autism, ADHD, etc.)
4. **Battery Efficient**: Optimize for mobile devices
5. **Testing**: Test with real children (with guardian consent)

## 📧 Support

For questions or issues, contact: komalforkids@gmail.com

## 📄 License

[To be determined]

---

**Built with ❤️ for children's mental health and social-emotional learning**
