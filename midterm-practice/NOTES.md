# Midterm Practice -- Notes

## Task 5: git hygiene

Deleting a .tfstate file or credential string in a subsequent commit only removes it from the current branch tip, but Git is an immutable, append-only directed acyclic graph (DAG), meaning the sensitive plaintext data remains permanently stored and retrievable throughout the repository's commit history unless purged with history-rewriting tools like git filter-repo or BFG.
