# Fragility proof contract

A fragility finding is valid only when the current code proves one concrete, reachable failure chain:

1. A real entry point, caller, event listener, observer, scheduled task, or framework registration reaches the operation.
2. A specific operation can fail through an explicit throw, rejection, error result, failed side effect, or verified dependency or framework contract.
3. The failure condition is reachable from code, accepted input, persisted state, or a verified runtime contract. Do not invent an environment failure.
4. Every relevant caller and error boundary is traced until the failure is handled or reaches its observable outcome.
5. The current handling is absent or incorrect, and the outcome is concrete: a crash, false success, stuck state, lost cleanup, partial commit,
   duplicate work, or equivalent.

Reject a candidate when any link is missing. "The network might fail," "this could be null," and similar theoretical statements are not findings
without a proved path.

For dependencies and frameworks, read the installed source. If source is unavailable, use official documentation for the installed version and record that source.

Complexity can cause fragility. Assess the smallest simplification that removes contradictory state, duplicated branching, unclear ownership, or lost propagation.
Keep the existing shape when simplification does not make failure behavior clearer and safer.
