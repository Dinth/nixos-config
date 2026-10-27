# Finance workspace

Personal-finance project. Work here is about money: accounts, transactions,
budgets, bills, categories, tags, net worth and spending insights.

## Data source — Firefly III

- The **`firefly` MCP** (firefly-iii-mcp on `10.10.1.13:5137`) is wired for this
  project only. It is the source of truth — query it rather than guessing or
  asking for exports.
- Discover before acting: `get_accounts` / `search_accounts`, `get_categories`,
  `get_budgets`, `get_tags` give the real names and IDs to use in later calls.
- Prefer the server-side aggregates (`get_insight_*`, `get_summary`,
  `get_net_worth_summary`, the `*_chart` tools) over summing transactions
  yourself; they already handle currencies, transfers and splits.

## Writes

- Read tools are safe. **Create / update / delete / bulk tools change the live
  ledger** — every one prompts. Before a mutation, state exactly what will change
  (transaction IDs, old → new values). For bulk edits, show the matching set
  first and confirm the count.
- Never delete a transaction to "fix" it; update it, or ask.
- Refunds and reimbursements: link the refund to the purchase, tag the purchase
  `Reimbursed/refunded`, and give the refund the purchase's category — linking
  alone does not net anything in reports.

## Output

- Show amounts with their currency and the date range they cover.
- Keep files written here (notes, CSVs, reports) inside this folder.

> `AGENTS.md`, `CLAUDE.md`, `.mcp.json` and `opencode.json` here are deployed by
> nixos-config (Home Manager) — change them in `modules/apps/{opencode,claude-code}`,
> not in place.
