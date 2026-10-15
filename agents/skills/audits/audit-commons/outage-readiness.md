# 2 AM outage readiness lens

Evaluate this lens whenever reviewing code or an implementation plan. Ask: **when an engineer is paged during an outage, can they quickly understand the affected
behavior, diagnose the fault, and take a safe recovery action?**

Assess both the operational path and the code path. Do not assume that a system has alerts, metrics, logs, dashboards, or runbooks.
Trace the actual behavior and report only gaps that the repository or plan proves are relevant.

## Review rules

1. Trace the affected entry point through its dependencies, error boundaries, background work, callbacks, registrations, and callers.
2. Identify the observable signals available during failure: structured logs, error context, metrics, traces, alerts, health checks, audit records, dashboards, or
   runbooks.
3. Check whether each signal identifies the failed operation, affected resource or correlation ID where safe, failure cause, and result of any retry or recovery
   action.
4. Check whether a tired engineer can follow the code without reconstructing hidden state, implicit control flow, distributed ownership, or undocumented side
   effects.
5. Check that the documented or implemented recovery action is safe, bounded, and clear about effects on retries, partial work, and data integrity.
6. Do not require production observability for code that cannot run in production. State why the operational portion does not apply, then still assess code
   comprehension.
7. Do not recommend telemetry, retries, abstractions, or documentation without evidence that they would make a real incident easier to diagnose or recover from.

## Evidence and outcomes

For each concern, record the exact file and line references, the failure or incident scenario, the missing signal or comprehension barrier, and the impact on diagnosis or
recovery. State the smallest change that fixes it. For plans, identify the exact implementation step, signal, owner, and test or verification that proves the behavior.

Classify a finding as blocking when it hides a direct failure, makes recovery unsafe, or prevents diagnosis of an outage in behavior the change can affect. Classify
lesser readability or operational improvements according to the calling skill's normal severity rules. Record an explicit skip when the code is already diagnosable and
understandable, or when the lens does not apply.
