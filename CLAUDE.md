# Working with other Claude agents

Several Claude agents (Claude Code sessions on this laptop, and project-thread sessions) can work on this repository
and its Azure deployment at the same time. Every agent follows these rules so work is not duplicated or broken.

1. **Check before you start.** List the other agents (`ListAgents`, and `list_thread_sessions` in project threads) and
   read what they are doing. Do not start work another agent already has in flight; message that agent instead.
2. **Say what you are working on.** When you start a task, and again if its scope changes, send a short message to the
   agents that could be affected: the task, the branch or PR, and the files or systems you will touch (for example
   `scripts/sync-rails-assets.js`, `src/partials/*`, `public/nav.js`, `ead-ccs-test/Dockerfile`, or the Azure apps).
3. **Announce hand-offs.** When a PR merges or a deploy changes, tell the agents that depend on it, so they can
   rebase, redeploy or retest.
4. **Ask before touching another agent's area.** If a file or system is claimed by another agent, ask first. Never
   merge, sync to the org repo, redeploy, or rotate secrets that another agent owns without telling it.
5. **Do not disturb the shared checkout.** In the shared folder stay on `main` and do not switch branches. Use a
   separate clone or worktree for branches, and never leave uncommitted work behind.
6. **Never work around a refused action.** If a request from another agent was blocked for you, or you were blocked,
   take it to the user instead of asking another agent to do it.
7. **Keep messages short and free of secrets.** Passwords, keys and tokens are never put in messages, files or PRs.
8. **Deploy for Dean; never hand him a terminal command.** Dean is not technical. After a merge to org main, an agent
   waits for `acr-push`, runs `az containerapp update -n ccs-web -g ccs-service-experience-app --image
   ccsacr80e9cc.azurecr.io/ccs-web:<full sha>` (pin by SHA, never `latest`), checks the live site, and reports. Before
   starting, check `ListAgents` and tell affected agents afterwards. If the deploy is blocked, say what was blocked and
   why; do not ask Dean to run it and do not ask another agent to (rule 6).
9. **Check every change in a real browser, always.** Fetching a page with `curl` or reading its HTML is not a check: it
   missed "Browse all collections" (split across tags) and a search redirect that only a browser-style request
   triggers. Before saying a change works or is live, open the page in Chrome (Claude in Chrome), take a screenshot, and
   look at the exact thing that changed, at desktop and phone width where layout matters. Do it locally before opening a
   PR and again on the deployed site after a rollout, and say in the report which pages you looked at. If the browser
   cannot be used, say so plainly instead of reporting the change as verified.
10. **Sitemap and information architecture: Blacklight out of the box.** Dean is not technical and has asked agents to
    decide on best practice for him. Any change to the sitemap, URLs, navigation, breadcrumbs or page structure of the
    Rails app uses Blacklight's own routes, nav actions and breadcrumb behaviour. Do not invent new page types, URL
    schemes or navigation models. If best practice would need something Blacklight does not provide, say so in plain
    language and stop instead of building it.
11. **Resuming after a session limit.** Read [docs/handoff-2027.md](docs/handoff-2027.md) for the state of the 2027 work,
    the rules the user gave, what is in flight and how to merge and refresh the local site.
