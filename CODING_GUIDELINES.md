# ThreeBody3D Coding Guidelines

## Project Philosophy

ThreeBody3D is a scientific software project.

Its primary purpose is to produce accurate and scientifically trustworthy
solutions of the three-body problem.

All engineering decisions should support that objective.

Priority order:

1. Scientific correctness
2. Numerical accuracy
3. Robustness
4. Simplicity
5. Ease of use
6. Performance

Performance is important, but never at the expense of correctness.

---

# Development Principles

## Make small changes

Each implementation stage should be small.

Avoid combining unrelated improvements into a single commit.

Each commit should have one clear purpose.

---

## Preserve behaviour

Unless explicitly requested, do not change public behaviour.

Bug fixes should be narrowly targeted.

Avoid introducing unintended API changes.

---

## Never modify unrelated files

Only edit files necessary for the requested implementation.

Do not perform opportunistic refactoring.

Do not reformat unrelated code.

---

## Keep the repository buildable

Before considering any task complete:

- run `Pkg.test()`
- fix all regressions introduced by the change

If appropriate, also run

- `JET.report_package()`

---

## Scientific validation

Validation infrastructure exists to improve confidence in numerical accuracy.

It is not the primary goal of the project.

New infrastructure should directly contribute to:

- improved regularization
- improved numerical accuracy
- improved scientific confidence

Avoid infrastructure that exists only for its own sake.

---

# Numerical Priorities

Prefer:

- mathematically rigorous algorithms
- deterministic behaviour
- reproducible validation
- well-conditioned numerical methods

Avoid shortcuts that sacrifice numerical quality.

---

# Regularization

Regularization should satisfy:

- mathematically justified
- reversible where appropriate
- scientifically documented
- independently validated

Automatic switching should preserve continuity and minimise unnecessary
coordinate transitions.

---

# Testing

Every new feature should include appropriate tests.

Tests should be:

- deterministic
- reproducible
- scientifically meaningful

Regression tests are preferred whenever fixing bugs.

---

# Documentation

Public APIs should remain clearly documented.

When behaviour changes:

- update documentation
- update examples if necessary
- update implementation plans if appropriate

---

# Git Workflow

Prefer:

one implementation stage
→ tests
→ review
→ commit

Keep commits small and descriptive.

---

# When Unsure

Prefer asking for clarification over making assumptions.

Never fabricate missing repository contents.

Inspect existing code before modifying it.

Follow the existing project style unless explicitly instructed otherwise.
