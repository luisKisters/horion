# Horion: how agents work here

Horion is a macOS calendar app in Swift. Luis builds it with agents and does not read the code. Luis captures ideas, decides designs and the structure of the app, looks at the PR and merges.

## At the start of a thread

1. Say in your first line which path you take: **Fix**, **Visual change** or **Project**. Luis can change the path with one word.
2. One thread, one ticket, one PR.
3. Every thread has a ticket. A ticket is a GitHub issue.
    - Fix: if there is no ticket, create one yourself.
    - Visual change or Project: propose a title and two or three lines of content. Create the ticket when Luis says yes.
    - Put `Closes #<number>` in the PR.

## The three paths

**Fix.** A bug, or a small UI change with one clear answer. Build it, check it, open the PR with a screenshot before and after, or a video when motion matters. No mockup and no questions.

**Visual change.** You can see it, and there is more than one good answer.
- Use the designr skill.
- Start from `design/current/`: the mockup of the app as it is now. First compare it with fresh screenshots of the app. Fix where they differ. Then make the options on top of it.
- First show 2 or 3 different approaches. Choose them by what is easiest to use and what fits the rest of the app best. Say for each one why. Then show options per element.
- When Luis sends picks, lock them. If he says to keep going, make the next round. Otherwise build. Do not ask again.
- The PR that builds the change also updates `design/current/` and `design/LOCKED.md`, so the next round starts from the app as it is then.

**Project.** A big feature. It needs a plan before anyone builds.
1. Say what it is, which milestone it belongs to and which area of the app it changes.
2. Grill Luis with the grilling skill until the plan is clear: what it does, the cases at the edges, and the structure (which part owns what, what talks to what). Ask only about things that are expensive to change later. Swift patterns and types are your decision.
3. Write the result into one parent issue.
4. Make mockups as in "Visual change", when the project has a visual part.
5. Split the work into tickets under the parent issue. Start one new T3 Code thread per ticket, with the ticket as its brief. Luis works in those threads.
6. This thread stays the project thread. Keep the parent issue up to date as the tickets merge.

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
