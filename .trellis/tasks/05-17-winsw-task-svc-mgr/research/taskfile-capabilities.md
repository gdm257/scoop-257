# Research: Taskfile (go-task/task) Capabilities

- **Query**: Research task runner at taskfile.dev for winsw service manager integration
- **Scope**: External
- **Date**: 2026-05-17

## Findings

### 1. Positional Arguments and Dynamic Task Names

Task supports **two mechanisms** for passing dynamic arguments to tasks:

#### a) CLI Variables (named, after task name)

Variables can be passed as `KEY=VALUE` pairs after the task name:

```shell
task greet_user USER_NAME="Bob"
```

Inside the Taskfile, accessed via `{{.USER_NAME}}`. Use `default` for fallback:

```yaml
tasks:
  greet_user:
    vars:
      USER_NAME: '{{.USER_NAME | default "DefaultUser"}}'
    cmds:
      - echo "Hello, {{.USER_NAME}}!"
```

#### b) CLI_ARGS (positional, after `--`)

Everything after `--` is captured in `{{.CLI_ARGS}}` (string) and `{{.CLI_ARGS_LIST}}` ([]string):

```shell
task start -- myservice
```

```yaml
tasks:
  start:
    cmds:
      - echo "Starting {{.CLI_ARGS}}"       # "Starting myservice"
```

#### c) Wildcard Task Names (dynamic task routing) -- KEY FEATURE

Task supports `*` wildcards in task names. Matched segments are captured in `.MATCH` array:

```yaml
tasks:
  start:*:
    vars:
      SERVICE: '{{index .MATCH 0}}'
    cmds:
      - echo "Starting {{.SERVICE}}"

  start:*:*:
    vars:
      SERVICE: '{{index .MATCH 0}}'
      REPLICAS: '{{index .MATCH 1}}'
    cmds:
      - echo "Starting {{.SERVICE}} with {{.REPLICAS}} replicas"
```

Usage:
```shell
task start:myservice        # matches start:*, .MATCH[0] = "myservice"
task start:myservice:3      # matches start:*:*, .MATCH[0] = "myservice", .MATCH[1] = "3"
task "start:foo bar"        # whitespace allowed if quoted
```

**Relevance to winsw**: `task start:myservice` is a natural fit. The wildcard pattern `start:*` captures the service name.

---

### 2. Taskfile Discovery (Search Path, Parent Directories, Global)

#### Discovery order
1. Current working directory first
2. If not found, walks **up parent directories** (like `git`)
3. When found in a parent, behaves as if run from that directory

#### Supported filenames (in priority order)
- `Taskfile.yml`, `taskfile.yml`
- `Taskfile.yaml`, `taskfile.yaml`
- `Taskfile.dist.yml`, `taskfile.dist.yml`
- `Taskfile.dist.yaml`, `taskfile.dist.yaml`

#### Global Taskfile
- `task --global` (alias `-g`) looks for `$HOME/{T,t}askfile.{yml,yaml}`
- When running globally, tasks execute in `$HOME` by default
- Use `{{.USER_WORKING_DIR}}` to reference the directory where `task -g` was invoked

#### Explicit path
- `--taskfile <path>` (alias `-t`) specifies an explicit Taskfile
- `--dir <path>` specifies the working directory

**Relevance to winsw**: A global Taskfile at `~/.config/winsw/Taskfile.yml` could be invoked via `task -t ~/.config/winsw/Taskfile.yml`, or `task --global` if placed in `$HOME/Taskfile.yml`. The `--taskfile` flag gives the most control for `winsw-manage` alias.

---

### 3. Include/Import Other Taskfiles

Task uses the `includes` keyword (not `import`):

```yaml
version: '3'

includes:
  docs: ./documentation          # looks for ./documentation/Taskfile.yml
  docker: ./DockerTasks.yml      # explicit filename
```

Namespaced calls: `task docs:serve`, `task docker:build`.

#### Advanced include options

```yaml
includes:
  docs:
    taskfile: ./docs/Taskfile.yml
    dir: ./docs                  # run tasks from this directory
    vars:                        # pass variables to included file
      DOCKER_IMAGE: backend_image
    optional: true               # don't error if file missing
    internal: true               # hide tasks from listing
    flatten: true                # no namespace prefix needed
    aliases: [gen]               # alternative namespace names
    excludes: [foo]              # exclude specific tasks
```

#### OS-specific includes

```yaml
includes:
  build: ./Taskfile_{{OS}}.yml   # template-based selection
```

#### From global to local
A global Taskfile **can** include a local one by using an absolute or templated path:

```yaml
# ~/Taskfile.yml (global)
includes:
  local:
    taskfile: '{{.USER_WORKING_DIR}}/Taskfile.local.yml'
    optional: true
```

**Relevance to winsw**: A global winsw Taskfile could include project-level Taskfiles, or users can include a shared winsw utility Taskfile in their project.

---

### 4. Iteration/Loops Over a List of Items

Task provides a powerful `for:` construct at the `cmds` and `deps` level.

#### Static list

```yaml
tasks:
  default:
    cmds:
      - for: ['foo.txt', 'bar.txt']
        cmd: cat {{.ITEM}}
```

#### Over a variable

```yaml
tasks:
  default:
    vars:
      SERVICES: [nginx, postgres, redis]
    cmds:
      - for:
          var: SERVICES
        cmd: echo "Starting {{.ITEM}}"
```

#### String splitting

```yaml
tasks:
  default:
    vars:
      MY_VAR: foo.txt,bar.txt
    cmds:
      - for: { var: MY_VAR, split: ',' }
        cmd: cat {{.ITEM}}
```

#### Over glob sources/generates

```yaml
tasks:
  default:
    sources:
      - '*.txt'
    cmds:
      - for: sources
        cmd: cat {{.ITEM}}
```

#### Matrix (Cartesian product)

```yaml
tasks:
  default:
    cmds:
      - for:
          matrix:
            OS: ['windows', 'linux', 'darwin']
            ARCH: ['amd64', 'arm64']
        cmd: echo "{{.ITEM.OS}}/{{.ITEM.ARCH}}"
```

#### Renaming iterator variable

```yaml
tasks:
  default:
    vars:
      SERVICES: [nginx, postgres, redis]
    cmds:
      - for: { var: SERVICES, as: SVC }
        cmd: echo "Starting {{.SVC}}"
```

#### Looping over tasks (run different task per item)

```yaml
tasks:
  default:
    cmds:
      - for: [foo, bar]
        task: task-{{.ITEM}}

  task-foo:
    cmds:
      - echo 'foo'

  task-bar:
    cmds:
      - echo 'bar'
```

#### Looping over deps (parallel)

```yaml
tasks:
  default:
    deps:
      - for: [foo, bar]
        task: my-task
        vars:
          FILE: '{{.ITEM}}'
```

#### Map iteration
When looping over a map, `{{.KEY}}` is also available.

#### Dynamic variable as loop source

```yaml
tasks:
  default:
    vars:
      MY_VAR:
        sh: find -type f -name '*.txt'
    cmds:
      - for: { var: MY_VAR }
        cmd: cat {{.ITEM}}
```

**Relevance to winsw**: Can iterate over all `shims/*.exe` files for status/stop/uninstall operations using `for: sources` with a glob, or iterate over a declared service list variable.

---

### 5. Dynamic Commands Based on Variables

Task fully supports dynamic command construction via Go template interpolation:

```yaml
tasks:
  start:*:
    vars:
      SERVICE: '{{index .MATCH 0}}'
    cmds:
      - 'shims/{{.SERVICE}}.exe start'

  stop:*:
    vars:
      SERVICE: '{{index .MATCH 0}}'
    cmds:
      - 'shims/{{.SERVICE}}.exe stop'
```

Any string in `cmds` can use `{{.VAR}}` interpolation. Combined with:
- Wildcard task names for routing
- `for` loops for batch operations
- Dynamic variables (`sh:`) for runtime values
- Full Go template functions (string manipulation, conditionals, etc.)

**Relevance to winsw**: This is the core mechanism. `shims/{{.SERVICE}}.exe start` is exactly the pattern needed.

---

### 6. Syntax for Vars, Env Vars, and CLI Vars

#### Global vars

```yaml
version: '3'

vars:
  GREETING: Hello from Taskfile!
  SERVICES: [nginx, postgres, redis]
  CONFIG:
    map:
      timeout: 30
      retries: 3

tasks:
  greet:
    cmds:
      - echo "{{.GREETING}}"
```

#### Task-level vars

```yaml
tasks:
  build:
    vars:
      GIT_COMMIT:
        sh: git log -n 1 --format=%h   # dynamic var from shell
    cmds:
      - go build -ldflags="-X main.Version={{.GIT_COMMIT}}"
```

#### CLI variables

```shell
# Named variables
task build IMAGE_NAME=myapp IMAGE_TAG=v1.0

# Positional via --
task start -- myservice
```

Inside Taskfile:
- `{{.IMAGE_NAME}}` / `{{.IMAGE_TAG}}` for named vars
- `{{.CLI_ARGS}}` for everything after `--`
- `{{.CLI_ARGS_LIST}}` for shell-parsed list

#### Environment variables

Global:
```yaml
env:
  GREETING: Hey, there!
```

Task-level:
```yaml
tasks:
  greet:
    env:
      GREETING: Hey, there!
    cmds:
      - echo $GREETING
```

dotenv files:
```yaml
dotenv: ['.env', '{{.ENV}}/.env']
```

#### Variable precedence (highest to lowest)
1. Variables declared in the task definition
2. Variables given when calling a task from another task
3. Variables of the included Taskfile
4. Variables of the inclusion (when including with vars)
5. Global variables (`vars:` at root)
6. Environment variables

#### Special variables always available
- `{{.TASK}}` - current task name
- `{{.ROOT_DIR}}` - absolute path of root Taskfile directory
- `{{.TASK_DIR}}` - absolute path where task is executed
- `{{.USER_WORKING_DIR}}` - where `task` was called from
- `{{.CLI_ARGS}}` / `{{.CLI_ARGS_LIST}}` - CLI arguments after `--`
- `{{OS}}` / `{{ARCH}}` - runtime OS/arch
- `{{.TASK_VERSION}}` - task binary version

#### Types supported
`string`, `bool`, `int`, `float`, `array`, `map` (maps need `map:` subkey)

#### Reference passing (preserves type)
```yaml
vars:
  FOO:
    ref: .OTHER_VAR    # passes by reference, preserves array/map types
```

---

### 7. Task-Level Prerequisites/Dependencies

Task supports two mechanisms:

#### `deps` (dependencies, run in parallel before the task)

```yaml
tasks:
  build:
    deps: [assets]
    cmds:
      - go build -v -i main.go

  assets:
    cmds:
      - esbuild --bundle --minify css/index.css > public/bundle.css
```

Multiple deps run **in parallel**:
```yaml
tasks:
  assets:
    deps: [js, css]    # both run in parallel
```

Passing vars to deps:
```yaml
tasks:
  default:
    deps:
      - task: echo_sth
        vars: { TEXT: 'before 1' }
      - task: echo_sth
        vars: { TEXT: 'before 2' }
```

#### Serial task calls (in `cmds`)

```yaml
tasks:
  main-task:
    cmds:
      - task: task-to-be-called    # runs serially
      - task: another-task         # runs after first
      - echo "Both done"
```

#### `preconditions` (must be true, or task fails)

```yaml
tasks:
  deploy:
    preconditions:
      - test -f .env
      - sh: '[ "$CI" = "true" ]'
        msg: "Must be running in CI"
    cmds:
      - ./deploy.sh
```

#### `requires` (ensure variables are set)

```yaml
tasks:
  deploy:
    requires:
      vars: [IMAGE_NAME, IMAGE_TAG]
    cmds:
      - docker build . -t {{.IMAGE_NAME}}:{{.IMAGE_TAG}}
```

#### `if` (conditional skip, non-failing)

```yaml
tasks:
  deploy:
    if: '[ "$CI" = "true" ]'
    cmds:
      - echo "Deploying..."
```

**Relevance to winsw**: `deps` can ensure prerequisites run first (e.g., `install` before `start`). `preconditions` can verify admin privileges or service existence before operations.

---

### 8. `for:` Loops in Task

**Yes, fully supported.** See section 4 above for comprehensive details.

Summary of `for:` capabilities:
- Static lists: `for: ['a', 'b', 'c']`
- Variable iteration: `for: { var: MY_VAR }`
- String splitting: `for: { var: MY_VAR, split: ',' }`
- Sources/generates glob: `for: sources` or `for: generates`
- Matrix (Cartesian product): `for: { matrix: { OS: [...], ARCH: [...] } }`
- Custom iterator name: `for: { var: X, as: ITEM_NAME }`
- Works on both `cmds` and `deps`
- Can call different tasks per item: `task: task-{{.ITEM}}`
- Iterator accessed via `{{.ITEM}}` (default) or custom name
- Map iteration provides `{{.KEY}}` and `{{.ITEM}}`

---

## Summary Table: winsw Use Case Mapping

| winsw Requirement | Taskfile Feature | Syntax Pattern |
|---|---|---|
| `winsw-manage start myservice` | Wildcard task names | `start:*` + `.MATCH[0]` |
| `winsw-manage status` (all services) | `for:` loop over glob | `for: sources` with `shims/*.exe` glob |
| `winsw-manage stop myservice` | Wildcard + dynamic cmd | `stop:*` + `shims/{{.SERVICE}}.exe stop` |
| `winsw-manage install` (batch) | `for:` loop + variable | `for: { var: SERVICES }` |
| Service list configuration | Global `vars:` | `vars: { SERVICES: [...] }` |
| Discover services dynamically | Dynamic vars (`sh:`) | `vars: { SERVICES: { sh: "ls shims/*.exe" } }` |
| Global Taskfile | `--global` or `--taskfile` | `task -g` or `task -t path/to/Taskfile.yml` |
| Admin check before ops | `preconditions` | `preconditions: [...]` |
| Ensure service name provided | `requires` | `requires: { vars: [SERVICE] }` |

## External References

- [Taskfile Guide](https://taskfile.dev/docs/guide) - Main documentation (usage, includes, vars, loops, deps)
- [Taskfile Templating Reference](https://taskfile.dev/docs/reference/templating) - All template functions and special variables
- [Taskfile Schema Reference](https://taskfile.dev/docs/reference/schema) - Full YAML schema
- [go-task/task GitHub](https://github.com/go-task/task) - Source repository
- [slim-sprig library](https://sprig.taskfile.dev/) - Template function library used by Task

## Caveats / Not Found

- Task does NOT support true positional arguments (like `$1`, `$2`). The `--` separator puts everything into `.CLI_ARGS` as a single string. For structured args, use wildcard task names or named CLI variables.
- `deps` run in parallel by design. For serial execution, use `cmds` with `task:` calls.
- Each command runs in a separate shell process. Shell state (variables, `cd`) does not persist between commands. Use multiline commands (`|`) for multi-step shell logic.
- Windows core utilities (cat, ls, cp, etc.) are compiled into the Task binary for compatibility.
- The `dotenv` key cannot be used inside included Taskfiles (only in the root Taskfile).
- Remote Taskfile includes are an experimental feature (`experiments/remote-taskfiles`).
