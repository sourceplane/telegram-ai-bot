# bot-tests

The bot's tests (every upstream library's own, and the port's, in workerd), run on every pull request

The test suite for **bot**. It deploys nothing: its lane installs, builds and runs the tests.

|              |                      |
| ------------ | -------------------- |
| Type         | `turbo-package`      |
| Source       | `tests/bot`          |
| Package      | `@app/bot-tests`     |
| Environments | `dev`: `quick-check` |

## Depends on

- (none)

## Depended on by

- (none)
