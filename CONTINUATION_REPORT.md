# ThreeBody3D – Continuation Report for Codex

**Date:** 28 July 2026

---

# Project Overview

ThreeBody3D is a scientific Julia package for solving the Newtonian three-body initial-value problem.

The project's primary objective is to produce **scientifically trustworthy numerical solutions**.

This is **not** primarily a software engineering exercise. Engineering exists to support numerical quality.

Project priorities are:

1. Scientific correctness
2. Numerical accuracy
3. Robustness
4. Simplicity
5. Ease of use
6. Performance

Performance improvements must never reduce numerical quality.

---

# Current Repository

Repository:

ThreeBody3D

Development branch:

v0.5-development

The repository uses Git and all work should be performed as small, self-contained commits.

---

# Current Development Program

The project is currently implementing the Version 0.5 scientific validation programme together with improvements to automatic regularization.

The validation framework is intended to provide scientifically reproducible evidence that successive numerical improvements genuinely improve solution quality.

Validation infrastructure is **not** the project's primary goal.

Its purpose is to improve confidence in future numerical algorithms.

---

# Development Philosophy

Before implementing any change:

* inspect the existing code
* understand the current architecture
* preserve existing behaviour unless intentionally changing it

Never reconstruct missing code.

Never invent repository contents.

Never modify unrelated files.

Prefer asking for clarification over making assumptions.

---

# Scientific Priorities

Always favour:

* mathematically rigorous algorithms
* deterministic execution
* reproducible validation
* clean numerical design

Avoid engineering shortcuts that reduce numerical quality.

---

# Automatic Regularization Philosophy

Automatic regularization exists to improve robustness during close encounters while preserving solution quality.

Important design goals include:

* reversible coordinate transforms
* continuity across switching boundaries
* minimal switching
* preservation of physical trajectory
* deterministic switching decisions

The switching controller should remain explainable and scientifically auditable.

---

# Validation Philosophy

Validation should provide evidence that:

* numerical accuracy has improved
* behaviour remains deterministic
* previous capability has not regressed

Infrastructure that exists only for its own sake should be avoided.

Every new capability should ultimately support better numerical methods.

---

# Current Completed Work

The project already contains:

* structured validation framework
* deterministic validation records
* scientific reference records
* manual scientific approval workflow
* performance benchmark infrastructure
* automatic regularization framework
* switching diagnostics
* KS regularization
* extensive benchmark suite
* JET compatibility improvements

All previous implementation stages were intentionally developed as small commits with tests after every stage.

Continue this discipline.

---

# Immediate Next Task

Current implementation stage:

AS-4b2

Objective:

Extend automatic entry decision provenance handling.

Required behaviour:

`automatic_entry_decision(...)` should accept a keyword parameter

```
crossing_provenance::Symbol = :algebraic
```

and forward it into the decision-evidence construction.

Decision evidence should preserve provenance information generated earlier in the switching pipeline.

Expected behavioural impact:

No public API change.

No algorithmic change.

Only provenance bookkeeping should be extended.

---

# Likely Files

Expected implementation files include:

```
src/Regularization/AutomaticSwitching.jl
```

Expected test files include the existing automatic-switching tests.

Inspect the repository before modifying any files.

---

# Required Workflow

For every implementation stage:

1. Inspect the existing implementation.
2. Make the smallest possible change.
3. Update or add tests where appropriate.
4. Run:

```
Pkg.test()
```

5. If appropriate, run:

```
using Revise
using JET
JET.report_package(
    ThreeBody3D;
    target_modules=(ThreeBody3D,),
    toplevel_logger=nothing,
)
```

6. Resolve any issues introduced by the change.
7. Produce a clean Git diff.
8. Commit only when tests pass.

---

# Git Expectations

Commits should be:

* small
* scientifically meaningful
* easy to review
* reversible

Do not combine unrelated changes.

Do not perform opportunistic refactoring.

Do not reformat unrelated code.

---

# Code Style

Follow the existing repository conventions.

Prefer explicit, readable code over clever code.

Preserve public APIs unless explicitly instructed otherwise.

Maintain deterministic behaviour.

---

# Documentation

If public behaviour changes:

* update documentation
* update examples if necessary
* update implementation plans where appropriate

Otherwise avoid unnecessary documentation churn.

---

# Verification Before Completion

A task is not complete until:

* repository builds successfully
* tests pass
* newly added tests pass
* no unrelated files were modified
* Git diff contains only intended changes

---

# Collaboration Model

The project uses two complementary assistants.

**ChatGPT**

Responsible for:

* scientific reasoning
* numerical analysis
* architecture
* implementation planning
* algorithm review
* design decisions

**Codex**

Responsible for:

* repository inspection
* implementation
* test execution
* iterative debugging
* Git operations
* verified code changes

When implementation questions arise, prefer preserving the scientific design over introducing expedient engineering changes.

The long-term objective is not merely to add features, but to build a scientifically reliable research-quality three-body solver whose numerical accuracy improves demonstrably with each release.
