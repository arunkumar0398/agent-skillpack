---
name: skill-evaluation-pipeline
description: A/B testing pipeline for prompts, skills, and workflows - validates improvements through structured comparison and benchmarking
version: 1.0.0
tags:
  - evaluation
  - testing
  - comparison
  - benchmarking
agents:
  - grader
  - analyzer
  - comparator
  - planner
  - implementer
  - reviewer
  - validator
  - orchestrator
category: meta
---

# Skill Evaluation Pipeline

## Overview

A systematic A/B testing pipeline for evaluating prompts, skills, and workflows. Uses blind comparison, structured grading, and benchmarking to validate improvements before shipping. Ensures changes are measurably better, not just different.

## When to Use

- **Skill optimization**: Comparing two versions of a skill to determine which performs better
- **Prompt evaluation**: Testing prompt variants against specific success criteria
- **Workflow validation**: Benchmarking workflow changes against baseline performance
- **Regression detection**: Ensuring updates don't degrade existing capabilities

## Pipeline Steps

```
Draft → Test → Grade → Benchmark → Iterate
```

1. **Draft**: Create test prompts and evaluation criteria
2. **Test**: Run both variants against identical inputs
3. **Grade**: Score outputs per assertion (PASS/FAIL)
4. **Benchmark**: Calculate win rates and performance metrics
5. **Iterate**: Ship if >60% win rate, refine otherwise

## Agent Roles

| Agent | Responsibility |
|-------|----------------|
| **grader** | Scores outputs PASS/FAIL per assertion, extracts evidence |
| **analyzer** | Detects patterns, suggests improvements |
| **comparator** | Performs blind A/B comparison, determines winner |
| **planner** | Designs test suite and evaluation criteria |
| **implementer** | Executes test runs and collects outputs |
| **reviewer** | Validates methodology and scoring consistency |
| **validator** | Confirms metrics meet shipping thresholds |
| **orchestrator** | Coordinates pipeline execution and state |

## Test Prompt Design

- Create **5-10 diverse prompts** covering edge cases
- Include baseline, stress, and boundary scenarios
- Each prompt must have clear expected behavior
- Document assumptions for each test case

## Blind Comparison Methodology

1. Anonymize outputs (label A/B randomly)
2. Score independently without knowing which is "new"
3. Use consistent rubric across all comparisons
4. Document reasoning for each score
5. Aggregate scores for final determination

## Benchmark Metrics

| Metric | Description |
|--------|-------------|
| **Win rate** | Percentage of times variant beats baseline |
| **Assertion pass rate** | Ratio of passed assertions to total |
| **Timing** | Execution time comparison |
| **Consistency** | Variance in scores across runs |

## Iteration Rules

- **Ship if**: Win rate > 60% AND assertion pass rate > 80%
- **Iterate if**: Win rate 40-60% (inconclusive)
- **Reject if**: Win rate < 40% OR assertion pass rate < 60%

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "This feels better" | Measure it - feelings aren't metrics |
| "It's just a small change" | Small changes can have large impacts |
| "We don't need to test everything" | Test at least the critical paths |
| "The old way was fine" | Baseline matters - quantify "fine" |
| "We'll fix it later" | Ship with evidence or don't ship |

## Red Flags

- Skipping blind comparison
- Testing only happy-path scenarios
- No baseline comparison
- Inconsistent grading criteria
- Shipping without meeting thresholds

## Verification Checklist

- [ ] Test prompts cover diverse scenarios
- [ ] Blind comparison completed
- [ ] Grading consistent across all outputs
- [ ] Metrics meet shipping thresholds
- [ ] Edge cases documented
- [ ] Baseline performance recorded
- [ ] No regressions detected
- [ ] Evidence collected for all scores
