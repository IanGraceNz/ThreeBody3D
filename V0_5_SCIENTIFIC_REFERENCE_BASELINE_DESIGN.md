# ThreeBody3D v0.5 Scientific Reference Baseline Design

## 1. Purpose

### 1.1 Background

Earlier v0.5 validation-framework milestones provide structured validation
results, deterministic reporting, reviewed reference records, explicit retained
metric policies, and reproducible comparison workflows.

These capabilities establish a scientifically auditable process for examining
numerical behaviour. The next stage is not to expand them into a comprehensive
baseline-management system. It is to define the minimum additional capability
required to support continued improvement of ThreeBody3D's regularization
methods and numerical accuracy.

### 1.2 Scientific objective

The purpose of approved scientific references is to preserve carefully reviewed
numerical observations that can serve as trustworthy comparison points for
future scientific development.

Approved scientific references exist to support continued improvements in:

- numerical accuracy;
- regularization methods;
- solver robustness;
- benchmark quality; and
- reproducibility.

They are not intended to become an administrative framework or a substitute for
scientific judgement.

The design exists to help determine whether a proposed numerical change is a
genuine improvement, no improvement, or a regression. The practical purpose of
avoiding self-deception is to produce better, more accurate software.

## 2. Design philosophy

This design follows the priorities established in
`V0_5_IMPLEMENTATION_PLAN.md`:

1. scientific acceptability;
2. ease of use; and
3. simplicity.

Scientific correctness takes precedence over convenience or feature count.
Routine scientific validation should remain straightforward. Infrastructure
should remain as small as practical and should grow only when demonstrated
scientific need justifies the added complexity.

### 2.1 Scientific minimalism

The validation framework shall implement only the minimum infrastructure
required to support scientifically defensible improvements in ThreeBody3D.

Features that primarily provide administrative, architectural, or
organisational sophistication without improving scientific capability are
outside the present scope.

### 2.2 Scientific return test

Every future extension should answer:

> Will this feature help determine whether a new numerical method is
> scientifically better than the previous one?

If the answer is no, implementation should normally be deferred.

### 2.3 Progressive scientific confidence

Every iteration should leave the project in a better scientific position than
the previous iteration. That improvement may arise from better accuracy,
stronger robustness, improved benchmarks, better reproducibility, clearer
limitations, or stronger confidence in existing algorithms.

The framework must make it as easy to conclude that a proposed method is not an
improvement as it is to confirm an improvement.

## 3. Scope

This design defines:

- candidate scientific references;
- approved scientific references;
- minimum scientific and provenance metadata;
- explicit human approval;
- immutability;
- explicit reference selection;
- comparison philosophy;
- replacement and historical-preservation rules; and
- the minimum implementation sequence.

This design intentionally does not define:

- automated baseline discovery;
- automatic approval or promotion;
- repository registries;
- approval hierarchies;
- lifecycle workflow engines;
- release-management automation;
- database-like reference querying;
- complex independent version-management systems; or
- automated scientific interpretation.

These omissions are deliberate. They may be reconsidered only when a concrete
scientific workflow demonstrates that they are needed.

## 4. Scientific reference concepts

### 4.1 Candidate scientific reference

A candidate scientific reference is a deliberately constructed record of
selected validation observations proposed for scientific review.

A candidate:

- is generated from an identified validation result;
- retains only explicitly selected metrics;
- records explicit comparison policies;
- records sufficient provenance for reproduction;
- has not yet become an authoritative comparison point; and
- must not be used merely to make the current implementation pass.

### 4.2 Approved scientific reference

An approved scientific reference is an immutable, scientifically reviewed
record of selected validation observations accepted as an authoritative
comparison point for future numerical development.

Its authority derives from scientific review, reproducibility, and understood
methodology rather than from a package version, filename, automated status, or
software decision.

Approved scientific references represent scientific observations rather than
software state. Their purpose is to preserve carefully reviewed numerical
evidence so that future developments may be evaluated objectively. The
validation framework stores, compares, and reports these observations, but
scientific interpretation remains the responsibility of the reviewer.

### 4.3 What an approved scientific reference is not

An approved scientific reference is not necessarily:

- a complete validation suite;
- every metric produced by a benchmark;
- a snapshot of the repository;
- a software release;
- proof that the generating implementation is optimal;
- a permanent claim that tolerances or methodology can never improve; or
- a substitute for examining the mathematics and numerical method.

Only intentionally selected observations become part of the approved reference.

## 5. Scientific evidence chain

Every numerical comparison should remain traceable through an unbroken chain of
scientific evidence:

```text
Mathematical formulation
        |
        v
Numerical algorithm
        |
        v
Validation benchmark
        |
        v
Reviewed scientific observation
        |
        v
Approved scientific reference
        |
        v
Future comparison
        |
        v
Scientific judgement
```

The comparison is evidence, not the scientific conclusion. Mathematics begins
the chain and scientific judgement completes it. The software preserves the
integrity and traceability of the evidence between those points.

## 6. Separation of evidence and judgement

The validation framework is responsible for:

- collecting structured observations;
- preserving approved observations faithfully;
- comparing current observations with explicitly selected references; and
- reporting values, differences, policies, and evaluation status clearly.

The framework is not responsible for:

- deciding that a new algorithm is scientifically superior;
- inferring scientific significance from a numerical difference;
- selecting the "best" reference;
- approving a candidate automatically;
- recommending that a reference be replaced; or
- hiding evidence that conflicts with an expected improvement.

Automated `PASS`, `FAIL`, and `ERROR` statuses describe whether declared
comparison policies were satisfied and whether comparison was executable. They
do not replace scientific interpretation.

## 7. Scientific acceptance

Approval is an explicit human scientific decision.

A candidate should normally be approved only when all of the following are
satisfied:

- the benchmark's scientific purpose is understood;
- the mathematical and numerical methodology is documented sufficiently for
  review;
- generation is reproducible from recorded provenance;
- every retained metric has a stated scientific purpose;
- every comparison policy has a defensible rationale;
- the observed values have been inspected directly;
- relevant limitations and uncertainty are understood;
- the candidate is not derived merely by relaxing limits until the current
  implementation passes; and
- the reviewer considers the candidate suitable for future comparison.

No automatic approval mechanism shall exist.

## 8. Minimum metadata

An approved scientific reference should contain only the metadata needed to
identify, reproduce, understand, and review the observation.

### 8.1 Identity

Required identity should include:

- a stable human-readable reference identifier; and
- a reference schema version.

A content digest may be added later if integrity requirements justify it, but it
is not required for the first implementation.

### 8.2 Provenance

Required provenance should include:

- source repository commit;
- package version;
- Julia version;
- generation date;
- generating validation suite or case identifier;
- relevant solver configuration;
- numeric type and precision where material; and
- initial-condition identifier or random seed where material.

Existing structured validation metadata should be reused rather than duplicated
when practical.

### 8.3 Scientific review

Required review metadata should include:

- reviewer;
- approval date;
- concise scientific rationale;
- benchmark scope;
- retained metrics; and
- known limitations where relevant.

Associated publications, release tags, issue references, or independent reviews
may be recorded when useful, but they are optional.

### 8.4 Method description

The reference should identify the methodology sufficiently to explain what the
observation represents. This may be a concise description or a stable link to a
repository design or benchmark document.

The design does not require a general scientific-document management system.

## 9. Retained metrics and comparison policies

Approved references retain only metrics selected deliberately during scientific
review.

For every retained metric, the reference must record:

- case identifier;
- metric identifier;
- approved observed value;
- value kind and scientific role;
- unit or scale where applicable; and
- explicit comparison policy.

The initial supported policies remain:

- exact comparison for discrete values that must match exactly; and
- tolerance-based comparison for finite scalar values with scientifically
  justified absolute and/or relative tolerance.

Trend-based comparison is deferred until a concrete scientific case requires it
and its interpretation is designed explicitly.

Baseline values and comparison tolerances serve different purposes. The value
records the approved observation. The policy records the allowed comparison.
Changing either requires explicit review.

## 10. Immutability and preservation

Approved scientific references are immutable.

After approval, their observed values, retained metrics, comparison policies,
provenance, and scientific rationale must not be edited in place.

If an error is found or scientific understanding improves:

1. preserve the existing reference for audit and reproduction;
2. create a new candidate;
3. perform a new scientific review;
4. approve a new reference if justified; and
5. record why the new reference replaces the earlier comparison point.

The first implementation does not require a complex formal lifecycle. Historical
references remain ordinary immutable files and may be selected explicitly when
reproducing earlier work.

## 11. Explicit selection and comparison

A scientific comparison must use an explicitly identified approved reference.

The framework must not:

- choose the newest file automatically;
- infer compatibility from package version alone;
- silently fall back to another reference;
- generate a reference from the current run; or
- update a reference after comparison.

The comparison output should identify:

- the exact selected reference;
- every retained metric;
- approved and observed values;
- comparison policy;
- absolute difference where meaningful;
- allowed difference where meaningful;
- missing or incompatible observations; and
- derived comparison status.

Reports should present evidence clearly enough for a reviewer to determine
whether an observed difference is a regression, an improvement, an expected
methodological consequence, or an unresolved anomaly.

## 12. Replacement policy

A new approved scientific reference should normally be created only when there
is a scientific reason, such as:

- demonstrably improved numerical accuracy;
- improved regularization methodology;
- improved benchmark formulation;
- improved independent or high-precision reference data;
- discovery of an error or limitation in the earlier reference;
- a justified change in retained metrics; or
- a justified change in comparison policy.

Routine source changes, refactoring, package-version changes, or release activity
do not by themselves justify a new approved scientific reference.

A replacement rationale must explain what changed scientifically and why the
new observation is a better comparison point.

## 13. Ease-of-use requirement

The normal workflow should remain understandable as four explicit actions:

```text
Generate candidate
        |
        v
Inspect candidate and evidence
        |
        v
Approve after scientific review
        |
        v
Compare future validation run
```

A contributor should be able to understand why a reference is trusted, how it
was produced, and how it is used by reading this document, the workflow
document, and the reference file itself.

The workflow should not require knowledge of an abstract baseline-management
architecture.

## 14. Relationship to existing VF-4 workflow

VF-4 already provides the essential technical foundation:

- deterministic suite reports;
- explicit retained metric policies;
- immutable reviewed reference records;
- deterministic comparison records;
- explicit candidate preparation;
- a read-only comparison workflow; and
- manual end-to-end scientific review.

VF-5 should extend this foundation rather than replace it. Implementation should
first determine which accepted design requirements are not yet represented by
the existing `ValidationReferenceRecord` and workflow.

No existing working capability should be duplicated under a second abstraction
without a demonstrated need.

## 15. Minimum implementation sequence

Implementation should proceed in small stages.

### Stage 1: Gap analysis and approved-reference representation

- inspect the current reference types, serialization, and workflow;
- identify the minimum missing identity, provenance, and review fields;
- extend or reuse the existing representation rather than creating a parallel
  system;
- define immutability through construction and read-only workflow behaviour; and
- add focused unit tests.

### Stage 2: Deterministic serialization and loading

- serialize the accepted minimum metadata deterministically;
- read it back with strict validation;
- preserve ordering and value semantics;
- reject malformed, incomplete, or incompatible records clearly; and
- test round trips and failure paths.

### Stage 3: Evidence-centred comparison and presentation

- compare only explicitly retained metrics;
- identify the selected reference in every result;
- report approved values, observations, differences, and policies;
- retain deterministic machine-readable output; and
- keep scientific interpretation outside automated logic.

### Stage 4: Real scientific application

Apply the completed workflow to a meaningful numerical question, such as:

- Cartesian versus KS close-encounter accuracy;
- KS versus Levi-Civita behaviour in an appropriate planar case;
- solver-profile comparison against a high-precision reference; or
- regularized collision-continuation accuracy.

This stage is required to demonstrate that the infrastructure produces a real
scientific return before additional baseline features are considered.

## 16. Acceptance criteria for VF-5

VF-5 is complete when:

- the accepted scientific philosophy is documented consistently;
- an approved scientific reference is distinguishable from a candidate;
- minimum identity, provenance, methodology, and review metadata are preserved;
- approved references are immutable and explicitly selected;
- no automatic approval, selection, interpretation, or rewriting occurs;
- comparison output presents the relevant evidence clearly;
- malformed or incomplete references fail explicitly;
- the workflow remains simple enough for routine contributor use;
- package tests and scientific validation pass; and
- the reference capability is applied to at least one meaningful numerical or
  regularization comparison.

## 17. Long-term philosophy

The long-term success of ThreeBody3D will be measured by the scientific quality
of its numerical solutions rather than by the sophistication of its supporting
infrastructure. The approved scientific reference system exists to provide
confidence that each successive iteration genuinely improves accuracy and
quality.
