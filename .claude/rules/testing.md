# Testing

After any code change, run `make test` from the project root and all tests must pass before considering the task complete.

Each test should be stateless and self-contained. Avoid sharing state between tests (e.g. global variables, module-level mutable state). Prefer `before_each` / `after_each` for setup and teardown over shared state, and only share state across tests when there is a clear and necessary reason to do so.

Every function must have tests covering a variety of scenarios (happy path, edge cases, failure cases). Keep each test minimal — only the setup and assertions strictly necessary to verify the scenario.

Prefer naming local variables before asserting, using one of these conventions:
- Input: `input`, `origin`
- Expected: `expected`, `expected_*`
- Actual: `actual`, `actual_*`
