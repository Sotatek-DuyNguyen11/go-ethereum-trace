# Code Standards: go-ethereum-trace

## Go Conventions

### Formatting

**Before every commit, run:**

```bash
gofmt -w <modified files>      # Canonical formatting
goimports -w <modified files>  # Auto-organize imports + gofmt
```

Tools to configure in editor:
- **VSCode:** Enable `editor.formatOnSave` with `golang.useLanguageServer: true`
- **GoLand/IntelliJ:** Format on Save enabled by default

### Import Organization

`goimports` automatically orders imports:
```go
import (
  "fmt"                                              // standard library
  "math/big"                                        // standard library

  "github.com/ethereum/go-ethereum/common"          // external
  "github.com/ethereum/go-ethereum/core/types"      // external
)
```

**Rule:** Never manually organize imports; let `goimports` handle it.

### Naming Conventions

**Packages:** lowercase, single word (prefer clarity over brevity)
```go
package tracing      // ✅ good
package tracingcore  // ❌ hard to read
```

**Types:** PascalCase, exported; unexported types are rare
```go
type StateDB struct { }        // ✅ exported
type hookedStateDB struct { }  // ✅ unexported (internal)
```

**Functions/Methods:** PascalCase for exported; camelCase for unexported
```go
func (h *Hooks) OnBalanceChange() {}       // ✅ exported
func (s *StateDB) mutateBalance() {}       // ✅ unexported
```

**Constants:** PascalCase (exported) or CONSTANT_CASE (internal semantics)
```go
const DefaultTraceTimeout = 5 * time.Second     // ✅ exported
const maxPendingTraceStates = 128               // ✅ unexported
```

**Variables:** camelCase
```go
var stateRoot common.Hash     // ✅ exported
var txIndex int               // ✅ local
```

**Interfaces:** Short, descriptive names ending in `-er`
```go
type Reader interface { }      // ✅ good
type StateDB interface { }     // ✅ idiomatic
type Backend interface { }     // ✅ good
```

### Documentation (Godoc)

**Required:** Every exported type, function, const, var
- Starts with name of the thing being documented
- Ends with a period
- Blank line separates from detailed docs

```go
// Hooks holds function pointers for tracing hooks.
// When a hook is nil, it is not called (zero overhead).
type Hooks struct {
  OnEnter func(depth int, frame *Frame) error
  OnExit  func(depth int, frame *Frame, result []byte, err error)
}

// NewHookedState wraps the given stateDb with the given hooks.
func NewHookedState(stateDb *StateDB, hooks *Hooks) *hookedStateDB {
  ...
}
```

**Not required:** Unexported functions, trivial getters, implementation details

### Error Handling

**Prefer explicit error handling:**

```go
// ✅ good
result, err := someFunc()
if err != nil {
  return fmt.Errorf("failed to compute: %w", err)
}

// ❌ avoid
result, _ := someFunc()  // never ignore errors silently
```

**For recoverable errors, use sentinel values:**

```go
var (
  ErrTransactionNotFound = errors.New("transaction not found")
  ErrInvalidInput        = errors.New("invalid input")
)

if err == ErrTransactionNotFound {
  // handle specific case
}
```

### Concurrency & Safety

**Use sync primitives for goroutine safety:**

```go
type Cache struct {
  mu    sync.RWMutex
  items map[string]interface{}
}

func (c *Cache) Get(key string) interface{} {
  c.mu.RLock()
  defer c.mu.RUnlock()
  return c.items[key]
}
```

**Avoid goroutine leaks:** Always channel close / ensure goroutine cleanup

### Code Organization (File Structure)

**Single-file packages:** Keep related code together
- Interfaces at top
- Implementation structs/functions follow
- Tests in separate `*_test.go` files

**Multi-file packages:** Organize by responsibility
```
core/tracing/
├── hooks.go           # Type definitions & interfaces
├── journal.go         # Journal implementation
├── hooks_test.go
└── journal_test.go
```

**Avoid:** Cyclic imports, giant 1000+ LOC files (refactor into focused modules)

## Commit Message Format

**Format:**
```
<package(s)>: description
```

**Rules:**
- Prefix with affected package(s), comma-separated for multiple
- Lowercase description (no capitals after colon)
- Concise (aim for <60 chars)
- Imperative mood ("add", not "adds" or "added")

**Examples:**

✅ Good:
- `core/tracing: add Balance mutation reason enums`
- `eth, tracers: implement flatCall tracer`
- `cmd/workload: fix trace test validation`
- `core/vm: optimize stack push operation`

❌ Avoid:
- `Fix bug` (too vague, no package)
- `core/tracing: Added new reason enums` (capitalized, past tense)
- `core/tracing: this adds balance mutation tracking to the hooks system` (too long)

## Pull Request Title Format

**Format:**
```
<path(s)>: description
```

**Rules:**
- List top-level package paths affected (comma-separated if multiple)
- Keep under 70 characters
- Same imperative, lowercase style as commits

**Examples:**

✅ Good:
- `core/vm: fix stack overflow in PUSH instruction`
- `core, eth: add arena allocator support`
- `eth/tracers: implement Parity-compatible flatCall`

❌ Avoid:
- `Fix bug` (no path, vague)
- `core/vm: fix stack overflow in PUSH instruction operation in the EVM` (too long)

## Pre-Commit Checklist

Before **every commit**, run all checks in order:

### 1. Formatting

```bash
gofmt -w <modified files>
goimports -w <modified files>
```

Check no diffs remain after formatting:
```bash
git diff
```

### 2. Build All Commands

```bash
make all
```

**Must succeed with no errors.** This builds all executables, including custom ones like `workload`.

### 3. Tests

**Development (iterative):**
```bash
go run ./build/ci.go test -short
```

**Before commit (final):**
```bash
go run ./build/ci.go test
```

**Requirements:**
- All tests pass (including execution-spec tests, block/state test permutations)
- Do NOT commit if tests fail
- Do NOT use `-short` flag for final check

### 4. Linting

```bash
go run ./build/ci.go lint
```

Fix all linting issues before committing. Common issues:
- Unused variables/imports
- Cyclic imports
- Missing error checks

### 5. Generated Code

```bash
go run ./build/ci.go check_generate
```

If this fails:
1. Install code generators: `make devtools`
2. Run `go generate ./...` on affected packages
3. Include updated `gen_*.go` files in commit

### 6. Dependency Hygiene

```bash
go run ./build/ci.go check_baddeps
```

Ensures no forbidden dependencies introduced. Common offenders:
- Importing `cmd/*` packages (not allowed)
- Adding OS-specific dependencies without guards

## What to Commit

**Include:**
- `.go` source files (formatted, tested)
- `.md` documentation updates
- Generated files (`gen_*.go`)
- Test files (`*_test.go`)

**Exclude:**
- Binaries (`geth`, `evm`, other executables in `build/bin/`)
- Temporary files (`.tmp`, `*.bak`)
- IDE config (`.vscode/`, `.idea/`)
- OS files (`.DS_Store`)

**Note:** `.gitignore` already excludes most build artifacts

## Code Review Standards

**Self-review before pushing:**

1. Read your own diff: `git diff`
2. Verify:
   - No unintended changes
   - No debug prints or commented code
   - Formatting clean
   - Tests pass
3. Check commit message format matches this doc

**When reviewing others' PRs:**

- Verify formatting & imports
- Check error handling (no `_` ignores)
- Ensure tests cover new functionality
- Watch for unnecessary refactoring (keep changes focused)

## File Size Management

**Guideline:** Keep `.go` files under 200 LOC for optimal readability
- Split large packages into focused modules
- Use composition over inheritance
- Extract utility functions into separate files

**Monitor with:**
```bash
find . -name "*.go" -exec wc -l {} + | sort -rn | head -20
```

**Example refactoring trigger:** `eth/tracers/api.go` is 41KB; consider splitting into:
- `api.go` (common types & helpers)
- `api_transaction.go` (TraceTransaction logic)
- `api_block.go` (TraceBlock logic)
- `api_call.go` (TraceCall logic)

## Testing Conventions

**Test file naming:** `<package>_test.go` in same directory

**Test function naming:** `Test<Function><Scenario>`

```go
func TestStateDB_CreateAccount(t *testing.T) { }
func TestStateDB_CreateAccount_Duplicate(t *testing.T) { }
func TestHooks_OnBalanceChange_NilHook(t *testing.T) { }
```

**Coverage target:** Aim for >80% on new code

**Table-driven tests:** Use for multiple scenarios

```go
tests := []struct {
  name    string
  input   interface{}
  want    interface{}
  wantErr bool
}{
  {"valid", input1, want1, false},
  {"invalid", input2, nil, true},
}

for _, tt := range tests {
  t.Run(tt.name, func(t *testing.T) {
    got, err := Func(tt.input)
    if (err != nil) != tt.wantErr {
      t.Errorf("got err %v, want %v", err, tt.wantErr)
    }
    if got != tt.want {
      t.Errorf("got %v, want %v", got, tt.want)
    }
  })
}
```

## Security & Best Practices

**Input validation:**
```go
if len(data) == 0 {
  return fmt.Errorf("data cannot be empty")
}
```

**Avoid panic in libraries:** Use errors instead
```go
// ✅ library
if invalid {
  return fmt.Errorf("invalid state")
}

// ❌ library
if invalid {
  panic("invalid state")  // only in cmd/ executables for fatal errors
}
```

**Secure memory:** Clear sensitive data when done
```go
defer copy(sensitiveBytes, make([]byte, len(sensitiveBytes)))  // zero out
```

## Documentation Files

**Required:**
- `.go` files: Godoc comments on all exported types/functions
- Package-level `.go` files: `package <name> // Package X does...`

**Keep current:**
- `docs/` files sync with code changes
- Update `docs/project-changelog.md` with significant changes
- Update `docs/project-roadmap.md` when milestones shift

## Tools & Setup

**Installation:**

```bash
# Install formatter tools
goimports                    # auto-installed with Go
gofmt                        # auto-installed with Go

# Install dev tools
make devtools

# Setup pre-commit hooks (optional but recommended)
# Manual: run pre-commit checks before committing
```

**CI/CD runs these automatically on PR:**
- `gofmt` check (fail if diffs)
- Build (`make all`)
- Tests (`go run ./build/ci.go test`)
- Linting (`go run ./build/ci.go lint`)

---

**Summary:** Clean formatting, clear error handling, focused commits, passing tests. No exceptions.
