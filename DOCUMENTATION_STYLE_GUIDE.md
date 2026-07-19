# DOCUMENTATION_STYLE_GUIDE

**Status:** Repository Standard  
**Applies to:** All Markdown documentation in ThreeBody3D

## 1. Purpose

This guide defines the documentation conventions used throughout the
ThreeBody3D repository. Its goals are to:

- keep documentation readable in Visual Studio Code and GitHub;
- maintain mathematical precision without requiring Markdown extensions;
- make engineering decisions easy to understand;
- ensure all design documents have a consistent structure.

---

## 2. Markdown Compatibility

Documentation shall render correctly in:

- Visual Studio Code
- GitHub
- GitLab
- Azure DevOps
- Plain Markdown viewers

Do **not** require MathJax or KaTeX to read repository documentation.

---

## 3. Mathematics

Avoid LaTeX delimiters such as:

    \[ ... \]
    \( ... \)

Instead write equations as indented text blocks.

Example

Relative equation of motion

    r¨ = -μ r / r³ + fpert

where

    r      relative position vector
    μ      gravitational parameter
    fpert  perturbing acceleration

---

## 4. Unicode Symbols

Prefer Unicode where widely supported.

Examples:

    μ  Δ  ∇  ×  ·  ≤  ≥  ∞
    α  β  γ  θ  λ  π
    ²  ³  √  ‖x‖

Avoid obscure symbols that render inconsistently.

---

## 5. Engineering First

Repository documents are engineering specifications, not journal papers.

Each major section should answer:

- What are we doing?
- Why is it needed?
- What decision was made?
- How will it be validated?

Long mathematical derivations belong in the cited literature unless essential.

---

## 6. Standard Document Structure

Use the following headings whenever practical:

1. Purpose
2. Background
3. Definitions
4. Requirements
5. Design Decisions
6. Mathematical Formulation
7. Software Architecture
8. Validation Strategy
9. Testing Strategy
10. Implementation Plan
11. References

---

## 7. Conventions

State conventions explicitly near the beginning of the document.

Examples:

- Coordinate ordering
- Units
- Time conventions
- Variable naming
- Precision model
- Sign conventions

Never assume readers know which convention has been adopted.

---

## 8. Equations

Immediately explain every displayed equation.

Avoid introducing symbols without definitions.

Prefer concise equations supported by explanatory text.

---

## 9. Diagrams

Prefer diagrams over lengthy prose whenever they improve understanding.

Examples:

- Coordinate systems
- Module architecture
- Data flow
- Switching timeline
- State transformations

---

## 10. Validation

Design documents should specify:

- acceptance criteria;
- measurable outputs;
- expected invariants;
- failure conditions.

Avoid qualitative statements that cannot be tested.

---

## 11. Repository Philosophy

ThreeBody3D prioritises:

1. Scientific correctness
2. Numerical robustness
3. Reproducibility
4. Clean architecture
5. Long-term maintainability

Documentation should reflect these priorities.

---

## 12. Style Summary

- Use plain Markdown.
- Use Unicode mathematics.
- Avoid LaTeX.
- Explain engineering decisions.
- Cite references instead of reproducing proofs.
- Keep terminology consistent.
- Write for future contributors as well as current developers.
