# Evaluation Schemas

## Evaluation Input Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "EvaluationInput",
  "type": "object",
  "required": ["test_prompts", "assertions"],
  "properties": {
    "test_prompts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "input", "expected_behavior"],
        "properties": {
          "id": { "type": "string" },
          "input": { "type": "string" },
          "expected_behavior": { "type": "string" },
          "tags": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "assertions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "description", "type"],
        "properties": {
          "id": { "type": "string" },
          "description": { "type": "string" },
          "type": { "enum": ["contains", "excludes", "format", "length", "custom"] }
        }
      }
    }
  }
}
```

## Grading Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "GradingOutput",
  "type": "object",
  "required": ["test_prompt_id", "results"],
  "properties": {
    "test_prompt_id": { "type": "string" },
    "results": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["assertion_id", "score", "evidence"],
        "properties": {
          "assertion_id": { "type": "string" },
          "score": { "enum": ["PASS", "FAIL", "NO_EVIDENCE"] },
          "evidence": { "type": "string" },
          "confidence": { "enum": ["high", "medium", "low"] },
          "notes": { "type": "string" }
        }
      }
    }
  }
}
```

## Benchmark Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "BenchmarkOutput",
  "type": "object",
  "required": ["baseline", "variant", "metrics"],
  "properties": {
    "baseline": {
      "type": "object",
      "required": ["name", "version"],
      "properties": {
        "name": { "type": "string" },
        "version": { "type": "string" }
      }
    },
    "variant": {
      "type": "object",
      "required": ["name", "version"],
      "properties": {
        "name": { "type": "string" },
        "version": { "type": "string" }
      }
    },
    "metrics": {
      "type": "object",
      "required": ["win_rate", "assertion_pass_rate", "timing"],
      "properties": {
        "win_rate": { "type": "number", "minimum": 0, "maximum": 100 },
        "assertion_pass_rate": { "type": "number", "minimum": 0, "maximum": 100 },
        "timing": {
          "type": "object",
          "properties": {
            "baseline_ms": { "type": "number" },
            "variant_ms": { "type": "number" },
            "delta_percent": { "type": "number" }
          }
        },
        "total_comparisons": { "type": "integer" },
        "ties": { "type": "integer" }
      }
    }
  }
}
```

## Comparison Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "ComparisonOutput",
  "type": "object",
  "required": ["comparison_id", "output_a", "output_b", "winner"],
  "properties": {
    "comparison_id": { "type": "string" },
    "output_a": {
      "type": "object",
      "required": ["label", "scores", "weighted_score"],
      "properties": {
        "label": { "const": "A" },
        "scores": {
          "type": "object",
          "properties": {
            "accuracy": { "type": "number", "minimum": 0, "maximum": 100 },
            "completeness": { "type": "number", "minimum": 0, "maximum": 100 },
            "clarity": { "type": "number", "minimum": 0, "maximum": 100 },
            "conciseness": { "type": "number", "minimum": 0, "maximum": 100 },
            "edge_handling": { "type": "number", "minimum": 0, "maximum": 100 }
          }
        },
        "weighted_score": { "type": "number", "minimum": 0, "maximum": 100 }
      }
    },
    "output_b": {
      "type": "object",
      "required": ["label", "scores", "weighted_score"],
      "properties": {
        "label": { "const": "B" },
        "scores": {
          "type": "object",
          "properties": {
            "accuracy": { "type": "number", "minimum": 0, "maximum": 100 },
            "completeness": { "type": "number", "minimum": 0, "maximum": 100 },
            "clarity": { "type": "number", "minimum": 0, "maximum": 100 },
            "conciseness": { "type": "number", "minimum": 0, "maximum": 100 },
            "edge_handling": { "type": "number", "minimum": 0, "maximum": 100 }
          }
        },
        "weighted_score": { "type": "number", "minimum": 0, "maximum": 100 }
      }
    },
    "winner": { "enum": ["A", "B", "tie"] },
    "confidence": { "enum": ["high", "medium", "low"] },
    "reasoning": { "type": "string" }
  }
}
```
