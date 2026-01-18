#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Simulate realistic terminal activity
fake_build() {
    echo -e "${CYAN}❯${RESET} npm run build"
    sleep 0.3
    echo -e "${GRAY}> baby-lock@1.0.0 build${RESET}"
    echo -e "${GRAY}> tsc && vite build${RESET}"
    sleep 0.2
    echo ""
    echo -e "${GREEN}✓${RESET} Compiling TypeScript..."
    sleep 0.4
    for file in "src/index.ts" "src/components/App.tsx" "src/hooks/useAuth.ts" "src/utils/helpers.ts" "src/api/client.ts"; do
        echo -e "  ${GRAY}→ ${file}${RESET}"
        sleep 0.1
    done
    echo ""
}

fake_git_log() {
    echo -e "${CYAN}❯${RESET} git log --oneline -10"
    sleep 0.2
    commits=(
        "${YELLOW}a3f2d1c${RESET} feat: Add input interception for keyboard events"
        "${YELLOW}b7e4a2f${RESET} fix: Handle edge case in overlay animation"
        "${YELLOW}c9d3b5e${RESET} refactor: Extract MenuBarManager from AppDelegate"
        "${YELLOW}d2f6c8a${RESET} docs: Update README with installation steps"
        "${YELLOW}e5a9d4b${RESET} feat: Implement blue glow border effect"
        "${YELLOW}f8c2e7d${RESET} fix: Resolve memory leak in event tap"
        "${YELLOW}g1b5f9c${RESET} chore: Update dependencies to latest"
        "${YELLOW}h4e8a2f${RESET} feat: Add launch at login support"
        "${YELLOW}i7d1c5e${RESET} test: Add unit tests for LockManager"
        "${YELLOW}j9f3b8a${RESET} refactor: Simplify hotkey detection logic"
    )
    for commit in "${commits[@]}"; do
        echo -e "$commit"
        sleep 0.15
    done
    echo ""
}

fake_test_run() {
    echo -e "${CYAN}❯${RESET} swift test"
    sleep 0.3
    echo -e "${WHITE}Building for debugging...${RESET}"
    sleep 0.5
    echo -e "${GREEN}Build complete!${RESET} (2.34s)"
    echo ""
    echo -e "${WHITE}Test Suite 'All tests' started${RESET}"

    tests=(
        "LockManagerTests.testInitialState"
        "LockManagerTests.testToggleLock"
        "LockManagerTests.testDebounce"
        "InputInterceptorTests.testEventTapCreation"
        "InputInterceptorTests.testHotkeyPassthrough"
        "OverlayWindowTests.testWindowLevel"
        "OverlayWindowTests.testGlowAnimation"
        "HotKeyManagerTests.testKeyDetection"
        "MenuBarManagerTests.testIconStates"
    )

    for test in "${tests[@]}"; do
        echo -e "  ${GREEN}✓${RESET} $test ${GRAY}(0.0$(( RANDOM % 9 + 1 ))s)${RESET}"
        sleep 0.12
    done
    echo ""
    echo -e "${GREEN}Test Suite 'All tests' passed${RESET}"
    echo -e "  Executed 9 tests, with 0 failures in 1.42s"
    echo ""
}

fake_claude_code() {
    echo -e "${CYAN}❯${RESET} claude"
    sleep 0.3
    echo -e "${BLUE}╭─────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${BLUE}│${RESET}  ${WHITE}Claude Code${RESET} v1.0.0                                       ${BLUE}│${RESET}"
    echo -e "${BLUE}│${RESET}  ${GRAY}Your AI pair programmer${RESET}                                   ${BLUE}│${RESET}"
    echo -e "${BLUE}╰─────────────────────────────────────────────────────────────╯${RESET}"
    echo ""
    sleep 0.2
    echo -e "${GREEN}?${RESET} What would you like to do?"
    sleep 0.5

    # Simulate typing
    text="Help me refactor the InputInterceptor class"
    echo -ne "${CYAN}❯${RESET} "
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep 0.03
    done
    echo ""
    sleep 0.3

    echo ""
    echo -e "${GRAY}Analyzing codebase...${RESET}"
    sleep 0.4
    echo -e "${GRAY}Reading InputInterceptor.swift...${RESET}"
    sleep 0.3
    echo ""
    echo -e "I'll help you refactor the ${WHITE}InputInterceptor${RESET} class. Looking at the"
    sleep 0.1
    echo -e "current implementation, I can see a few opportunities:"
    echo ""
    sleep 0.2
    echo -e "  ${CYAN}1.${RESET} Extract the event tap callback into a separate method"
    sleep 0.1
    echo -e "  ${CYAN}2.${RESET} Create an enum for the different event types"
    sleep 0.1
    echo -e "  ${CYAN}3.${RESET} Add proper error handling for tap creation"
    echo ""
}

fake_file_watch() {
    echo -e "${CYAN}❯${RESET} npm run dev"
    sleep 0.2
    echo -e "${GRAY}> watching for file changes...${RESET}"
    echo ""
    files=(
        "src/components/Header.tsx"
        "src/styles/global.css"
        "src/hooks/useTheme.ts"
        "src/api/endpoints.ts"
        "src/utils/format.ts"
    )
    for file in "${files[@]}"; do
        echo -e "${YELLOW}[update]${RESET} ${file}"
        sleep 0.08
        echo -e "${GREEN}[built]${RESET}  in ${GRAY}$(( RANDOM % 50 + 10 ))ms${RESET}"
        sleep 0.15
    done
    echo ""
}

# Clear screen and hide cursor
clear
tput civis

# Trap to restore cursor on exit
trap 'tput cnorm; exit' INT TERM

# Main loop
while true; do
    fake_build
    sleep 0.5
    fake_git_log
    sleep 0.5
    fake_test_run
    sleep 0.5
    fake_claude_code
    sleep 0.8
    fake_file_watch
    sleep 0.5
    clear
done
