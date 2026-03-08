# Technical Terms Recognition Plan

## Goal
Improve recognition of domain-specific/technical terms in VoiceApp transcripts while keeping latency low and fully local/on-device behavior.

## Scope
- Add user-managed custom dictionary.
- Add optional in-decoder biasing using WhisperKit prompt/prefix tokens.
- Add deterministic post-processing correction pipeline.
- Measure quality impact with clear attribution.

## Non-Goals
- Cloud-based correction services.
- Training or fine-tuning Whisper models.
- Large language model post-correction in this phase.

## Implementation Phases

### Phase 1: Dictionary + Post-Processing (MVP)
1. Create dictionary data model:
   - `term`: canonical output text.
   - optional flags: `caseSensitive`, `enabled`.
2. Persist dictionary in app storage (JSON).
3. Add correction pipeline after transcription:
   - normalize transcript chunks.
   - fuzzy + phonetic matching from transcript text directly to canonical terms (no user-entered aliases required).
   - replace with canonical terms.
4. Add safety guards:
   - high confidence threshold for auto-replacement.
   - skip replacements in ambiguous matches.
   - optional suggestion-only mode for borderline matches.
5. Add settings UI for dictionary CRUD and enable/disable toggle.

### Phase 2: Prompt Token Biasing
1. Build decode options per transcription request.
2. Convert selected dictionary terms to tokenizer tokens.
3. Pass token hints via `DecodingOptions.promptTokens` or `prefixTokens`.
4. Add feature flag to toggle biasing independently of post-processing.
5. Keep this soft and non-blocking (no hard forcing).

### Phase 3: Advanced Correction (Optional)
1. Add phonetic matching for names/acronyms.
2. Add context-aware reranking when multiple canonical terms compete.
3. Optionally evaluate lightweight Core ML text correction pass (on-device acceleration).

## Evaluation Plan

### Experiment Matrix
Run the same evaluation set in four modes:
1. Baseline: no bias, no post-processing.
2. Bias only: bias on, post-processing off.
3. Post-processing only: bias off, post-processing on.
4. Combined: bias on, post-processing on.

### Metrics
- Technical-term recall.
- Technical-term precision.
- Technical-term F1.
- False correction rate (replacements that should not happen).
- Optional global WER/CER for regression monitoring.
- Latency delta vs baseline (p50/p95).

### Dataset
- Build a local test set of representative utterances:
  - clean speech, accented speech, fast speech.
  - homophones and near-confusable terms.
  - mixed general + technical vocabulary.
- Keep gold transcripts with canonical term spellings.

### Success Criteria (initial)
- +20% relative improvement in technical-term recall vs baseline.
- <=2% false correction rate.
- <=10% p95 latency increase.

## Rollout Strategy
1. Ship Phase 1 behind a feature toggle.
2. Collect local evaluation + manual spot checks.
3. Enable Phase 2 for internal testing.
4. Promote combined mode as default only if metrics meet targets.

## Risks and Mitigations
- Over-correction of common words:
  - use strict thresholds and ambiguity checks.
  - prefer suggestion mode over auto-replace for medium-confidence matches.
- Prompt bias hurts non-technical text:
  - gate biasing by session/context and keep independent toggle.
- Added complexity in settings UI:
  - keep UX term-only (no alias entry), start with simple list CRUD and import/export later.

## Deliverables
- Dictionary storage + UI.
- Post-processing module with tests.
- Prompt bias integration with tests.
- Evaluation harness + report comparing all four modes.
