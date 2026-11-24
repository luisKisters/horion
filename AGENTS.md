# Horion: how agents work here

Horion is a macOS calendar app in Swift. Luis builds it with agents and does not read the code. Luis captures ideas, decides designs and the structure of the app, looks at the PR and merges.

## At the start of a thread

1. Say in your first line which path you take: **Fix**, **Visual change** or **Project**. Luis can change the path with one word.
2. Work in your own worktree, on a branch from `origin/main`. One thread, one ticket, one PR.
3. Every thread has a ticket. A ticket is a GitHub issue.
    - Fix: if there is no ticket, create one yourself.
    - Other paths: propose a title and two or three lines of content. Create the ticket when Luis says yes.
    - Put `Closes #<number>` in the PR.

## The three paths

**Fix.** A bug, or a small UI change with one clear answer. Build it, check it, open the PR with a picture before and after. No mockup and no questions.

**Visual change.** You can see it, and there is more than one good answer.
- Use the designr skill.
- Start from how the app looks today, not from an old mockup.
- First show 2 or 3 different approaches and how other calendars do it. Then show options per element.
- When Luis sends the picks, lock them and build. Do not ask again.

**Project.** A big feature that needs design.
1. Say what it is, which milestone it belongs to and which area of the app it changes.
2. Ask about the structure: which parts exist, which part owns what, and what talks to what. Ask only about things that are expensive to change later. Mix open questions and proposals. Swift patterns and types are your decision.
3. Make mockups as in "Visual change".
4. Split the work into tickets under one parent issue. This thread stays the project thread. It starts one thread per ticket and keeps the parent issue up to date.

Read the code before you ask. Never ask what you can look up.

## Scope

- Work on your ticket only.
- If Luis asks for something outside the ticket, say so and propose a new ticket with a title and rough contents. Do it in this thread only when Luis says "do it here".
- Do not add features that nobody asked for.

## Check before you open the PR

1. `scripts/verify.sh --fast` passes. Run the full `scripts/verify.sh` when you changed a tour, the app bundle or the packaging.
2. A different agent reviews the diff. Tell it to find bugs and to find ways to make the change smaller. Fix what it finds, or say why not.
3. Write every finding to `findings/<branch-name>.md`, fixed or not. The format is in `findings/README.md`.
4. Tests:
    - A bug in logic (recurrence, time zones, overlap, sync): add one test that fails without the fix.
    - A visual bug: no new test.
    - A feature: test its rules, not its views.
5. If your ticket fixes a bug that an earlier check did not catch, add one line to the findings file that says why the check missed it.
6. Run one build or one test run at a time. This Mac has 8 GB of memory.

## The PR

Luis reads only the PR. It must make sense without the thread.

- Use the PR template. Use plain words and short sentences. Each block has at most 5 lines.
- Visual change: add a screenshot. When motion matters, add a video: record it with `Horion --walkthrough <tour> --record <file>` and post it with `gh pr comment --attach <file>`.
- Luis asks for changes in a new thread. After the change, rewrite the PR body so that it describes the PR as it is now.

## Code

- The rules that a machine checks are in `scripts/verify.sh`. Do not weaken a check to make it pass.
- If your change makes a file longer than 500 lines, split the file or give the reason in the PR.
- Never delete files with `rm`. Use `trash <path>`.
