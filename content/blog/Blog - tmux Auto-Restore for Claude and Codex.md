+++
title = "Bringing Claude and Codex Sessions Back From the Dead With tmux"
date = "2026-06-11"

[taxonomies]
tags = ["tmux", "Claude-Code", "Codex", "Developer-Tooling"]

[extra]
created = "2026-06-07"
related = ["[[Blog - Agentic Security Guide]]", "[[Kelsea.io Blog Posts]]"]
+++

# Bringing Claude and Codex Sessions Back From the Dead With tmux

*Or: I rebooted my laptop and lost six conversations. I am not doing that again.*

---

I keep a lot of AI tabs open. Not a couple, not a few. Not even 10s. More like 100 terminal tabs. AuADHD fuels both this brain and laptop.

Not browser tabs, no. `tmux` panes. At any given moment I have a Claude Code session running in `~/Projects/something-cursed`, a Codex session in a different repo, another Claude doing research in my notes vault, and a fourth pane that's been *thinking* for ten minutes about a `terraform` refactor I'll review later. Each of these is its own conversation. Each one has hours of context I do not want to retype.

And then I made the mistake of closing the lid on my laptop. Ugh, I love my Lenovo running Linux but it's got an issue with nap time. That issue stems from the laptop having no S3 deep-sleep support in firmware, only s2idle (Modern Standby), combined with AMD Krackan Point platform quirks that mean overnight lid-close sometimes runs the battery flat instead of latching into the deepest power state. Target of a later blog post once I solve it for good.

Right now it's literally a coin toss whether my laptop will come back or just reboot when I open the lid after a few hours closed. And mine just rebooted.

All of them died. Every single conversation. `tmux` came back via `tmux-resurrect` with the right pane layout, the right working directories, even the right command (`claude`) re-launched in each pane — but every Claude session was a *fresh* Claude session. Empty context. No memory of the work we'd been doing. The pane *looked* right and was *functionally* useless.

This was unacceptable.

---

## What Already Works

For anyone not familiar with the tmux session-restore stack, the baseline pieces are:

- **`tmux-resurrect`** — saves your sessions, windows, panes, working directories, and (with `@resurrect-capture-pane-contents 'on'`) the scrollback. Triggered manually with `prefix Ctrl-s` and restored with `prefix Ctrl-r`.
- **`tmux-continuum`** — auto-saves resurrect snapshots every 15 minutes and auto-restores on tmux server start.

Combine those with a systemd user unit that auto-starts tmux at boot, and `loginctl enable-linger` so the user manager survives logout, and you have a tmux server that:

- Starts at boot
- Survives SSH disconnects, TTY logouts, and kitty restarts
- Auto-restores the last 15-minute snapshot if it ever does come up cold

Then point your terminal at it. In `kitty.conf`:

```conf
shell /usr/bin/tmux new-session -A -s Home
```

Now every kitty window lands in the same tmux session named `Home`. Close kitty, reopen kitty, you're back where you were. Reboot the machine, you're back where you were (minus up to 15 minutes).

This is the *infrastructure*. It handles tmux state. It does not handle what's running *inside* the panes.

---

## Where It Falls Apart

`tmux-resurrect` has a feature called `@resurrect-processes` that re-launches specific commands on restore. Set:

```
set -g @resurrect-processes 'claude codex'
```

…and on restore, panes that had `claude` running get `claude` started again. Panes that had `codex` get `codex`.

This is the trap.

The CLIs *launch*. They just don't *resume*. You get a clean Claude session in the right directory, scrollback intact above it showing the conversation you used to be having, and a fresh prompt waiting for you to start over. The scrollback is taunting you.

Both tools support resumption — `claude --resume <uuid>` and `codex resume <uuid>` — but `tmux-resurrect` has no idea what UUID belonged to what pane. Neither CLI exposes its session ID through any mechanism tmux can read at restore time. The pane title doesn't carry it. The process environment doesn't carry it. There is no `$CLAUDE_SESSION_ID` we can grep out of `/proc/$pid/environ`.

So I built the bridge.

---

## The Bridge

Both Claude and Codex write session files to disk:

- `~/.claude/projects/<cwd-slug>/<session-uuid>.jsonl`
- `~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<session-uuid>.jsonl`

Each file is tagged with the `cwd` it was started in. Claude encodes the cwd in the directory name (`/home/kelsea/Projects/foo` becomes `-home-kelsea-Projects-foo`). Codex puts it inside the first JSONL record as `payload.cwd`.

That's enough to match panes to sessions, *if* you do it at the right moment.

**At save time** — when `tmux-continuum` writes its 15-minute snapshot — I walk every pane, check if it's running `claude` or `codex`, look up the most recently modified session file matching that pane's cwd, and write a sidecar file next to the resurrect save:

```
session|window|pane|tool|cwd|uuid
Home|1|2|claude|/home/kelsea/Projects/foo|20b3456c-c8d3-4341-b31a-5376860057b3
Home|2|1|codex|/home/kelsea/Projects/bar|019e80a3-ea38-7fc2-b37c-749a255a9c1b
```

`tmux-resurrect` exposes hooks for exactly this:

```
set -g @resurrect-hook-post-save-all 'bash ~/.config/tmux/scripts/ai-session-save.sh'
set -g @resurrect-hook-post-restore-all 'bash ~/.config/tmux/scripts/ai-session-restore.sh'
```

**At restore time** — after resurrect has rebuilt panes and re-launched `claude`/`codex` fresh in each one — the post-restore hook reads the sidecar, waits a couple seconds for the freshly-spawned CLIs to settle, then for each entry:

1. Verifies the pane is still running the expected tool
2. Sends `C-c` to drop out of the fresh instance
3. Sends `claude --resume <uuid>` (or `codex resume <uuid>`) and Enter

The pane wakes back up *into the actual conversation it was in before the reboot.*

---

## What I Learned Along The Way

A few things were not in the manual.

**`tmux-resurrect` doesn't live in `~/.config/tmux/resurrect/`.** It lives in `~/.local/share/tmux/resurrect/`. I had the wrong path in my first version of the save script. The first run wrote nothing, the second run wrote everything. (XDG base dir spec strikes again. Configuration lives in one place, state in another, cache in a third. This is correct, but I had to be reminded.)

**`@resurrect-processes` matters even with the bridge.** Without it, resurrect doesn't even *try* to relaunch the CLI — it just gives you an empty shell. The bridge needs *something* running in the pane to send `C-c` and the resume command into. Belt and suspenders.

**Matching by cwd is good enough, but not unique.** If you have two `claude` panes in the *same* working directory, both get mapped to the most recently modified session — i.e., the same one. They'd both resume into the same conversation. The proper fix requires Claude/Codex to expose the live session ID through *something* tmux can read at save time. Neither does today. I am noting this as a feature request for both teams that I am too lazy to file.

**Auto-restore only fires on a cold server.** `@continuum-restore 'on'` only triggers when tmux starts with zero existing sessions. If you kill your terminal but the tmux server keeps running (which is the whole point of the systemd unit and `enable-linger`), continuum *doesn't* restore — because it doesn't need to. The live sessions are still there. The 15-minute-old snapshot is only there as a safety net for the case where the server genuinely died: machine reboot, OOM kill, `tmux kill-server`. This is correct behavior. I had to convince myself of that twice.

---

## The Honest Limits

This is a duct-tape solution to an absence of API. A few caveats worth stating plainly:

- **Resurrects the most recent matching session per cwd, not the exact one.** Multiple concurrent sessions in the same directory collapse to one.
- **Only captures actively-running CLIs.** If your Claude exited 30 seconds before the snapshot, you won't get it back automatically — though you can always `claude --resume` and pick from the picker.
- **Two-second sleep before sending resume commands.** Slow machines might need more. Fast ones waste two seconds. Fine.
- **Sidecar lives next to the resurrect save.** When resurrect prunes old saves, my sidecar gets orphaned. I should probably clean those up. I have not.

What it gets right: the 90% case where I close my laptop, walk away for the day and it reboots the next morning, I can just open kitty and *every conversation I was having yesterday is back where I left it.*

That's the thing I wanted.

---

## The Pieces

For anyone wanting to replicate this — and assuming you already have `tmux-resurrect`, `tmux-continuum`, and a `tmux.service` user unit set up — there are three small pieces.

### 1. Tell `tmux-resurrect` to relaunch the CLIs

In `tmux.conf`:

```conf
set -g @resurrect-processes 'claude codex'
set -g @resurrect-hook-post-save-all    'bash ~/.config/tmux/scripts/ai-session-save.sh'
set -g @resurrect-hook-post-restore-all 'bash ~/.config/tmux/scripts/ai-session-restore.sh'
```

### 2. `ai-session-save.sh`

Walks every pane, and for any pane running `claude` or `codex`, finds the most recently modified session file matching that pane's cwd and writes a sidecar next to the latest resurrect save.

```bash
#!/usr/bin/env bash
# Capture (window, pane, cwd, cmd) -> session UUID for every pane running
# `claude` or `codex`. Written next to the latest tmux-resurrect save.
#
# Hooked from tmux-resurrect's @resurrect-hook-post-save-all.

set -u

RESURRECT_DIR="${HOME}/.local/share/tmux/resurrect"
LAST_SAVE="${RESURRECT_DIR}/last"
[ -L "${LAST_SAVE}" ] || exit 0

SIDECAR="$(readlink -f "${LAST_SAVE}").ai-sessions"
: > "${SIDECAR}"

CLAUDE_ROOT="${HOME}/.claude/projects"
CODEX_ROOT="${HOME}/.codex/sessions"

# Find the most recent Claude session UUID for a given cwd.
claude_session_for_cwd() {
    local cwd="$1"
    local slug
    slug="$(echo "${cwd}" | sed 's|/|-|g')"
    local dir="${CLAUDE_ROOT}/${slug}"
    [ -d "${dir}" ] || return 1
    local newest
    newest="$(ls -1t "${dir}"/*.jsonl 2>/dev/null | head -n1)"
    [ -n "${newest}" ] || return 1
    basename "${newest}" .jsonl
}

# Find the most recent Codex session UUID for a given cwd.
codex_session_for_cwd() {
    local cwd="$1"
    [ -d "${CODEX_ROOT}" ] || return 1
    local f
    while IFS= read -r f; do
        local line cwd_in_file id
        line="$(head -n1 "${f}" 2>/dev/null)"
        cwd_in_file="$(printf '%s' "${line}" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("payload",{}).get("cwd",""))' 2>/dev/null)"
        if [ "${cwd_in_file}" = "${cwd}" ]; then
            id="$(printf '%s' "${line}" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("payload",{}).get("id",""))' 2>/dev/null)"
            [ -n "${id}" ] && { printf '%s' "${id}"; return 0; }
        fi
    done < <(find "${CODEX_ROOT}" -name 'rollout-*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')
    return 1
}

tmux list-panes -a -F '#{session_name}|#{window_index}|#{pane_index}|#{pane_current_command}|#{pane_current_path}' \
| while IFS='|' read -r sess win pane cmd cwd; do
    case "${cmd}" in
        claude)
            uuid="$(claude_session_for_cwd "${cwd}")" || continue
            printf '%s|%s|%s|%s|%s|%s\n' "${sess}" "${win}" "${pane}" claude "${cwd}" "${uuid}" >> "${SIDECAR}"
            ;;
        codex)
            uuid="$(codex_session_for_cwd "${cwd}")" || continue
            printf '%s|%s|%s|%s|%s|%s\n' "${sess}" "${win}" "${pane}" codex "${cwd}" "${uuid}" >> "${SIDECAR}"
            ;;
    esac
done

exit 0
```

### 3. `ai-session-restore.sh`

Reads the sidecar after resurrect has rebuilt panes, gives the freshly-spawned CLIs a beat to settle, then for each entry kicks the empty instance with `C-c` and sends the `--resume` command.

```bash
#!/usr/bin/env bash
# After tmux-resurrect restores panes, replay the sidecar:
# for each (session, window, pane) match, send the appropriate
# `claude --resume <uuid>` or `codex resume <uuid>` command.
#
# Resurrect restores panes with their original command (claude/codex)
# already running, so we first send C-c to drop out, then the resume
# command. Skips panes where the current command no longer matches.
#
# Hooked from tmux-resurrect's @resurrect-hook-post-restore-all.

set -u

RESURRECT_DIR="${HOME}/.local/share/tmux/resurrect"
LAST_SAVE="${RESURRECT_DIR}/last"
[ -L "${LAST_SAVE}" ] || exit 0

SIDECAR="$(readlink -f "${LAST_SAVE}").ai-sessions"
[ -s "${SIDECAR}" ] || exit 0

# Give resurrect a moment to finish spawning processes inside each pane.
sleep 2

while IFS='|' read -r sess win pane tool cwd uuid; do
    [ -n "${sess}" ] || continue
    target="${sess}:${win}.${pane}"

    current_cmd="$(tmux display-message -p -t "${target}" '#{pane_current_command}' 2>/dev/null)" || continue
    [ "${current_cmd}" = "${tool}" ] || continue

    case "${tool}" in
        claude) resume_cmd="claude --resume ${uuid}" ;;
        codex)  resume_cmd="codex resume ${uuid}"   ;;
        *) continue ;;
    esac

    tmux send-keys -t "${target}" C-c
    sleep 0.3
    tmux send-keys -t "${target}" "${resume_cmd}" Enter
done < "${SIDECAR}"

exit 0
```

That's it — under 100 lines combined. Most of the work was figuring out *what* the bridge needed to be, not writing it. Once you know that Claude stamps cwd into directory names and Codex stamps it into the first JSONL record, the rest is `find`, `head -n1`, and a `python3 -c` one-liner.

---

## Why This Matters (To Me)

There's a version of working with AI tooling where every session is disposable. You start a conversation, you finish it, you close the terminal. The context dies with the pane.

That's not how I work.

I keep long-running conversations. I have a research pane that's been compounding context for two weeks. I have a "current refactor" pane that knows the entire history of why I'm doing what I'm doing. I have a "review this PR" pane I keep coming back to. These conversations are not just chat logs, they're working memory. Killing them is the same as wiping a notebook.

Auto-restore for AI tooling shouldn't be a duct-tape script in my `~/.config/tmux/scripts/` directory. It should be a first-class feature of every CLI agent. Until it is, this is what I'm running.

If you've been losing your sessions on every reboot too, now you don't have to.
