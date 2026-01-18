# Claude Code Statusbar

> **Full credit to [davidamo9](https://github.com/davidamo9)** - Based on the [original gist](https://gist.github.com/davidamo9/764415aff29959de21f044dbbfd00cd9)

A customizable statusbar hook for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays useful information right in your terminal.

![statusbar-preview](https://img.shields.io/badge/claude--code-statusbar-blue)

## Features

The statusbar displays:

- **Model indicator** - Shows current model (opus/sonnet/haiku)
- **Working directory** - Current path (shortened for readability)
- **Context usage** - Color-coded percentage of context window used
  - Green: < 50%
  - Yellow: 50-80%
  - Red: > 80%
- **Git status** - Branch name with visual indicators:
  - `✓` Clean working tree
  - `⚠` Uncommitted changes (+added, ~modified, -deleted)
  - `↑` Commits ahead of remote
  - `⚡` Changes AND ahead (needs attention)
  - `⚙` Merge/rebase in progress

## Example Output

```
[opus] ~/projects/myapp | 23% (46K/200K) | ✓ main
[sonnet] ~/dev/api | 67% (134K/200K) | ⚠ feature/auth(~3)
[haiku] ~/work | 12% (24K/200K) | ⚡ fix/bug(+2~1)↑3
```

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- `jq` - JSON processor
- `git` (optional, for git status display)

## Installation

### Quick Install

```bash
git clone https://github.com/alamparelli/claude-code-statusbar.git
cd claude-code-statusbar
./install.sh
```

### Manual Install

1. Copy `statusline.sh` to `~/.claude/hooks/`:
   ```bash
   mkdir -p ~/.claude/hooks
   cp statusline.sh ~/.claude/hooks/statusline.sh
   chmod +x ~/.claude/hooks/statusline.sh
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/hooks/statusline.sh"
     }
   }
   ```

3. Restart Claude Code

## Uninstall

```bash
rm ~/.claude/hooks/statusline.sh
```

Then remove the `statusLine` section from `~/.claude/settings.json`.

## Customization

Edit `~/.claude/hooks/statusline.sh` to customize:

- Color thresholds for context usage
- Git status symbols
- Display format and order

## Credits

Created by [davidamo9](https://github.com/davidamo9)

## License

MIT License - see [LICENSE](LICENSE) for details.
