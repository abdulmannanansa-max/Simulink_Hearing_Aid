# Simulink Hearing Aid (MathWorks Challenge Project 241)

A frame-based digital hearing-aid model with an objective verification suite.

**Signal chain (one 32-sample / 2 ms frame at 16 kHz):**
`mic + acoustic feedback -> adaptive feedback canceller (NLMS) -> 6-band linear-phase FIR filterbank ->
per-band WDRC compression + noise reduction -> sum -> soft output limiter (MPO) -> receiver`

Gains are prescribed from an audiogram with a NAL-R-style formula. Everything is driven by `ha_params.m`.

## Run it
MATLAB R2020b or newer. Simulink is needed only for the model; the DSP and verification need no toolboxes.
```matlab
RUN_ME                       % verify + demo audio + (if Simulink present) build & check the model
RUN_ME('my_speech.wav')      % use your own recording (recommended for your report)
```
Individual entry points: `ha_verify`, `ha_demo`, `ha_build_simulink_model(scene)`, `ha_run_simulink`.
Change the hearing loss in `ha_params.m` (`audiogram_HL`); everything re-fits automatically.

## What "success" means: verification (results/verification_report.txt)
| # | Check | Criterion | Result (Octave, synthetic speech) |
|---|-------|-----------|-----------------------------------|
| T1 | Filterbank reconstruction, latency | bands sum to a pure delay; < 10 ms | error 1e-17; 8.0 ms |
| T2 | Prescription accuracy (65 dB SPL speech-shaped noise) | within 3 dB of NAL-R target, every band | max error 1.6 dB |
| T3 | Compression ratio (level sweep) | within 0.35 of programmed CR | 1.56-2.55 vs 1.5-2.5 |
| T4 | Output limiting | peak never above MPO ceiling at 105 dB SPL input | pass |
| T5 | Noise reduction (shadow-filter SNR) | output SNR +2 dB or more, speech loss 4 dB or less | +4.0 / +4.3 dB SNR; speech -3.0 / -2.0 dB |
| T6 | Feedback | howls without AFC, stable with AFC, transparent with no feedback, added stable gain >= 10 dB | +10.9 dB howl vs +0.1 dB; -15.6 dB; ASG >= 20 dB |
| T7 | Audibility (simplified SII-like index, my approximation) | improves by 0.20 or more | 0.34 -> 0.70 |

Figures are in `results/`. `demo_unaided.wav` / `demo_aided.wav` are for listening (low volume first).

## Project status
| Stage | Status |
|---|---|
| DSP algorithm (filterbank, NAL-R fitting, WDRC, noise reduction, AFC, MPO) | **Done** |
| Verification suite, T0-T7 (18 checks) | **Done, 18/18 pass** — confirmed in real MATLAB, not just Octave |
| Demo audio (`demo_unaided.wav` / `demo_aided.wav`) | **Done** |
| Simulink model builds and compiles | **Done** — confirmed in real Simulink |
| Simulink output retrieved and compared to the script model | **Fixed, not yet confirmed** — see below |
| Figures | 5 already generated from the script model; a 6th (`fig6_simulink_vs_script.png`) now generates from the Simulink run once it completes |
| Match against the challenge page's own stated goals | **Not done** — I still cannot open that page myself (robots.txt); please check it |

**What "done" means here:** the DSP core is verified 18 ways (prescription accuracy, compression
ratios, output limiting, noise reduction, feedback stability, added stable gain, audibility) and
that verification has now run inside real MATLAB with identical results to every Octave run
throughout this project. The Simulink model compiles. What is NOT yet confirmed is the one
remaining equivalence check: that the Simulink model's *output signal* numerically matches the
verified script model to within -100 dB — that check was blocked by the data-retrieval bug in the
previous run and has not completed successfully yet. Run `RUN_ME` again to get that result.

## Demo outputs (for showing the aid working, not just verifying it)
`ha_run_simulink` (called by `RUN_ME`) writes, from the Simulink run itself:
* `results/fig7_input_vs_output.png` -- input audio (mic: speech + noise) vs. the hearing aid's
  output, first 4 s.
* `results/fig8_noise_reduction_simulink.png` -- noise-reduction gain (rows `nb+1:2*nb` of
  `ha_gains`) averaged across bands, over the whole run. Checked directly against real output
  data (not assumed): it genuinely drops as the per-band noise floor is learned in the first
  ~0.3 s, then tracks speech activity -- backing off during speech, deepening during pauses. This
  is the honest "it's working" visual for noise reduction specifically.
`ha_demo_nr.m` produces the same plot from the MATLAB *script* model directly (no Simulink
needed, useful to preview this before running Simulink at all).

**An earlier version of this README/code showed an "AFC error going down" plot as a feedback-
cancellation demo. That was wrong and has been removed.** Checked directly against this model's
own data: the raw AFC adaptation-error signal is dominated by input signal level and by
closed-loop transients as feedback first builds up, not cleanly by how well the path has been
learned -- it does not fall in a clean, presentable way, and a time-resolved cancellation-depth
metric (comparing the estimated vs. true synthetic feedback signal) fluctuates between roughly
-5 and +8 dB throughout a run rather than rising steadily, consistent with the modest ~2 dB
average depth already noted in T6 above. **For an honest AFC demonstration, use T6's
howling-vs-stable comparison instead** (`fig4_feedback.png`, or compare `ha_run_simulink` with
`p.afc_on` toggled in `ha_params.m`): that effect -- the aid staying stable instead of howling --
is large, real, and already verified, which "error descending" was not.

**To watch results live in Simulink itself** (e.g. for a demo/viva): right-click the wire from
`Scene` into `MicSum`, choose *Log Selected Signal Data*; do the same for the wire from
`HACore`'s `y` output. Press **Run**. Click **Data Inspector** in the ribbon (Review Results
section) -- every logged signal appears there together, zoomable, and exportable as a figure.
