# v0.6 Investigation 2 Experimental Plan

## 1. Purpose

Investigation 2 explains the dominant numerical behaviours measured during Investigation 1 before any algorithmic changes are considered.

The governing question is:

> **What numerical mechanisms are responsible for the dominant errors identified in Investigation 1?**

The investigation shall use controlled computational experiments to distinguish:

* integration-algorithm effects;
* integration-tolerance effects;
* algorithm–tolerance interactions;
* diagnostic-sampling effects;
* duration-dependent behaviour;
* unregularised close-encounter propagation error;
* regularised propagation error;
* switching-event and handoff effects;
* physical-state reconstruction effects;
* dense-output evaluation effects; and
* backend-specific behaviour.

The investigation does not select or implement numerical improvements. Candidate components may be identified for Investigation 3 only when the experimental evidence supports doing so. “No change” remains a valid outcome.

## 2. Basis in Investigation 1

The completed Investigation 1 baseline identified four behaviours requiring explanation.

### 2.1 Core benchmark profile contrast

For the ten-period figure-eight benchmark:

* the fast profile recorded maximum relative energy drift of approximately `1.24e-8`;
* the accurate profile recorded approximately `1.34e-13`;
* periodicity error improved only from approximately `9.55e-7` to `3.50e-7`.

For the hierarchical triple:

* maximum relative energy drift improved from approximately `3.45e-8` to `9.41e-14`;
* the minimum hierarchy ratio changed only from approximately `9.95596628` to `9.95596654`.

The profile comparison combines a change of integration algorithm and tolerance. It does not reveal the separate contribution of either choice or any interaction between them.

The large change in invariant drift relative to the smaller change in trajectory-specific measurements also requires explanation.

### 2.2 Cartesian close-encounter error

In the fixed close-encounter comparison:

* Cartesian maximum state error was approximately `3.93e-10`;
* automatic-switching maximum state error was approximately `7.02e-11`;
* explicit-regularised maximum state error was approximately `7.03e-11`;
* Cartesian periapsis separation error was approximately `2.10e-2`;
* both regularised modes reproduced periapsis separation to approximately `8.54e-18`.

The dominant source, location, and tolerance dependence of the Cartesian error are not yet established.

### 2.3 Automatic versus explicit regularisation

Automatic-switching and explicit-regularised propagation produced nearly equal reference errors despite using different orchestration paths. Their exit-state difference was small but nonzero.

This suggests that switching and handoff may be secondary to propagation in the regularised representation, but the fixed baseline alone cannot establish that conclusion.

### 2.4 KS versus Levi-Civita behaviour

The KS and Levi-Civita switching backends recorded:

* maximum scaled physical-state discrepancy of approximately `1.86e-9`;
* entry-event time difference of zero;
* exit-event time difference of approximately `4.82e-14`;
* transition residuals of approximately `1.39e-17`;
* different maximum relative energy drifts.

The existing evidence does not identify whether the physical-state discrepancy arises from:

* regularised integration;
* physical-state reconstruction;
* dense interpolation or physical-time evaluation;
* the duration or location of regularised propagation; or
* another backend-specific numerical effect.

## 3. Scientific hypotheses

Investigation 2 shall test the following hypotheses. Each hypothesis identifies a candidate explanation for an Investigation 1 observation. The experiments may support, reject, qualify, or leave the hypothesis unresolved.

### H1 — Contributions of integration algorithm and tolerance

The differences observed between the `:fast` and `:accurate` core profiles arise from the integration algorithms, tolerance settings, and possible interaction between those choices.

Matched-algorithm tolerance series and matched-tolerance algorithm comparisons will determine the relative contribution of:

* integration algorithm;
* absolute and relative tolerance; and
* algorithm–tolerance interaction

to each measured accuracy and solver-work outcome.

### H2 — Distinct behaviour of trajectory and diagnostic measurements

Trajectory-specific errors and invariant-drift measurements respond differently to integration tolerance, duration, and diagnostic sampling.

Consequently, improvement in an invariant measurement does not necessarily imply a proportional improvement in the physical trajectory, and changes in sampled diagnostic extrema may not represent equivalent changes in the integrated solution.

### H3 — Limiting source of figure-eight periodicity error

At sufficiently tight integration tolerances, the figure-eight periodicity error may become limited by the fixed benchmark initial conditions, period value, arithmetic precision, or another non-integrator source.

This hypothesis is supported only if integration and invariant errors continue to decrease while the periodicity residual becomes reproducibly insensitive to further tolerance reduction.

### H4 — Source of Cartesian close-encounter error

The dominant Cartesian close-encounter error develops during unregularised propagation through the near-periapsis region.

This hypothesis will be tested by examining where the Cartesian state error develops and how state error, periapsis error, and solver work change under controlled tolerance reduction while the physical problem and reference solution remain fixed.

### H5 — Contribution of switching and handoff

For the Investigation 1 close encounter, switching detection and segment handoff contribute less to the observed error than propagation within the regularised representation.

This hypothesis is supported if automatic and explicitly bounded regularised integrations remain closely matched across controlled tolerance and threshold experiments. A systematic automatic-versus-explicit discrepancy would instead indicate a material switching, event-location, or handoff contribution.

### H6 — Origin of the KS and Levi-Civita discrepancy

The physical-state discrepancy between the KS and Levi-Civita backends develops primarily during regularised propagation, physical-state reconstruction, or dense-output evaluation rather than from disagreement in switching-event times or transition continuity.

This hypothesis will be tested by localising the discrepancy by trajectory segment, physical-state component, regularised tolerance, and switching threshold while retaining event-time, transition, reconstruction, and dense-output evidence separately.

These hypotheses may be supported, rejected, qualified, or remain unresolved.

## 4. Scope

### 4.1 Included

Investigation 2 includes:

* matched tolerance experiments using fixed integration algorithms;
* matched algorithm comparisons at fixed tolerances;
* integration-duration experiments;
* diagnostic-sampling experiments;
* fixed-grid physical-state self-convergence measurements;
* one conditionally triggered arithmetic-precision confirmation;
* Cartesian and regularised close-encounter tolerance experiments;
* reference-defined temporal localisation of close-encounter error;
* controlled switching-threshold experiments;
* localisation of KS/Levi-Civita discrepancy by trajectory segment and state component;
* explicit reconstruction-consistency evidence;
* explicit dense-output consistency evidence;
* deterministic solver-work evidence;
* repeated execution and reproducibility comparison; and
* an explanatory report linking measurements to the registered hypotheses.

### 4.2 Excluded

Investigation 2 excludes:

* changes to solver algorithms;
* new regularisation formulations;
* changes to production profile defaults;
* adoption of new switching thresholds;
* new physical benchmark families;
* optimisation work;
* new acceptance limits for descriptive experiments;
* automatic ranking across incomparable metrics;
* universal numerical thresholds for classifying causal importance;
* synthetic combined accuracy scores; and
* implementation of candidate improvements.

The experiments may vary existing parameters for causal study. Experimental variation does not imply that the varied value is suitable for production use.

## 5. Experimental principles

### 5.1 One controlled variable per series

Each ordered series shall vary one declared independent variable. Separate series may use the same point values to permit matched comparison.

Where an experiment necessarily compares two algorithms or backends, all other recorded controls shall be identical or explicitly qualified.

### 5.2 Predeclared values

Point values defined by this plan shall not be changed after inspecting results.

Unsupported, unsuccessful, or unavailable points shall remain in their declared position. A result shall not be removed because it conflicts with an expected trend.

### 5.3 Common controls

Within each series, the following shall remain fixed unless declared as the independent variable:

* physical initial conditions;
* integration interval;
* solver algorithm;
* absolute and relative tolerances;
* arithmetic type and precision;
* sampling convention;
* switching policy;
* reference construction;
* comparison grid;
* comparison norm and scaling;
* metric definitions; and
* performance measurement policy.

### 5.4 Separate measurement from explanation

Machine-readable reports shall contain factual measurements, configurations, provenance, execution outcomes, and supporting evidence.

Causal interpretation shall appear only in the explanatory report.

A descriptive experimental point shall not be converted into an acceptance failure merely because its result is unexpected.

### 5.5 Reference independence

A method being evaluated shall not determine the reference times, encounter boundaries, comparison scales, or reference states against which it is measured.

Reference-defined boundaries and scales shall be calculated independently and reused across all points in the corresponding series.

### 5.6 Reproducibility

Every mandatory series shall be executed twice under the Investigation 1 reproducibility protocol.

Numerical and deterministic work evidence shall use the established comparison rules. Elapsed and garbage-collection timing shall remain descriptive and excluded from equality requirements.

Any additional comparison tolerance introduced for Investigation 2 shall be stated explicitly in the machine-readable definition and explanatory report.

## 6. Core integration experiments

### 6.1 Matched algorithm-and-tolerance experiments

Four ordered series shall be created:

* `figure_eight_tsit5_tolerance`;
* `figure_eight_vern9_tolerance`;
* `hierarchical_triple_tsit5_tolerance`;
* `hierarchical_triple_vern9_tolerance`.

Each series shall use:

```text
reltol = abstol ∈ (1e-9, 1e-10, 1e-11, 1e-12, 1e-13)
```

Figure-eight controls:

```text
periods = 10
saveat = 0.02
arithmetic = Float64
```

Hierarchical-triple controls:

```text
duration = 100.0
saveat = 0.02
arithmetic = Float64
```

Using separate Tsit5 and Vern9 series permits:

* tolerance effects to be measured with the algorithm fixed;
* algorithm effects to be compared at the same tolerance; and
* the original fast/accurate profile contrast to be decomposed.

Required evidence includes:

* completion status;
* achieved final time;
* final-time residual;
* periodicity error for the figure-eight;
* hierarchy measurements for the hierarchical triple;
* invariant and centre-of-mass residuals;
* minimum pair separation;
* accepted and rejected steps;
* right-hand-side evaluations;
* saved states;
* retained timing evidence; and
* adjacent-tolerance physical-state differences.

#### 6.1.1 Adjacent-tolerance physical-state comparison

For each algorithm and benchmark, every point except the tightest shall be compared with the next tighter tolerance point:

```text
1e-9  versus 1e-10
1e-10 versus 1e-11
1e-11 versus 1e-12
1e-12 versus 1e-13
```

Comparisons shall use the fixed common `saveat = 0.02` physical-time grid. Values shall be taken from the states saved at those requested times rather than from a separately chosen adaptive grid.

The following initial characteristic scales shall be calculated once from the shared benchmark initial state:

```text
L₀ = maximum initial pair separation
V₀ = maximum initial pair-relative speed
```

If either scale is exactly zero, its replacement scale shall be `1` in the benchmark’s established units, and that fallback shall be recorded.

At each common time, let `R_cm` and `V_cm` be the corresponding centre-of-mass position and velocity for each solution. Define:

```text
position difference =
    maxᵢ ‖(rᵢ - R_cm)_loose - (rᵢ - R_cm)_tight‖₂ / L₀

velocity difference =
    maxᵢ ‖(vᵢ - V_cm)_loose - (vᵢ - V_cm)_tight‖₂ / V₀

scaled state difference =
    max(position difference, velocity difference)
```

The series shall record:

* maximum position difference over the common grid;
* maximum velocity difference over the common grid;
* maximum scaled state difference over the common grid;
* final position difference;
* final velocity difference; and
* final scaled state difference.

These are self-convergence differences between two numerical approximations. They are not approved-reference errors and do not independently establish that either approximation is correct.

### 6.2 Duration experiments

Two ordered duration series shall be created.

#### 6.2.1 Figure-eight duration

Series:

```text
figure_eight_duration
```

Points:

```text
periods ∈ (1, 2, 5, 10, 20)
```

Fixed controls:

```text
algorithm = Vern9
reltol = abstol = 1e-12
saveat = 0.02
arithmetic = Float64
```

#### 6.2.2 Hierarchical-triple duration

Series:

```text
hierarchical_triple_duration
```

Points:

```text
duration ∈ (25.0, 50.0, 100.0, 200.0)
```

Fixed controls:

```text
algorithm = Vern9
reltol = abstol = 1e-13
saveat = 0.02
arithmetic = Float64
```

The report shall examine the measured growth or stability of each metric separately.

Terms such as *linear*, *secular*, *bounded*, *saturating*, or *exponential* shall be used only when the complete measured series supports that description. A monotonic sequence alone shall not establish a physical or asymptotic growth law.

### 6.3 Diagnostic-sampling experiments

Two ordered sampling series shall be created:

* `figure_eight_diagnostic_sampling`;
* `hierarchical_triple_diagnostic_sampling`.

Points:

```text
saveat ∈ (0.1, 0.02, 0.004)
```

All other controls shall match the respective fixed high-accuracy baseline.

These series test whether reported maxima and minima depend materially on the output sampling used to evaluate diagnostics.

The analysis shall distinguish:

* changes in diagnostic extrema;
* changes in final-state or periodicity evidence;
* changes in saved-state counts;
* changes in deterministic internal solver-work counts; and
* changes caused only by evaluating dense output at more requested times.

A diagnostic-sampling effect shall not be described as an integration-accuracy effect unless physical-state or deterministic solver evidence also supports that interpretation.

### 6.4 Conditional figure-eight precision confirmation

The precision confirmation shall run only when both conditions are met:

1. periodicity error changes by less than a factor of two between the `1e-12` and `1e-13` Vern9 points; and
2. maximum relative energy drift changes by at least a factor of ten between those points.

If triggered, create:

```text
figure_eight_precision_confirmation
```

Points:

```text
precision_bits ∈ (128, 256, 384)
```

Fixed controls:

```text
algorithm = Vern9
reltol = abstol = 1e-30
periods = 10
saveat = 0.02
```

#### 6.4.1 Precision-safe input construction

The benchmark’s initial positions, initial velocities, masses, gravitational constant, period value, integration limits, tolerances, and sampling interval shall be represented by canonical decimal strings.

For each precision point:

1. establish the requested `BigFloat` precision before parsing any numerical input;
2. parse the same canonical decimal strings directly into `BigFloat`;
3. construct the complete system and initial state from those parsed values; and
4. retain the canonical strings and requested precision in the measurement record.

Float64 values shall not be promoted to construct this experiment because promotion cannot restore digits already lost through Float64 rounding.

No additional digits, fitted corrections, externally sourced initial conditions, or revised period values shall be introduced. Every precision point shall represent the same published benchmark data to the precision supported by the canonical strings.

The requested `1e-30` tolerance is an experimental control, not a claim that every precision point will achieve that error. Any unsupported or unsuccessful point shall be retained factually.

A precision-insensitive periodicity residual would support the conclusion that the residual is not dominated by ordinary Float64 arithmetic or integration error. It would not by itself identify an exact correction to the benchmark initial conditions or period.

If the trigger conditions are not met, the report shall record:

```text
figure_eight_precision_confirmation: not triggered
```

together with the measured trigger values.

## 7. Close-encounter mechanism experiments

The existing physical problem, comparison interval, independent BigFloat reference, sampling procedure, and established error metrics shall remain unchanged.

The higher-precision reference shall be constructed once per experimental execution and reused by all close-encounter points in that execution.

### 7.1 Cartesian tolerance series

Series:

```text
close_encounter_cartesian_tolerance
```

Points:

```text
reltol = abstol ∈ (1e-9, 1e-10, 1e-11, 1e-12, 1e-13)
```

Required evidence includes:

* maximum and final pair-relative position error;
* maximum and final pair-relative velocity error;
* maximum and final full-state error;
* dense periapsis time error;
* dense periapsis separation error;
* invariant drift;
* minimum sampled separation, reported separately from periapsis;
* accepted and rejected steps;
* right-hand-side evaluations;
* saved states;
* retained timing evidence; and
* temporally localised reference error.

#### 7.1.1 Reference-defined encounter interval

The temporal localisation interval shall be defined solely from the independent BigFloat reference.

Its boundaries are:

```text
reference entry time =
    inbound reference crossing of pair separation 0.1

reference periapsis time =
    minimum-separation time of the BigFloat reference

reference exit time =
    outbound reference crossing of pair separation 0.25
```

These reference times shall be calculated once per experimental execution and reused unchanged for every Cartesian tolerance point.

A Float64 method being evaluated shall not determine or alter these boundaries.

#### 7.1.2 Localised error evidence

Every Cartesian point shall record the established pair-relative position, velocity, and full-state error at:

* the reference entry time;
* the reference periapsis time;
* the reference exit time; and
* final time.

It shall also record the maximum of each established error metric in three fixed regions:

```text
before encounter:
    initial time ≤ t < reference entry time

during encounter:
    reference entry time ≤ t ≤ reference exit time

after encounter:
    reference exit time < t ≤ final time
```

The maxima shall be evaluated using:

* the existing common physical-time comparison grid;
* the exact reference entry time;
* the exact reference periapsis time;
* the exact reference exit time; and
* final time.

The comparison shall state whether each evaluated method state was saved directly or obtained through dense interpolation.

This evidence is required to distinguish:

* error already present before the encounter;
* error generated or amplified near periapsis; and
* error accumulated after the encounter.

Tolerance sensitivity alone shall not be treated as proof that the error originated near periapsis.

### 7.2 Regularised tolerance series

Two matched series shall be created:

* `close_encounter_automatic_regularized_tolerance`;
* `close_encounter_explicit_regularized_tolerance`.

Points:

```text
regularized reltol = regularized abstol ∈
    (1e-10, 1e-11, 1e-12, 1e-13)
```

Fixed controls:

```text
Cartesian reltol = Cartesian abstol = 1e-13
entry threshold = 0.1
exit threshold = 0.25
state-evaluation tolerance = 1e-14
```

For every tolerance, explicit propagation shall use the physical entry and exit times detected by the corresponding automatic run. This preserves matched regularised intervals for the automatic-versus-explicit comparison.

The automatic event times shall also be compared independently with the reference-defined entry and exit times from Section 7.1.

Required evidence includes:

* all established reference-state and periapsis errors;
* automatic-versus-explicit state differences at entry, periapsis, exit, and final time;
* maximum automatic-versus-explicit discrepancy during the regularised interval;
* transition and handoff residuals;
* fictitious-time endpoint residuals;
* segment and switch counts;
* accepted and rejected steps;
* right-hand-side evaluations;
* saved states; and
* retained timing evidence.

A small automatic-versus-explicit discrepancy does not establish that both are accurate; it establishes only that their orchestration paths agree closely under the matched conditions. Reference error shall remain the independent accuracy evidence.

### 7.3 Switching-threshold series

Two matched series shall be created:

* `close_encounter_automatic_threshold_scale`;
* `close_encounter_explicit_threshold_scale`.

The independent variable is:

```text
threshold_scale ∈ (0.5, 1.0, 2.0)
```

Thresholds are fixed before execution as:

| Scale | Entry |  Exit |
| ----: | ----: | ----: |
|   0.5 |  0.05 | 0.125 |
|   1.0 |  0.10 |  0.25 |
|   2.0 |  0.20 |  0.50 |

The ambiguity threshold shall follow the existing close-encounter rule. All tolerances shall remain at their Investigation 1 baseline values.

Explicit propagation shall use the corresponding automatic entry and exit times for each threshold point.

The threshold series tests whether reference error and automatic-versus-explicit discrepancy change with:

* entry-event location;
* exit-event location;
* duration of regularised propagation; and
* the resulting handoff states.

A threshold effect shall not be described as a switching-policy improvement because Investigation 2 does not select production thresholds.

## 8. KS and Levi-Civita mechanism experiments

The fixed physical encounter and existing controller shall remain unchanged.

Each point shall run both KS and Levi-Civita backends under identical Cartesian controls and policy parameters.

### 8.1 Common regularised-tolerance series

Series:

```text
ks_switching_regularized_tolerance
```

Points:

```text
regularized reltol = regularized abstol ∈
    (1e-10, 1e-11, 1e-12, 1e-13)
```

Fixed controls:

```text
Cartesian reltol = Cartesian abstol = 1e-12
entry threshold = 0.2
ambiguity threshold = 0.3
exit threshold = 0.4
```

### 8.2 Switching-threshold series

Series:

```text
ks_switching_threshold_scale
```

Points:

```text
threshold_scale ∈ (0.5, 1.0, 2.0)
```

Thresholds are:

| Scale | Entry | Ambiguity | Exit |
| ----: | ----: | --------: | ---: |
|   0.5 |  0.10 |      0.15 | 0.20 |
|   1.0 |  0.20 |      0.30 | 0.40 |
|   2.0 |  0.40 |      0.60 | 0.80 |

The regularised and Cartesian tolerances shall remain at the Investigation 1 baseline values.

### 8.3 Discrepancy localisation

Every KS comparison point shall add physical-state discrepancy evidence partitioned into:

* Cartesian propagation before entry;
* regularised propagation;
* Cartesian propagation after exit;
* entry state;
* exit state; and
* final state.

Position and velocity discrepancies shall be recorded separately as well as in the existing scaled full-state norm.

The report shall retain:

* the time and segment in which the maximum discrepancy occurs;
* pair-relative position discrepancy;
* pair-relative velocity discrepancy;
* full physical-state discrepancy;
* event-time differences;
* transition residuals;
* reconstruction-consistency residuals;
* dense-output consistency residuals;
* backend-specific invariant drift;
* segment and switch counts;
* accepted and rejected steps;
* right-hand-side evaluations;
* saved states; and
* retained timing evidence.

#### 8.3.1 Common physical-time grids

Maximum-discrepancy evaluation shall use two nested common physical-time grids of 801 and 3201 points over the full comparison interval.

Both grids shall additionally include:

* exact entry-event times from both backends;
* exact exit-event times from both backends;
* all segment-boundary times;
* final time; and
* every accepted solver-node time used for the reconstruction and dense-output checks where practical without changing solver behaviour.

A material difference between the nested-grid maxima shall be reported as sampling-limited evidence. It shall not be attributed to a backend mechanism without further evidence.

The coarse and fine grid results shall both be retained. The fine-grid value shall not silently replace evidence that the maximum was grid-sensitive.

#### 8.3.2 Reconstruction-consistency residual

The reconstruction-consistency residual shall test the algebraic coordinate maps independently of trajectory agreement between the two backends.

It shall be evaluated at:

* every retained accepted regularised solver state for which the required mapping data are available;
* the exact regularised-segment entry state; and
* the exact regularised-segment exit state.

Dense-interpolated regularised states shall not be used for this metric.

For each backend and evaluation state:

1. reconstruct the physical selected-pair position and velocity from the retained regularised state;
2. retain the reconstructed binary centre of mass, third-body state, masses, and physical time;
3. deterministically lift the reconstructed physical selected-pair state back into the same regularised representation using the backend’s existing canonical inverse or gauge-selection rule;
4. reconstruct the physical state from that lifted regularised state; and
5. compare the first and second reconstructed physical states.

The residual shall record:

* pair-relative position residual;
* pair-relative velocity residual;
* full physical-state residual;
* physical-time residual; and
* the maximum and endpoint values for each residual.

The same scale-aware position, velocity, and physical-state norms already established for the corresponding backend diagnostics shall be used. The exact scaling fields shall be retained in the experiment definition.

For KS:

* raw regularised coordinates shall not be compared across gauge-equivalent lifts;
* the deterministic inverse-lift and gauge convention shall be recorded;
* only reconstructed physical-state differences shall be interpreted as reconstruction residuals.

For Levi-Civita:

* sign-equivalent coordinate representations shall not be treated as distinct physical states;
* only reconstructed physical-state differences shall be interpreted.

This metric tests map and lift consistency. It does not measure regularised propagation error against an independent physical reference.

If an existing backend cannot perform this defined round trip without introducing a new mathematical mapping or changing solver behaviour, the reconstruction metric for that backend shall be recorded as `Not available`. The corresponding reconstruction mechanism shall remain unresolved rather than being estimated through an ambiguous proxy.

#### 8.3.3 Dense-output consistency residual

Dense-output consistency shall be evaluated at accepted regularised solver-node times.

For each retained node:

1. reconstruct the physical state directly from the stored accepted regularised state;
2. evaluate the normal composed-trajectory or backend state-query path at the same physical time; and
3. compare the two physical states.

The residual shall record:

* pair-relative position difference;
* pair-relative velocity difference;
* full physical-state difference;
* maximum values across accepted nodes; and
* values at entry and exit where applicable.

This evidence isolates discrepancies introduced by:

* dense interpolation in fictitious time;
* physical-time inversion;
* composed-trajectory state evaluation; or
* the state-query reconstruction path.

It does not independently measure propagation accuracy.

If the normal state-query operation returns the stored accepted state directly at an exact node, that fact shall be recorded. A zero residual in that case shall not be generalised to off-node dense interpolation.

## 9. Interpretation rules

### 9.1 Core integration behaviour

A tolerance contribution is supported when a metric changes consistently and reproducibly as tolerance is tightened with the algorithm fixed.

An algorithm contribution is supported when Tsit5 and Vern9 differ reproducibly at the same tolerance while the benchmark, arithmetic, duration, sampling, and tolerance remain fixed.

An algorithm–tolerance interaction is supported when the relative ordering or size of the algorithm difference changes materially across the tolerance series.

A diagnostic-sampling contribution is supported when reported extrema change with `saveat` while final-state evidence and deterministic internal solver work remain effectively unchanged.

### 9.2 Close encounter

Unregularised near-periapsis propagation is supported as the primary source of Cartesian error when:

* error before the reference-defined encounter remains comparatively small;
* error grows materially during the reference-defined encounter;
* the increase is reproducible;
* the increase changes systematically with Cartesian tolerance; and
* regularised modes remain substantially more accurate under the fixed physical comparison.

Switching or handoff is supported as a material contributor only when the automatic-versus-explicit discrepancy changes systematically with threshold location, event timing, or regularised tolerance.

A common change in both automatic and explicit results indicates an effect associated with the regularised interval or propagation representation rather than automatic-controller orchestration alone.

### 9.3 KS and Levi-Civita

Regularised propagation is supported as a contributor when:

* the cross-backend physical-state discrepancy first develops or grows materially inside the regularised segment;
* the discrepancy changes systematically with regularised tolerance;
* event-time and transition residuals remain much smaller than the physical-state discrepancy; and
* reconstruction and dense-output residuals are too small to account for the observed discrepancy in the same metric.

Reconstruction is supported as a contributor only when the defined reconstruction-consistency residual is reproducibly large enough, in the same physical component and scale, to account for a material part of the observed backend discrepancy.

Dense-output evaluation is supported as a contributor only when:

* dense-output consistency residuals are reproducible;
* the discrepancy is larger away from accepted nodes than at accepted nodes; or
* the nested-grid comparison shows a consistent evaluation-dependent effect.

A switching-policy contribution is supported when threshold scaling changes the discrepancy after integration tolerance is held fixed.

If the discrepancy cannot be localised or responds inconsistently, the mechanism shall remain unresolved.

### 9.4 Per-metric effect reporting

Causal effects shall be quantified separately for each named metric.

For finite positive error magnitudes, the report should normally retain:

```text
error ratio = error_after / error_before
order change = log10(error_after) - log10(error_before)
```

The direction of the comparison and the selected baseline shall be stated explicitly.

For a metric that may be zero or signed, the report shall retain:

* the signed difference where scientifically meaningful;
* the change in absolute magnitude where relevant; and
* explicit handling of exact zero rather than an undefined or unbounded ratio.

For deterministic work counts, the report shall retain:

* absolute count difference; and
* relative count difference when the denominator is nonzero.

For timing evidence, the retained-sample summaries shall remain descriptive and shall not be incorporated into a causal accuracy score.

### 9.5 Mechanism classification

No universal percentage threshold shall be used to classify a mechanism as primary, secondary, or negligible.

For each named metric, the explanatory report may classify evidence as follows.

#### Primary evidence

A mechanism may be described as primary evidence for a measured behaviour when:

* the relevant controlled variable was isolated;
* the effect is reproducible;
* the effect has the same direction as the Investigation 1 contrast;
* its magnitude is sufficient to account for most of that contrast in the same metric and natural scale;
* relevant temporal or segment localisation supports the proposed mechanism; and
* competing measured mechanisms are smaller, inconsistent, or independently excluded.

The report shall show the quantitative comparison supporting the phrase “most of that contrast.”

#### Secondary evidence

A mechanism may be described as secondary evidence when:

* it produces a reproducible effect in the relevant metric;
* the effect is consistent with the observed behaviour; but
* it does not account for the main measured contrast, or its contribution cannot be separated completely from an interaction.

#### Not materially supported

A proposed mechanism may be described as not materially supported when the controlled experiments show no reproducible effect capable of explaining the observed behaviour in the relevant metric.

This phrase shall not mean that the mechanism is mathematically impossible.

#### Unresolved

A mechanism shall remain unresolved when:

* results are inconsistent;
* required evidence is unavailable;
* the experiment is unsuccessful;
* multiple variables remain confounded;
* comparison values are too close to a numerical or measurement limit; or
* the available series cannot distinguish competing explanations.

Every classification shall include:

* the metric being explained;
* the controlled comparison;
* the quantitative result in the metric’s natural scale;
* the reproducibility outcome;
* relevant limitations; and
* any interaction that prevents a unique attribution.

Effects from different mechanisms need not add linearly. The report shall not force an additive decomposition when algorithm–tolerance or representation–threshold interactions are present.

### 9.6 Prohibited interpretation

The Investigation 2 report shall not:

* combine different accuracy metrics into a synthetic score;
* rank algorithms or backends without naming the metric and controls;
* equate invariant preservation with trajectory accuracy;
* describe minimum sampled separation as periapsis error;
* infer a causal mechanism from temporal coincidence alone;
* infer asymptotic convergence from too few points;
* recommend a production setting;
* approve a solver change; or
* suppress contradictory evidence.

## 10. Records and reporting

The existing Investigation records, validation metrics, solver statistics, performance reports, provenance, deterministic serialization, operational-failure handling, and reproducibility conventions shall be reused.

New generic infrastructure shall not be introduced unless the existing immutable records cannot faithfully retain:

* paired-solution comparisons;
* reference-defined temporal partitions;
* segment-localised evidence;
* reconstruction-consistency evidence; or
* dense-output consistency evidence.

Any new supporting-evidence type shall be:

* immutable;
* narrowly scoped;
* deterministically serializable;
* round-trip tested;
* ordered where order is scientifically meaningful; and
* rejected explicitly when malformed or unsupported.

Machine-readable series shall be written under:

```text
validation_reports/investigation_2/
```

The human-readable report shall be:

```text
validation_reports/investigation_2/INVESTIGATION_2_EXPLANATORY_REPORT.md
```

The explanatory report shall contain:

* registered hypotheses;
* experimental configurations;
* direct measurements;
* unsuccessful and unavailable points;
* core tolerance and algorithm behaviour;
* duration behaviour;
* diagnostic-sampling effects;
* conditional precision-trigger outcome;
* close-encounter temporal error localisation;
* automatic-versus-explicit decomposition;
* KS discrepancy localisation;
* reconstruction and dense-output evidence;
* per-metric effect measurements;
* supported, rejected, qualified, and unresolved mechanisms;
* limitations;
* reproducibility results; and
* components, if any, transferred to Investigation 3.

It shall not recommend a specific implementation change.

## 11. Completion criteria

Investigation 2 is complete when:

* every mandatory series has been executed and retained;
* the conditional precision experiment has either been executed or recorded as not triggered;
* repeated execution satisfies the declared reproducibility rules;
* every predeclared comparison grid, norm, scale, and reference boundary is recorded;
* each Investigation 1 target behaviour is classified as explained, partially explained, unresolved, or measurement-limited;
* causal conclusions identify the controlled evidence supporting them;
* core algorithm, tolerance, and interaction effects are distinguished where the data permit;
* Cartesian close-encounter error is temporally localised or explicitly recorded as unresolved;
* KS discrepancy is partitioned among propagation, switching, reconstruction, dense-output, and unresolved contributions where the evidence permits;
* primary mechanisms are distinguished from secondary effects using explicit per-metric reasoning rather than universal thresholds;
* unsupported mechanisms are not presented as causes;
* unavailable reconstruction evidence is not replaced with an ambiguous proxy;
* any component transferred to Investigation 3 is supported by a reproducible evidence chain; and
* the evidence permits a justified decision to evaluate candidate improvements or to make no solver change.

Investigation 2 does not require that every numerical behaviour be fully explained.

## 12. Implementation stages

### Stage I2-A — Experimental-plan approval

Approve this document and freeze:

* target behaviours;
* hypotheses;
* point values;
* fixed controls;
* comparison grids;
* comparison norms and scales;
* precision-input construction;
* reference-defined encounter boundaries;
* reconstruction and dense-output definitions;
* interpretation rules; and
* completion criteria.

### Stage I2-B — Core integration experiments

Implement:

* the core matched-algorithm tolerance series;
* matched-tolerance algorithm comparisons;
* the core duration series;
* the diagnostic-sampling series;
* the fixed adjacent-tolerance state comparisons; and
* the conditional precision trigger and precision-safe input construction.

Do not change benchmark physics or production profiles.

### Stage I2-C — Close-encounter decomposition

Implement:

* the Cartesian tolerance series;
* reference-defined temporal localisation;
* the automatic and explicit regularised tolerance series; and
* the matched threshold-scale series

while reusing the existing physical case and higher-precision reference.

### Stage I2-D — KS backend localisation

Implement:

* the common regularised-tolerance series;
* the threshold-scale series;
* segment-localised physical-state discrepancy measurements;
* reconstruction-consistency evidence; and
* dense-output consistency evidence.

If a defined reconstruction operation is unavailable through the existing mathematical maps, retain that evidence as unavailable and leave the corresponding mechanism unresolved.

### Stage I2-E — Explanatory execution and report

Execute all approved series twice, preserve deterministic records, evaluate the registered hypotheses, and produce the Investigation 2 explanatory report.

No algorithmic improvement shall be implemented during these stages.

## 13. First implementation increment

The first source-code increment after approval shall be limited to Stage I2-B.

It shall:

* reuse the existing Investigation records and performance protocol;
* add only the core experiment definitions, comparison operations, and adapters required by this plan;
* implement the fixed adjacent-tolerance comparison grid and scaling;
* implement precision-safe canonical-string input construction;
* retain every ordered point and unsuccessful execution;
* retain complete provenance and deterministic solver work;
* include focused unit tests;
* run the complete package test suite; and
* stop before executing or interpreting the complete Investigation 2 programme.

It shall not:

* change profile defaults;
* change solver algorithms;
* change acceptance criteria;
* add close-encounter or switching experiments;
* add new benchmark physics;
* alter the existing published figure-eight constants;
* introduce a general causal-analysis framework;
* classify mechanisms automatically; or
* implement an Investigation 3 candidate improvement.
