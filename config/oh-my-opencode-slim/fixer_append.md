Before code implementation, load the ponytail skill unless already loaded.

For implementation requiring repeated cross-file lookups, reuse an available XERJ project index; call xerj_map before querying an autoindexed corpus and verify findings against current source before editing. Do not independently build or refresh an index another lane owns; request indexing through the orchestrator if needed. For known paths and small, scoped changes, use read/grep/AST directly; if XERJ is unavailable, fall back without blocking.
