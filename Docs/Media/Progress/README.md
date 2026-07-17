# BirdFlowMetal visual progress

This folder preserves each previously published README hero as an exact binary
from the commit that introduced it. The archive is presentation history, not
quantitative evidence; validation claims must cite the committed JSON artifacts
and an immutable Git commit.

## V1 — native fluid viewer

Commit: `85c806a` · 2026-07-15 · `896 × 504` · 40 frames · 20 fps

The first hero exposed the live D3Q19 viewer: surface pressure, a vorticity
slice, Q structures, and GPU-rendered diagnostics around the analytic bird.

![V1 native fluid viewer](2026-07-15-v1-native-fluid-viewer.gif)

## V2 — validation overlay

Commit: `99bc3a5` · 2026-07-15 · `896 × 504` · 40 frames · 20 fps

The native-fluid scene gained a compact validation-progress panel so numerical
status was visible in the animation rather than separated from it.

![V2 validation overlay](2026-07-15-v2-validation-overlay.gif)

## V3 — measured-dove replay

Commit: `f174282` · 2026-07-16 · `1120 × 630` · 72 frames · 24 fps

The synthetic showcase was replaced by the source-locked Deetjen `OB_F03`
surface, measured/coarse-computed force history, component colors, and
kinematic wing ghosts. This revision used the earlier back-and-forth
presentation.

![V3 measured-dove replay](2026-07-16-v3-measured-dove-replay.gif)

## V4 — continuous forward loop

Commit: `6f3dab2` · 2026-07-16 · `1120 × 630` · 72 frames · 24 fps

The replay stopped reversing. It advances monotonically through measured
samples 27–121 and uses a visibly labeled, velocity-matched 14 ms presentation
closure so the loop remains continuous without claiming periodic source data.

![V4 continuous dove loop](2026-07-16-v4-continuous-dove-loop.gif)

## V5 — D28 pre-roll frontier

Worktree snapshot: 2026-07-17 · `1120 × 630` · 72 frames · 24 fps

Lighting, hierarchy, body-following camera motion, dual-layer wingtip trails,
and the validation rail were refined. Its status was locked to the passed D28
RR3 production-margin pre-roll, with the full measured-force window still open.

SHA-256: `367010c6a2ea564d87fd6669edc56d2de196c9f478c208c59c45dab6eb74a499`

![V5 D28 pre-roll frontier](2026-07-17-v5-d28-pre-roll-frontier.gif)

## V6 — D28 full-window frontier

Worktree snapshot: 2026-07-17 · `1120 × 630` · 72 frames · 24 fps

This exact binary locked the force chart and numerical status to the audited
D28 RR3 source-viscosity full window: 13,216 steps, 187 force bins, positive
populations, and closed momentum ledgers. D32 was still the open refinement
question.

SHA-256: `c27237257a49d0e0883fea7b32be9be23283eaafdee0a57d2baedfb2a4007dc2`

![V6 D28 full-window frontier](2026-07-17-v6-d28-full-window.gif)

## V7 — D32 phase-localization frontier

Worktree snapshot: 2026-07-17 · `1120 × 630` · 72 frames · 24 fps

The first fine-grid hero locked the chart to the audited D32 full window,
reported the failed `5.632% > 5%` pair gate, and marked the independently
localized `25...30 ms` interval before its component replay existed.

SHA-256: `d7b511d170eeb4785487c08fae21a2e5c5d8ae4561819b1145648f0c96538147`

![V7 D32 phase-localization frontier](2026-07-17-v7-d32-phase-frontier.gif)

## V8 — targeted-boundary attribution frontier

V8 preserved the forward loop and locked its status panel to both valid D28/D32
targeted component replays plus their 15-check signed-energy audit. It reported
reflected-population self energy as the stable `58.4%` absolute-ledger leader,
while retaining the failed `5.632% > 5%` refinement boundary. The selected-link
population-versus-composition fork was still open.

SHA-256: `fdbf5533df6b06a3321aad31c338a97e0391ed296189003e34f0fab661fcbdaf`

![V8 targeted-boundary attribution frontier](2026-07-17-v8-targeted-boundary-frontier.gif)

## Archived hero — V9 reflected-link provenance

The archived [V9 animation](2026-07-17-v9-reflected-link-provenance.gif) keeps the
forward loop while improving silhouette lighting, visual hierarchy, camera
framing, dual-layer wingtip traces, file-size headroom, and validation status.
Its force chart remains artifact-locked to the independently audited D32 RR3
source-viscosity full window. The top status and `PROVENANCE` rail node are
additionally locked through the V2 selected-link preregistration, both passing
cases, the exact population/composition attribution, and its independent
16-check audit: near-wall link composition supplies `91.1%` of the absolute
ledger and leads both temporal halves. The amber chart band retains the audited
`25...30 ms` interval, while the boundary panel still reports the failed
D28/D32 `5.632% > 5%` fine-pair gate. Convergence and experimental agreement
therefore remain explicitly open. The V9 encoding is `9,557,715` bytes with
SHA-256 `f25e4ed8680a930de6d67362fe6dfffc6d91742e55e8fa99d68b5661c56afe61`;
its 73rd endpoint probe is pixel-identical to frame zero.

![V9 reflected-link provenance](2026-07-17-v9-reflected-link-provenance.gif)

## Archived hero — V10 direction-composition discriminator

The [archived V10 animation](2026-07-17-v10-direction-composition-discriminator.gif) preserves
the seamless forward loop and audited D32 force chart while advancing the
scientific status through the preregistered zero-fluid conditioned-factor
discriminator. Its top panel and `DIRECTION` rail node are SHA-locked through
the six-factor contract, all 64 D28/D32 hybrid states, exact Shapley result,
and independent 18-check audit. Direction composition supplies `87.7%` of the
absolute conditioned-factor ledger and leads both temporal halves; the bottom
boundary still reports the failed `5.632% > 5%` fine-pair gate. The V10
encoding is `9,646,440` bytes with SHA-256
`23467c2e983ceee1ce7aedeb4919ebf103dcf21f481e64bdf6aca2f220b79951`;
its 73rd endpoint probe is pixel-identical to frame zero.

![V10 direction-composition discriminator](2026-07-17-v10-direction-composition-discriminator.gif)

## Archived hero — V11 planar direction weighting cleared

The [archived V11 animation](2026-07-17-v11-planar-direction-weighting-cleared.gif) adds the
preregistered 40-case planar direction-composition canonical to the complete
artifact lock. Its top panel now reports `PLANAR D3Q19 DIRECTION WEIGHTING`,
`40 METAL/CPU CASES`, and the `1.28%` maximum analytic-vector error; the rail
advances to `PLANAR OK`. Those labels require the V2 preregistration, zero
per-direction Metal/CPU mismatch, all eight passing gates, and the independent
14-check audit. The lower boundary deliberately remains `PAIR OPEN` with
`5.632% > 5.0%`, distinguishing the cleared planar operator from unresolved
curved-surface redistribution and bird-load convergence. The V11 encoding is
`9,445,971` bytes with SHA-256
`8f401abd51624b3098f12705f920c59c2ff3100dd6b109796d83623042fe6c29`;
its 73rd endpoint probe is pixel-identical to frame zero.

![V11 planar direction weighting cleared](2026-07-17-v11-planar-direction-weighting-cleared.gif)

## Current hero — V12 curved dove direction mix cleared

The [current README animation](../birdflow-metal-native-viewer.gif) advances the
fail-closed artifact chain through the source-locked D12/D16 complete-dove
curved direction canonical. The top panel reports `CURVED DOVE DIRECTION MIX`,
the `0.130%` whole-surface direction-histogram variation, and the `0.0091%`
maximum whole fixed-profile response change. Those labels require the exact
source link-geometry report, curved preregistration, passing seven-gate result,
and independent `14/14`-check audit in addition to every V11 source. The rail
advances to `CURVED OK`, while `PAIR OPEN` and the lower
`D28/D32 5.632% > 5.0%` boundary remain visible. The V12 encoding is
`9,424,489` bytes with SHA-256
`4ee0eaed0a6c459c4660f2647137f4f6f7edc22b339f6ef933727fcad2daa602`;
its 73rd endpoint probe is pixel-identical to frame zero.
