# Testing the harness

## Script tests (deterministic, run locally)

```sh
sh tests/scripts/test_preflight.sh
sh tests/scripts/test_new_investigation.sh
python3 -m pytest tests/scripts/test_script_template.py -q
```

All must exit 0.

## Skill scenario tests (RED → GREEN, via a subagent)

Each skill has scenario(s) in `tests/scenarios/<skill>-<case>.md`. To test a
skill, follow `superpowers:writing-skills`:

1. **RED (baseline):** dispatch a fresh subagent with the scenario text **and no
   access to the skill**. Record what it does (verbatim). This proves the skill is
   needed.
2. **GREEN (verify):** dispatch a fresh subagent with the scenario **and the
   skill loaded** (paste the SKILL.md if the skill is not yet installed). Confirm
   it now complies (see each scenario's "PASS criteria").
3. **REFACTOR:** if it finds a loophole, add an explicit counter to the skill and
   re-run GREEN.

A skill is "done" only when GREEN passes under the scenario's stated pressure.
