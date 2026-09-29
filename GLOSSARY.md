# building-agentskills Glossary

**Routing table**:
A table in a Skill that maps each kind of work to the procedure files the agent must read for it.
_Avoid_: dispatch table, skill index

**Routing row**:
One entry of a routing table: a trigger and the procedure files it links.
_Avoid_: route, rule

**Before-clause**:
A trigger worded as `Before <action>, read <file>`, which names the observable action the read must precede.
_Avoid_: timing hint, when-clause

**Bare conjunct**:
A required file joined to another link with "and" instead of getting its own before-clause.
_Avoid_: second link, secondary link

**Session-start pointer**:
A short always-loaded note, injected when a session starts, that tells the agent when to load a Skill and read the procedure its routing table links.
_Avoid_: bootstrap, routing hook

**Naive prompt**:
A benchmark prompt that needs a routing row but names neither the Skill nor the procedure.
_Avoid_: positive prompt, plain prompt

**Negative prompt**:
A benchmark prompt for similar work that needs no procedure; the procedure must stay unopened.
_Avoid_: control prompt, over-trigger test

**Moment**:
The action a required read must precede in a benchmark run: the first file edit, a named shell command or tool call, or the end of the run for answer-only work.
_Avoid_: checkpoint, trigger point

**Successful read**:
A read whose tool result succeeded; a refused or failed read is an attempt and does not count.
_Avoid_: read attempt, tool call

**Arm**:
One version of the text under test in a benchmark, such as the released rows or a candidate wording, built from a named ref and run on the same prompts as the other arms.
_Avoid_: variant, condition

**Verdict**:
The score of one required file in one benchmark run, such as `fired`, `skip`, `read-noaction` or `clean`.
_Avoid_: result, pass
