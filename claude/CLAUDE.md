# Global instructions

The user's machine facts, tool quirks and cross-project lessons live in the knowledge vault at
`~/knowledge`. Before working on the desktop, system config or another repo, read
`~/knowledge/reference/Environment & Tooling.md` (the index) and the topic note it points to.
Each repo's own CLAUDE.md wins for repo-specific rules; read it before editing that repo.

Config for this machine (system, dotfiles, Claude and Hermes settings) is the flake in `~/nix-dots`.
Change it there and apply with `nix-apply`; do not hand-edit generated files under `~/.claude` or
`~/.hermes` that are links into it. New files must be `git add`ed before the flake sees them.
