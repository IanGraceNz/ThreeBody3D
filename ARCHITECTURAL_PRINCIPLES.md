# Architectural Principles

**Project:** ThreeBody3D

---

# Purpose

ThreeBody3D is a scientific software project whose purpose is to produce numerically accurate, scientifically trustworthy solutions of the Newtonian three-body initial-value problem.

The software architecture exists to support this scientific objective.

Whenever architectural decisions involve trade-offs, preference should be given to improving scientific quality rather than increasing implementation complexity or adding features.

---

# Core Philosophy

The project is founded on several guiding principles.

## 1. Scientific correctness comes first

Scientific validity is the primary objective.

No optimisation, feature, convenience, or architectural simplification should reduce scientific correctness.

If a conflict exists between elegance and correctness, correctness wins.

---

## 2. Numerical accuracy is more important than performance

The project seeks the highest practical numerical accuracy.

Execution speed is valuable only after scientific quality has been established.

Performance improvements must never knowingly reduce solution quality.

---

## 3. Engineering serves the science

Infrastructure exists to support better numerical methods.

Validation systems, benchmarking frameworks, testing infrastructure, diagnostics, and tooling are valuable only insofar as they improve confidence in the numerical algorithms or enable future scientific improvements.

Avoid infrastructure whose primary purpose is architectural elegance rather than scientific benefit.

---

# Modular Scientific Design

Scientific algorithms should be decomposed into independently understandable components.

Examples include:

* coordinate transformations
* regularization methods
* switching logic
* numerical integration
* validation
* diagnostics

Each component should have a clearly defined responsibility.

Avoid tightly coupling unrelated numerical concepts.

---

# Separation of Responsibilities

The architecture intentionally separates several concerns.

Examples include:

* numerical integration versus regularization
* regularization versus switching policy
* switching policy versus evidence collection
* validation execution versus scientific approval
* measurement versus interpretation

Each subsystem should remain independently testable.

---

# Automatic Regularization

Automatic regularization exists to improve robustness while minimising disruption to the physical trajectory.

The preferred architecture is:

Observation

↓

Decision

↓

Coordinate transformation

↓

Integration

↓

Return

Each stage should have a clearly defined purpose.

Switching decisions should remain deterministic, explainable, and scientifically auditable.

---

# Explainable Decision Making

Automatic decisions should be supported by evidence.

Where practical, the system should retain enough information to explain:

* why a switch occurred
* why a switch did not occur
* which conditions were satisfied
* which numerical thresholds were crossed

Scientific software should make its behaviour understandable rather than mysterious.

---

# Deterministic Behaviour

Given identical inputs, the software should produce identical results whenever practical.

Avoid unnecessary dependence on:

* randomness
* execution order
* platform-specific behaviour

Deterministic behaviour greatly simplifies scientific validation.

---

# Reproducible Validation

Validation results should be reproducible.

Scientific conclusions should not depend upon undocumented execution details.

Validation records should preserve sufficient information for later review.

---

# Scientific Baselines

Reference solutions represent scientific evidence rather than software tests.

Approved reference records establish the current scientific baseline.

Future numerical improvements should demonstrate measurable improvement relative to these references.

The project should continually increase scientific confidence through comparison with trusted reference solutions.

---

# Progressive Improvement

Each released version should improve at least one of:

* numerical accuracy
* robustness
* scientific validation
* diagnostic capability
* usability

without degrading existing validated behaviour.

The project values steady scientific progress over rapid feature growth.

---

# API Philosophy

The public API should remain:

* simple
* predictable
* well documented
* stable

Internal implementation may evolve significantly without unnecessarily affecting user code.

Backward compatibility should be preserved whenever practical.

---

# Testing Philosophy

Tests exist to demonstrate correctness rather than merely increase coverage.

Preference should be given to tests that verify:

* mathematical identities
* conservation laws
* analytical solutions
* regression against approved references
* deterministic behaviour

Scientific significance is more valuable than large numbers of superficial tests.

---

# Documentation Philosophy

Documentation is part of the scientific record.

Major numerical algorithms should explain:

* the mathematical basis
* implementation decisions
* assumptions
* limitations
* references where appropriate

Design documents should explain why decisions were made, not merely describe the resulting code.

---

# Git Philosophy

The commit history should tell the scientific story of the project.

Each commit should represent one logical improvement.

Large mixed-purpose commits should be avoided.

The history should remain understandable to future researchers.

---

# Long-Term Vision

ThreeBody3D is intended to evolve into a research-quality numerical toolkit for the three-body problem.

Future work is expected to include improved regularization methods, more rigorous validation, broader benchmark coverage, and increasingly accurate numerical techniques.

Every architectural decision should be evaluated by asking:

> **"Will this help us discover, validate, and deliver more accurate three-body solutions?"**

If the answer is "no", the change should be reconsidered.

Architecture should remain a servant of the science, never its master.
