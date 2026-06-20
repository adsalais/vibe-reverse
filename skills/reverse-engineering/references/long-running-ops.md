# Long-running operations (background + budget + never auto-kill)

Some steps are slow: Ghidra on large binaries, angr/symbolic execution, emulation
(qiling), devirtualization, capa, FLOSS. Handle them like this:

1. **State the cost first.** Before launching, tell the user the expected cost with
   a tag: ⚡ fast (seconds) · ⏳ minutes · 🐢 long (tens of minutes+).
2. **Run detached, write to `artifacts/`.** Launch the tool in the background so the
   session stays responsive; direct its output to a file under the binary's
   `artifacts/<tool>/`. Keep analysing/summarising other things while it runs.
3. **Record it in `STATE.md`.** Add a row to the binary's Background-jobs ledger:
   `| <id> | <command> | <started> | <expected-artifact> | <budget> | running |`.
   Update the status to `done`/`killed` when it resolves.
4. **Soft time budget — generous.** Minimum **30 min**, up to **1 hour**, all
   overridable. Defaults: Ghidra 30m · emulation 30m · angr/symbolic 60m · devirt
   per-handler 60m.
5. **On budget-hit, ASK — never auto-kill.** Present a numbered choice and wait:
   ```
   <tool> has run <N> min (budget <M>). Options:
   1. Keep waiting (+<N> min)
   2. Kill it and use the partial result in artifacts/...
   3. Kill it and try another route
   Which option?
   ```

The human decides when to stop a process. Killing work the user is paying for, or
discarding a partial result, is never the agent's call alone.
