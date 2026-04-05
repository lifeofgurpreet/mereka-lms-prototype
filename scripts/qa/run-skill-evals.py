#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run agent-agnostic skill routing evals")
    parser.add_argument("--evals", required=True, help="Path to evals YAML file")
    parser.add_argument("--predictions", required=True, help="Path to predictions JSON file")
    parser.add_argument("--skills", help="Comma-separated list of skill names to evaluate")
    parser.add_argument("--output-json", help="Optional output JSON path")
    return parser.parse_args()


def safe_div(numerator: float, denominator: float) -> float:
    return 0.0 if denominator == 0 else round(numerator / denominator, 4)


def load_selected_skills(prediction: dict) -> set[str]:
    values = prediction.get("selected_skills") or prediction.get("predicted_skills") or []
    return {str(value) for value in values}


def quality_result(skill_name: str, quality_eval: dict, prediction: dict) -> tuple[bool, list[str]]:
    failures = []
    selected_skills = load_selected_skills(prediction)
    if skill_name not in selected_skills:
        failures.append(f"skill {skill_name} not selected")
    response_text = str(prediction.get("response_text", ""))
    contract = quality_eval.get("quality_contract") or {}
    required_substrings = contract.get("required_substrings", [])
    required_any = contract.get("required_any", [])
    forbidden_substrings = contract.get("forbidden_substrings", [])

    lowered = response_text.lower()
    for token in required_substrings:
        if token.lower() not in lowered:
            failures.append(f"missing substring: {token}")
    for group in required_any:
        if not any(token.lower() in lowered for token in group):
            failures.append(f"missing any-of group: {group}")
    for token in forbidden_substrings:
        if token.lower() in lowered:
            failures.append(f"forbidden substring present: {token}")

    if not contract and not response_text.strip():
        failures.append("response_text is empty")
    return (len(failures) == 0, failures)


def main() -> int:
    args = parse_args()
    evals_path = Path(args.evals)
    predictions_path = Path(args.predictions)
    selected_skills = None
    if args.skills:
        selected_skills = {skill.strip() for skill in args.skills.split(",") if skill.strip()}

    evals_doc = yaml.safe_load(evals_path.read_text(encoding="utf-8"))
    predictions_doc = json.loads(predictions_path.read_text(encoding="utf-8"))
    predictions = predictions_doc.get("predictions", [])
    prediction_index = {
        (str(row.get("skill_name")), str(row.get("eval_type")), str(row.get("eval_id"))): row
        for row in predictions
    }

    results = {}
    overall = {
        "tp": 0,
        "tn": 0,
        "fp": 0,
        "fn": 0,
        "quality_total": 0,
        "quality_passed": 0,
    }
    missing_predictions = []

    for skill_row in evals_doc.get("skills", []):
        skill_name = skill_row["skill_name"]
        if selected_skills and skill_name not in selected_skills:
            continue

        skill_metrics = {
            "trigger_total": 0,
            "tp": 0,
            "tn": 0,
            "fp": 0,
            "fn": 0,
            "quality_total": 0,
            "quality_passed": 0,
            "quality_failures": {},
        }

        for trigger_eval in skill_row.get("trigger_evals", []):
            key = (skill_name, "trigger", str(trigger_eval["id"]))
            prediction = prediction_index.get(key)
            if prediction is None:
                missing_predictions.append(key)
                continue
            predicted = skill_name in load_selected_skills(prediction)
            expected = bool(trigger_eval["should_trigger"])
            skill_metrics["trigger_total"] += 1
            if expected and predicted:
                skill_metrics["tp"] += 1
            elif expected and not predicted:
                skill_metrics["fn"] += 1
            elif not expected and predicted:
                skill_metrics["fp"] += 1
            else:
                skill_metrics["tn"] += 1

        for quality_eval in skill_row.get("quality_evals", []):
            key = (skill_name, "quality", str(quality_eval["id"]))
            prediction = prediction_index.get(key)
            if prediction is None:
                missing_predictions.append(key)
                continue
            passed, failures = quality_result(skill_name, quality_eval, prediction)
            skill_metrics["quality_total"] += 1
            if passed:
                skill_metrics["quality_passed"] += 1
            else:
                skill_metrics["quality_failures"][str(quality_eval["id"])] = failures

        tp = skill_metrics["tp"]
        tn = skill_metrics["tn"]
        fp = skill_metrics["fp"]
        fn = skill_metrics["fn"]
        skill_metrics["trigger_precision"] = safe_div(tp, tp + fp)
        skill_metrics["false_trigger_rate"] = safe_div(fp, fp + tn)
        skill_metrics["missed_trigger_rate"] = safe_div(fn, tp + fn)
        skill_metrics["quality_pass_rate"] = safe_div(
            skill_metrics["quality_passed"],
            skill_metrics["quality_total"],
        )
        results[skill_name] = skill_metrics

        for key in overall:
            if key in skill_metrics:
                overall[key] += skill_metrics[key]

    if missing_predictions:
        for skill_name, eval_type, eval_id in missing_predictions:
            print(f"MISSING prediction: skill={skill_name} type={eval_type} id={eval_id}")
        return 1

    summary = {
        "schema_version": "1.0",
        "skills": results,
        "overall": {
            "trigger_precision": safe_div(overall["tp"], overall["tp"] + overall["fp"]),
            "false_trigger_rate": safe_div(overall["fp"], overall["fp"] + overall["tn"]),
            "missed_trigger_rate": safe_div(overall["fn"], overall["tp"] + overall["fn"]),
            "quality_pass_rate": safe_div(overall["quality_passed"], overall["quality_total"]),
        },
    }

    for skill_name, skill_metrics in results.items():
        print(
            f"{skill_name}: precision={skill_metrics['trigger_precision']:.2f} "
            f"false_trigger_rate={skill_metrics['false_trigger_rate']:.2f} "
            f"missed_trigger_rate={skill_metrics['missed_trigger_rate']:.2f} "
            f"quality_pass_rate={skill_metrics['quality_pass_rate']:.2f}"
        )

    print(
        "overall: precision={:.2f} false_trigger_rate={:.2f} missed_trigger_rate={:.2f} quality_pass_rate={:.2f}".format(
            summary["overall"]["trigger_precision"],
            summary["overall"]["false_trigger_rate"],
            summary["overall"]["missed_trigger_rate"],
            summary["overall"]["quality_pass_rate"],
        )
    )

    if args.output_json:
        output_path = Path(args.output_json)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
