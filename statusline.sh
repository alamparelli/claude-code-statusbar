#!/bin/bash
# Claude Code Context Window Progress Bar & API Usage
#
# Installation:
# 1. Save this file to ~/.claude/hooks/statusline.sh
# 2. Make it executable: chmod +x ~/.claude/hooks/statusline.sh
# 3. Add to ~/.claude/settings.json:
#    {
#      "statusLine": {
#        "type": "command",
#        "command": "~/.claude/hooks/statusline.sh"
#      }
#    }
# 4. Restart Claude Code
#
# Requires: jq (brew install jq / apt install jq)

# Read JSON input from stdin
input=$(cat)

# Parse data from JSON input
if command -v jq &>/dev/null && [ -n "$input" ]; then
    model=$(echo "$input" | jq -r '.model.id // .model.api_model_id // empty' 2>/dev/null)
    context_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty' 2>/dev/null)

    # Get REAL context usage (like /context command)
    # current_usage shows actual tokens sent to API including cache
    cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0' 2>/dev/null)
    cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0' 2>/dev/null)
    current_in=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0' 2>/dev/null)
    current_out=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0' 2>/dev/null)

    # Ensure numeric
    [[ ! "$cache_read" =~ ^[0-9]+$ ]] && cache_read=0
    [[ ! "$cache_create" =~ ^[0-9]+$ ]] && cache_create=0
    [[ ! "$current_in" =~ ^[0-9]+$ ]] && current_in=0
    [[ ! "$current_out" =~ ^[0-9]+$ ]] && current_out=0

    # Total context = all input tokens (cache + new)
    input_tokens=$((cache_read + cache_create + current_in))
    output_tokens=$current_out

    # Fallback if current_usage is null
    if [ "$input_tokens" -eq 0 ]; then
        input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
        output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)
        [[ ! "$input_tokens" =~ ^[0-9]+$ ]] && input_tokens=0
        [[ ! "$output_tokens" =~ ^[0-9]+$ ]] && output_tokens=0
    fi
fi

# Fallback: read model from settings.json if not detected from input
if [ -z "$model" ] || [ "$model" = "null" ]; then
    settings_file="$HOME/.claude/settings.json"
    if [ -f "$settings_file" ] && command -v jq &>/dev/null; then
        model=$(jq -r '.model // empty' "$settings_file" 2>/dev/null)
    fi
fi

# Model name
model_short=""
case "$model" in
    *opus*) model_short="opus" ;;
    *sonnet*) model_short="sonnet" ;;
    *haiku*) model_short="haiku" ;;
    *) model_short="claude" ;;
esac

# Build usage display
usage_info=""

# Context window usage
if [ -n "$context_size" ] && [ "$context_size" != "0" ] && [ "$context_size" != "null" ]; then
    # Total tokens used in context
    total_tokens=$((input_tokens + output_tokens))

    # Autocompact buffer: ~22.5% of context window (~45K for 200K window)
    # This is reserved space for autocompact, not exposed in API yet
    autocompact_buffer=$((context_size * 225 / 1000))

    # Effective available space (context - buffer)
    effective_size=$((context_size - autocompact_buffer))

    # Calculate percentage WITH buffer (real usage relative to full context)
    pct_with_buffer=$(awk "BEGIN {x=(($total_tokens + $autocompact_buffer) / $context_size) * 100; print int(x) + (x > int(x) ? 1 : 0)}")
    # Cap at 100%
    [ "$pct_with_buffer" -gt 100 ] && pct_with_buffer=100

    # Format token count (K for thousands)
    if [ "$total_tokens" -ge 1000 ]; then
        tokens_display="$((total_tokens / 1000))K"
    else
        tokens_display="$total_tokens"
    fi

    # Effective size in K
    effective_size_k="$((effective_size / 1000))K"

    # Color coding based on usage WITH buffer (ANSI colors)
    if [ "$pct_with_buffer" -ge 80 ]; then
        color="\033[31m"  # Red - danger zone
    elif [ "$pct_with_buffer" -ge 50 ]; then
        color="\033[33m"  # Yellow - getting full
    else
        color="\033[32m"  # Green - plenty of room
    fi
    reset="\033[0m"

    # Format: percentage with buffer included (tokens/effective_size)
    usage_info="${color}${pct_with_buffer}%${reset} (${tokens_display}/${effective_size_k})"
fi

# Get current working directory (shortened)
cwd_info=""
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
if [ -n "$cwd" ] && [ "$cwd" != "null" ]; then
    # Shorten home directory to ~
    cwd_short="${cwd/#$HOME/~}"
    # If still too long, show only last 2 directories
    if [ "${#cwd_short}" -gt 30 ]; then
        cwd_short="…/$(echo "$cwd_short" | rev | cut -d'/' -f1-2 | rev)"
    fi
    cwd_info="$cwd_short"
fi

# Git branch info with colors (optional)
git_info=""
if git rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check git status
        porcelain=$(git status --porcelain 2>/dev/null)

        # Count added/modified/deleted
        added=$(echo "$porcelain" | grep -c '^A' 2>/dev/null || echo 0)
        modified=$(echo "$porcelain" | grep -c '^M' 2>/dev/null || echo 0)
        deleted=$(echo "$porcelain" | grep -c '^D' 2>/dev/null || echo 0)

        # Check for merge/rebase
        git_dir=$(git rev-parse --git-dir 2>/dev/null)
        if [ -f "$git_dir/MERGE_HEAD" ]; then
            git_state="merging"
        elif [ -f "$git_dir/rebase-merge/applying" ] || [ -f "$git_dir/rebase-apply/applying" ]; then
            git_state="rebasing"
        else
            git_state=""
        fi

        # Check ahead of remote
        ahead=0
        if git rev-parse @{u} &>/dev/null 2>&1; then
            ahead=$(git rev-list --count @{u}..@ 2>/dev/null)
        fi

        # Build git status string with colors
        # Color codes
        color_green="\033[32m"      # Clean
        color_yellow="\033[33m"     # Changes
        color_blue="\033[34m"       # Ahead
        color_red="\033[31m"        # Ahead + changes / critical
        color_magenta="\033[35m"    # Merging/rebasing
        color_reset="\033[0m"

        # Determine state and color
        if [ -n "$git_state" ]; then
            # In merge/rebase state
            git_info="${color_magenta}⚙ ${branch}(${git_state})${color_reset}"
        elif [ -n "$porcelain" ] && [ "$ahead" -gt 0 ]; then
            # Both changes and ahead = critical
            changes=""
            [ "$added" -gt 0 ] && changes="${changes}+${added}"
            [ "$modified" -gt 0 ] && changes="${changes}~${modified}"
            [ "$deleted" -gt 0 ] && changes="${changes}-${deleted}"
            git_info="${color_red}⚡ ${branch}(${changes})↑${ahead}${color_reset}"
        elif [ -n "$porcelain" ]; then
            # Only changes
            changes=""
            [ "$added" -gt 0 ] && changes="${changes}+${added}"
            [ "$modified" -gt 0 ] && changes="${changes}~${modified}"
            [ "$deleted" -gt 0 ] && changes="${changes}-${deleted}"
            git_info="${color_yellow}⚠ ${branch}(${changes})${color_reset}"
        elif [ "$ahead" -gt 0 ]; then
            # Only ahead
            git_info="${color_blue}↑ ${branch}(+${ahead})${color_reset}"
        else
            # Clean
            git_info="${color_green}✓ ${branch}${color_reset}"
        fi
    fi
fi

# Build output: [model] cwd | percentage | git
output=""

# Add current directory first
[ -n "$cwd_info" ] && output="$cwd_info"

# Add context usage
[ -n "$usage_info" ] && output="${output:+$output | }$usage_info"

# Add git info
[ -n "$git_info" ] && output="${output:+$output | }$git_info"

# Prefix with model indicator
if [ -n "$output" ]; then
    output="[$model_short] $output"
else
    output="[$model_short]"
fi

echo -e "$output"
