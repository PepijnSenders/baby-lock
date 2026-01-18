# Single-Task Backpressure Protocol

**One task per context window.** Complete the next unchecked `- [ ]` from plan.md.

## Context Gathering

Before starting, run these Explore subagents **in parallel** to gather context:

1. `specs/v1/` directory → return summary of all 4 spec files
2. `plan.md` → return summary of phases and current task status
3. `progress.txt` → return summary of completed work

## Workflow

1. **Find** first unchecked `- [ ]` in plan.md
2. **Study** relevant specs before implementing
3. **Implement** to satisfy ALL `- AC:` criteria
4. **Build Validate**: `xcodebuild -scheme BabyLock -configuration Debug build`
5. **UI Validate**: Run app and verify visual/behavioral ACs (see UI Validation below)
6. **Log** results to progress.txt
7. **Fix** failures, re-validate until all pass
8. **Mark complete** - change `- [ ]` to `- [x]`

## UI Validation

For tasks with visual or behavioral ACs, you MUST validate by running the app:

### Launch & Verify
```bash
# Build and run (from project directory)
open -a BabyLock

# Or run from build output
./build/Debug/BabyLock.app/Contents/MacOS/BabyLock
```

### Screenshot Capture
```bash
# Capture screen for visual verification
screencapture -x /tmp/babylock-test.png

# Capture after delay (for animations)
screencapture -x -T 2 /tmp/babylock-test.png
```

### UI Checklist by Phase

**Phase 1 (Core App):**
- [ ] Menu bar icon visible (SF Symbol lock)
- [ ] No dock icon appears
- [ ] Menu dropdown renders correctly
- [ ] Icon changes on state toggle

**Phase 2 (Input Interception):**
- [ ] Keyboard input blocked when locked
- [ ] Mouse clicks blocked when locked
- [ ] Cmd+Shift+B passes through to unlock
- [ ] Input restored after unlock

**Phase 3 (Visual Overlay):**
- [ ] Blue glow border visible on all edges
- [ ] Center is transparent (desktop visible)
- [ ] Overlay above all windows including fullscreen
- [ ] Fade in/out animation smooth

**Phase 4 (System Integration):**
- [ ] Permission dialog appears on first launch
- [ ] Launch at Login toggle persists
- [ ] Clean quit (no residual lock state)

### Behavioral Validation Script
```bash
# Test hotkey response (use osascript to simulate)
osascript -e 'tell application "System Events" to keystroke "b" using {command down, shift down}'

# Verify process running
pgrep -x BabyLock

# Verify no zombie processes after quit
pkill BabyLock && sleep 1 && pgrep -x BabyLock  # Should return nothing
```

## progress.txt Format

```
Phase: [phase name]
Task: [task title]

[✓] Implemented X
[✗] Build failed: Y
    Fix: Z
[✓] Build passed
[✓] UI: Menu bar icon renders correctly
[✗] UI: Glow border not visible
    Fix: Changed window level to .screenSaver
[✓] UI: Glow border visible on all edges

✅ VALIDATED - Task complete
```

## Rules

- ONE task per session
- ALL acceptance criteria must pass (build AND UI)
- Log EVERY validation result (build AND UI)
- Screenshot evidence required for visual ACs
- Stop at "Final Verification" (skip Post-MVP Backlog)
- If UI validation blocked (no display access), document and proceed with build-only
