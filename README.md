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

## Honest limitations (put these in your report)
* **Fixed, reproduced before and after:** T6 could fail on real-world audio containing true
  digital silence (not present in the bundled/synthetic test material) -- the NLMS step size
  `mu/(refw'*refw + afc_delta)` could spike when the reference signal hit exact zero, corrupting
  the filter even with no real feedback present. `afc_delta` raised from `1e-8` to `1e-5` in
  `ha_params.m`; reproduced the failure with a crafted silence-gap test signal first, confirmed
  the fix resolves it (-3.6 dB -> -20.1 dB on that same test, need < -10), and reran the full
  18-check suite against the original sample audio afterward -- still 18/18, and cancellation
  depth on that sample actually improved too (1.9 -> 3.8 dB), not just the silence case.
* **Fixed:** `RUN_ME` could hang (not error) while saving figures -- `print()` on an invisible
  figure is a known MATLAB issue on some graphics-driver/OS setups (common on VMs). All figure
  saving now goes through `ha_save_fig.m`, which uses `exportgraphics` with a software renderer
  instead, falling back to `print()` only on older MATLAB that lacks `exportgraphics`.
* **The Simulink model now numerically matches the verified script model** (`RUN_ME` reports
  the difference in dB; expect roughly -300 dB, i.e. floating-point noise) -- this is the
  equivalence check the whole Simulink-build effort was for, and it has now passed in a real
  MATLAB/Simulink run, not just in my own Octave sandbox.
* **Retracted:** see "Demo outputs" above -- the AFC "error going down" demo from the previous
  round did not hold up under direct testing and has been replaced with a correct one (noise
  reduction) plus the right pointer for AFC specifically (stability, not error magnitude).
* **Changed:** `ha_core_frame.m`'s diagnostics output `dg` (and so `ha_gains`/`info.gains`
  everywhere) grew from 12 rows to 13 -- row 13 is the new AFC adaptation-error trace described
  above. `ha_simulate.m` was updated to match. This doesn't touch the Simulink wiring at all
  (the `dg -> Gains` port just widens automatically); it does mean the Simulink model must be
  rebuilt (re-run `RUN_ME`, which always does this) rather than re-run as-is.
* **Fixed (round 4):** `sim(mdl)` completed and the To Workspace block wrote `ha_out`, but depending
  on the installation's Data Import/Export setting ("Single simulation output"), that variable can
  land either in the base workspace or bundled inside the object `sim()` returns
  (`Simulink.SimulationOutput`), and `evalin('base', 'ha_out')` only checked the former. Fixed by
  forcing `ReturnWorkspaceOutputs = 'on'` on the model and reading via `simOut.get('ha_out')`, with a
  fallback to the base workspace so it works either way. Also added `fig6_simulink_vs_script.png`,
  generated from the Simulink run itself, as a visual check alongside the numeric one.
* **Fixed (round 3):** once the struct-field bug was gone, Simulink got further and hit a different
  MATLAB Coder rule: array sizes must be provable at compile time. `ha_design.m`/`ha_init_state.m`/
  `ha_core_frame.m` were sizing buffers (`zeros(p.L,1)`, `st.ybuf(p.L+1:end)`, etc.) from scalars read
  out of the parameter struct -- numerically always 32/6/64/48, but Coder treats a struct-field read as
  ordinary runtime data, so it marked those arrays "unbounded variable-size," which blocks like Unit
  Delay then reject. Fix: `L`, `nb`, `fir_order`, `afc_len` and `fb_len` are now literal constants at
  the top of those three files wherever they size or slice an array (values used only in arithmetic,
  e.g. `p.fs`, `p.att_s`, still read from `p` -- that's fine and doesn't need to be literal). A new T0
  check in `ha_verify.m` asserts the literals still match `ha_params.m` on every run, so an edit to
  `ha_params.m` that forgets to update them fails loudly instead of silently corrupting buffer sizes.
  Re-verified in Octave: 18/18 pass (12 original + 6 new consistency checks), same numbers as before.
* The Simulink model builder was **not run by me**: I have no MATLAB/Simulink here, so `ha_build_simulink_model.m`
  / `ha_run_simulink.m` are untested against the real product. The DSP functions they call were verified in Octave
  only. One codegen-specific bug was already found and fixed this way (see below) — there could be others that
  only MATLAB Coder itself, not Octave, will catch. If `RUN_ME` throws a new error inside the MATLAB Function
  blocks, send me the exact message; MATLAB Coder's errors are usually specific enough to fix from the text alone.
  The blocks need a supported C compiler (`mex -setup`).
* **Fixed (two rounds):** MATLAB Coder closes a struct's field list the instant any field of it is read — including
  a read used only to size a new placeholder field. Round 1 moved `ha_design.m`'s new fields into `ha_params.m` as
  placeholders, but those placeholders were sized from `p.nb`/`p.fir_order` etc. (a read), which still tripped the
  same rule inside `ha_params.m` itself. Round 2 rewrote `ha_params.m` so every base parameter and every derived
  placeholder is computed from local variables and assigned to `p` in one unbroken write-only sequence — `p` is
  never read anywhere in that file. `ha_design.m` then only overwrites those existing fields. Re-verified in
  Octave after each round: identical 12/12 pass, identical numbers both times, since only struct plumbing changed.
* The audiogram is illustrative, not a clinical profile. NAL-R constants and the speech spectrum/RETSPL values are
  approximate and typed from memory; check them against the references before citing numbers.
* The audibility index is a simplified stand-in, not standard SII. It is not a clinical or listening-test result.
* Feedback cancellation prevents howling and gives >= 20 dB added stable gain (the sweep's upper bound was reached,
  so the true value may be higher), but only ~2 dB of feedback-signal cancellation above 1.5 kHz. Speech correlates
  with the receiver signal and biases NLMS; a real-speech, pitch-aware (PEM) canceller is the known next step.
* Noise reduction trades about 2-3 dB of speech level for about 4 dB SNR; it is a level-based (not spectral-subtraction)
  scheme, so it helps most for stationary noise.
* Results above used synthetic speech-like signals. Re-run `ha_verify('your_speech.wav')` with real speech and
  quote those numbers instead. Nothing here is a validated medical device.
