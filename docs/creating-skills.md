# Creating Skills

## Minimal Format

Create `<name>/SKILL.md`:

```markdown
---
name: skill-name
description: Explains what the skill does and when to use it. Use when the user requests a specific task or mentions related technologies.
---

# Skill Name

## Workflow

1. Gather the requirements and constraints.
2. Complete the task according to the rules below.
3. Verify the result.

## Rules

- Add specific domain instructions.
- Define the expected response format.
- Identify situations in which the agent should ask a question.
```

`name` must:

- match the directory name,
- contain only lowercase letters, numbers, and hyphens,
- be no more than 64 characters long.

`description` determines when the skill is discovered. It should include terms
that users are likely to use and convey two things:

- what the skill can do,
- when it should be used.

## Writing Guidelines

- Write operational instructions rather than a general article about the
  domain.
- Include a sequence of actions, decision rules, and verification criteria.
- Do not repeat knowledge the model is likely to have unless it affects its
  decisions.
- Specify the output format when consistency matters.
- Add examples only when they resolve ambiguity.
- Do not combine several unrelated domains in one skill.
- For a narrowly scoped skill, begin the description with `Use ONLY when...`
  to prevent accidental activation.

## Testing

A good set of manual tests includes:

1. A prompt that should clearly activate the skill.
2. A similar prompt that falls outside its scope.
3. Incomplete requirements that should cause the agent to ask questions.
4. A task that requires applying the skill's most important rule.

After each change, install the skill with `--force` or use `--link`, then start
a new OpenCode session.

## Other Good Candidates

- `database-design`
- `code-review`
- `testing-strategy`
- `observability`
- `system-design`
- `technical-writing`

Each one should have a narrow scope and its own quality criteria.
