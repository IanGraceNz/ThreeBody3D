# V0.6 Scientific Accuracy Improvement Design

## Abstract

This document defines the scientific methodology and investigation programme for Version 0.6 of ThreeBody3D. Its purpose is to guide the evidence-driven improvement of numerical methods through successive cycles of measurement, explanation, and algorithmic refinement. The programme emphasises scientific correctness, reproducibility, and objective validation, ensuring that future numerical improvements are supported by experimental evidence rather than intuition or premature optimisation.

---

# 1. Introduction

The primary objective of ThreeBody3D is to produce scientifically accurate and robust numerical solutions to the three-body initial value problem. Previous development has established a validated numerical foundation through the implementation of regularisation methods, reproducible scientific validation, approved scientific reference baselines, deterministic reporting, and comprehensive software quality assurance.

Version 0.6 marks a transition from validation infrastructure towards evidence-driven numerical improvement. Rather than expanding validation infrastructure or introducing additional numerical techniques, the focus shifts towards improving the scientific accuracy of the existing solver. This requires a disciplined process that identifies the most significant limitations of the current implementation before algorithmic modifications are considered.

The purpose of this document is to define that process. It establishes the scientific methodology by which future improvements will be investigated, evaluated, and accepted. The resulting programme is intended to ensure that each successive iteration of ThreeBody3D is supported by objective experimental evidence and represents a genuine improvement in solver quality.

---

# 2. Background

Versions 0.4 and 0.5 established the numerical and technical foundations upon which future development can confidently proceed.

Version 0.4 introduced mathematically rigorous regularisation techniques together with extensive analytical and numerical validation, demonstrating the correctness of the implemented formulations across representative benchmark problems.

Version 0.5 extended this foundation by introducing a comprehensive scientific validation framework capable of producing deterministic validation reports, approved scientific reference baselines, reproducible acceptance criteria, provenance tracking, and performance benchmarking. The development environment was further strengthened through static analysis using JET and continued software quality assurance.

Collectively, these developments provide a reliable platform for scientific investigation. Future development can therefore focus primarily upon improving numerical methods rather than establishing additional validation infrastructure.

---

# 3. Current Scientific Baseline

At the commencement of Version 0.6, ThreeBody3D provides:

- mathematically validated regularisation methods;
- automatic regularisation and switching capability;
- reproducible scientific validation;
- approved scientific reference baselines;
- deterministic validation reporting;
- provenance tracking for scientific results;
- reproducible performance benchmarking;
- comprehensive automated testing;
- a modular and maintainable software architecture.

This baseline provides sufficient confidence that future investigations can focus on improving numerical accuracy while relying upon the existing validation infrastructure to evaluate objectively.

---

# 4. Philosophy

The scientific development of ThreeBody3D shall continue to be guided by the following principles.

- Scientific correctness takes precedence over new functionality.
- Numerical improvements shall be supported by objective experimental evidence.
- Algorithmic modifications shall be introduced only when justified by an improved understanding of the numerical behaviour.
- Simplicity shall be preferred wherever it achieves equivalent scientific outcomes.
- All scientific conclusions shall remain reproducible and independently verifiable.

These principles are intended to ensure that development remains focused upon producing scientifically trustworthy numerical methods rather than increasing implementation complexity.

---

# 5. Scientific Objectives

The objectives of Version 0.6 are to:

1. quantitatively measure the current numerical accuracy of the solver across representative numerical regimes;
2. explain the dominant numerical mechanisms responsible for observed errors;
3. identify and evaluate candidate algorithmic improvements using objective experimental evidence;
4. validate all accepted improvements against approved scientific reference baselines;
5. establish an improved scientific baseline for future development.

Successful completion of these objectives will increase confidence that subsequent versions of ThreeBody3D provide demonstrably improved numerical accuracy while maintaining reproducibility and software quality.

---

# 6. Evidence-Driven Development Process

The scientific accuracy programme follows a three-stage methodology:

> **Measure → Explain → Improve**

The existing solver is first measured through objective and reproducible computational experiments to establish its numerical behaviour across representative benchmark problems and numerical regimes. The resulting evidence is then used to explain the dominant mechanisms responsible for the observed behaviour. Only after sufficient scientific understanding has been established are algorithmic improvements considered.

This methodology ensures that implementation is driven by scientific evidence rather than intuition, speculation, or premature optimisation.

## 6.1 Evidence-Driven Development

Algorithmic improvements are treated as scientific hypotheses requiring experimental validation. Every proposed algorithmic modification is therefore supported by objective experimental evidence demonstrating both the existence of a numerical limitation and the scientific benefit of the proposed improvement.

Where the available evidence is inconclusive, the preferred outcome is to retain the existing algorithm until further investigation provides sufficient evidence for change.

## 6.2 Scientific Methodology

Each investigation shall proceed through the following activities.

### Measure

Design and perform controlled computational experiments that produce objective, reproducible measurements of solver behaviour under clearly defined conditions.

### Explain

Analyse the experimental evidence to identify the numerical mechanisms responsible for the observed behaviour and formulate evidence-based explanations.

### Improve

Implement the smallest algorithmic changes capable of addressing the identified numerical mechanisms and evaluate their measurable benefit using the established validation framework.

## 6.3 Experimental Design

Every investigation shall employ experiments specifically designed to answer a defined scientific question. Experimental variables shall be controlled wherever practical so that observed behaviour can be attributed to identifiable numerical mechanisms with minimal ambiguity.

Experiments shall be reproducible, objectively measurable, and directly relevant to the scientific question under investigation.

## 6.4 Scientific Validation

Scientific conclusions shall be supported by approved scientific reference baselines, reproducible validation procedures, and quantitative experimental evidence.

Acceptance of an algorithmic improvement requires demonstration of a measurable benefit without unacceptable degradation of numerical robustness, reproducibility, or software quality.

## 6.5 Continuous Scientific Improvement

Completion of an investigation establishes an improved understanding of the solver. That understanding forms the basis for subsequent investigations and future algorithmic development.

Each accepted improvement establishes a new scientific baseline from which the next cycle of measurement, explanation, and improvement begins.

---

# 7. Scientific Investigation Programme

The Scientific Investigation Programme applies the evidence-driven methodology defined in the previous section to the continued improvement of the ThreeBody3D solver.

The programme consists of three sequential investigations. Each investigation addresses a specific scientific question whose resolution provides the evidence required for the subsequent investigation. Together, they establish a structured progression from objective measurement of solver behaviour to evidence-supported algorithmic improvement.

Each investigation follows a common structure:

- **Scientific Question** — the question to be answered.
- **Motivation** — why the question is important.
- **Experimental Design** — the experiments designed to answer the question.
- **Expected Evidence** — the measurements to be collected.
- **Scientific Outcomes** — the understanding expected from the investigation.
- **Transition Criteria** — the evidence required before proceeding.

## 7.1 Investigation 1 — Quantifying Numerical Error

### Scientific Question

What are the dominant magnitudes and distributions of numerical error across the current ThreeBody3D solver?

### Motivation

Objective improvement of numerical methods requires quantitative understanding of the current accuracy of the solver. This investigation establishes the numerical baseline against which future improvements will be evaluated.

### Experimental Design

The investigation shall include:

- execution of the complete validation suite across all existing benchmark problems;
- comparison against approved scientific reference solutions;
- evaluation of all supported solver profiles;
- controlled tolerance sweeps over representative integration tolerances;
- sampling of defined numerical regimes, including variations in encounter severity, hierarchy, timescale separation, integration duration, and regularisation activity;
- precision comparisons where scientifically relevant;
- repeated execution where required to confirm reproducibility.

### Expected Evidence

The investigation shall collect quantitative measurements including:

- position and velocity errors relative to approved scientific reference solutions;
- conservation of total energy;
- conservation of linear momentum;
- conservation of angular momentum;
- centre-of-mass residuals;
- convergence behaviour with decreasing tolerance;
- computational cost as a function of achieved accuracy;
- benchmark-specific error distributions.

### Scientific Outcomes

Completion of this investigation is expected to:

- establish the current numerical accuracy baseline;
- identify benchmarks contributing the largest numerical errors;
- identify numerical regimes in which solver accuracy deteriorates;
- distinguish systematic behaviour from isolated anomalies;
- identify numerical behaviours requiring further investigation.

### Transition Criteria

The investigation is complete when the dominant numerical behaviours have been identified and quantified with sufficient confidence to guide Investigation 2.

---

## 7.2 Investigation 2 — Explaining Numerical Error

### Scientific Question

What numerical mechanisms are responsible for the dominant errors identified in Investigation 1?

### Motivation

Numerical improvements should address the underlying causes of observed errors rather than their symptoms. This investigation seeks to identify the mechanisms responsible for the dominant numerical behaviours measured during Investigation 1.

### Experimental Design

The investigation shall include controlled experiments designed to isolate candidate numerical mechanisms, including:

- automatic switching behaviour;
- regularisation parameters;
- integration settings;
- state reconstruction;
- interpolation;
- arithmetic precision;
- other candidate mechanisms identified during Investigation 1.

### Expected Evidence

The investigation shall collect quantitative evidence describing the contribution of each candidate mechanism to the observed numerical errors.

### Scientific Outcomes

Completion of this investigation is expected to:

- identify the dominant numerical mechanisms contributing to observed errors;
- distinguish primary mechanisms from secondary effects;
- identify algorithmic components requiring improvement.

### Transition Criteria

The investigation is complete when sufficient evidence has been obtained to explain the dominant numerical behaviours identified in Investigation 1.

---

## 7.3 Investigation 3 — Improving Numerical Methods

### Scientific Question

Which algorithmic improvements provide the greatest demonstrable improvement in solver accuracy?

### Motivation

Algorithmic modifications should be supported by objective experimental evidence demonstrating measurable benefit.

### Experimental Design

The investigation shall include:

- implementation of candidate algorithmic improvements proposed by Investigation 2;
- validation against approved scientific reference baselines;
- comparison with the established numerical baseline;
- evaluation of numerical accuracy, robustness, reproducibility, and computational cost.

### Expected Evidence

The investigation shall collect quantitative comparisons between the baseline implementation and each proposed algorithmic improvement.

### Scientific Outcomes

Completion of this investigation is expected to:

- identify and validate algorithmic improvements producing measurable benefit;
- reject modifications that fail to demonstrate objective improvement;
- establish an improved numerical baseline for subsequent development.

### Transition Criteria

The investigation is complete when all candidate algorithmic improvements have been evaluated and sufficient evidence has been obtained to support evidence-based conclusions regarding their adoption or rejection.

---

# 8. Programme Management

The investigations defined in this programme should normally be undertaken sequentially, as each investigation provides evidence required by the subsequent investigation. Where new evidence indicates that the programme should be refined, investigations may be revised provided that the scientific rationale for the revision is documented.

The programme is intended to guide scientific development rather than prescribe inflexible implementation tasks. Scientific judgement should therefore be exercised whenever new evidence demonstrates that an alternative course of investigation is better supported.

---

# 9. Acceptance Criteria

Version 0.6 shall be considered successful when:

- each investigation has answered its scientific question using objective experimental evidence;
- all conclusions are supported by reproducible validation results;
- algorithmic modifications are supported by objective experimental evidence;
- accepted improvements demonstrate measurable benefit relative to the established numerical baseline;
- all accepted improvements have been validated against approved scientific reference baselines;
- the resulting solver establishes an improved scientific baseline for subsequent development.

---

# 10. Programme Completion

The Version 0.6 Scientific Accuracy Improvement Programme is complete when the planned investigations have been concluded and their findings have been incorporated into the scientific baseline where justified by the available evidence.

Completion of the programme does not imply that numerical improvement has ended. Rather, it establishes an improved understanding of the current solver together with an improved numerical baseline from which future investigations may proceed.

The completion of one investigation programme therefore provides the foundation for the next, supporting the continuous improvement of the ThreeBody3D solver through evidence-driven scientific investigation.
