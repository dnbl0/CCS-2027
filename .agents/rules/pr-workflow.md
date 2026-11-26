# Pull request workflow

When completing any coding task (this matches CONTRIBUTING.md, which wins if the two ever differ):

1. **Branch**: work on a branch off `main` in its own worktree, never in the shared checkout. Name it for the kind of change:
   `fix/`, `docs/`, `chore/`, `nfr/`, `design/`, `discover/`, `perf/` and so on.
2. **Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `perf:`, `refactor:`) with the Jira key at the end
   of the first line when there is one. Say why, not only what.
3. **Checks**: run what CI runs (CONTRIBUTING.md "Before you push") before pushing.
4. **Pull request**: push the branch and open a pull request into `main` with `gh pr create`, using the template. Wait for the
   `rails` and `system` checks to pass on the latest commit. Nothing is merged automatically: a person (or the agent the owner has
   asked to merge) merges it after the checks pass.
