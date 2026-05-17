# Research: WinSW XML Configuration File Format

- **Query**: WinSW XML configuration file format -- minimal config, discovery mechanism, key elements, env vars, CLI commands, naming, permissions
- **Scope**: External (official WinSW GitHub documentation, v2.12.0)
- **Date**: 2026-05-17

## Findings

### 1. Minimal XML Config

The absolute minimal XML config only requires four elements: `id`, `name`, `description`, and `executable`.

```xml
<service>
  <id>myapp</id>
  <name>MyApp Service (powered by WinSW)</name>
  <description>This service is a service created from a minimal configuration</description>
  <executable>%BASE%\myExecutable.exe</executable>
</service>
```

All other elements (arguments, log, onfailure, etc.) are optional.

### 2. Config File Discovery Mechanism

WinSW discovers its XML config file by **convention: same directory, same base name as the exe**.

- If the executable is named `myapp.exe`, WinSW looks for `myapp.xml` in the same directory.
- There is **no command-line parameter** to specify an alternative config file path.
- This means each WinSW instance (each renamed exe) is inherently tied to exactly one XML config.

This is a critical design constraint: one exe + one xml = one service. To manage multiple services, you need multiple renamed copies of the exe, each with its own same-named XML file.

### 3. Key XML Elements Reference

#### Mandatory Elements

| Element | Description |
|---|---|
| `<id>` | Internal Windows service identifier. Must be unique system-wide. Alpha-numeric only. |
| `<name>` | Short display name shown in Windows Service Manager. Must be unique. Can contain spaces. |
| `<description>` | Long description shown in Service Manager when service is selected. |
| `<executable>` | Path to the executable to launch. Can be absolute or just a filename (searched via PATH). |

#### Execution Control

| Element | Description |
|---|---|
| `<arguments>` | Arguments passed to the executable. |
| `<startarguments>` | Arguments passed on start; overrides `<arguments>` when present. |
| `<stopexecutable>` | Optional separate executable for graceful shutdown. |
| `<stoparguments>` | Arguments for stop executable. Enables graceful shutdown via stop process. |
| `<stoptimeout>` | Time to wait for graceful shutdown before force-killing. Default: 15 sec. Format: `10 sec`, `1 min`, etc. |
| `<stopparentprocessfirst>` | Boolean. If true, parent process is terminated first. Default: true. |
| `<workingdirectory>` | Sets the working directory for the child process. Default: directory of the wrapper exe. |
| `<priority>` | Process scheduling priority. Values: `idle`, `belownormal`, `normal`, `abovenormal`, `high`, `realtime`. Default: `normal`. |

#### Service Lifecycle

| Element | Description |
|---|---|
| `<startmode>` | Service start mode: `Boot`, `System`, `Automatic`, `Manual`. Default: `Automatic`. |
| `<delayedAutoStart/>` | Boolean element (empty = true). Enables delayed auto-start. Windows 7+ only. |
| `<depend>` | Service dependency. Repeatable. e.g. `<depend>Eventlog</depend>` |
| `<waithint>` | Estimated time for pending stop, reported to SCM. Default: 15 sec. |
| `<sleeptime>` | Interval between SetServiceStatus calls. Default: 1 sec. |
| `<interactive/>` | Allows desktop interaction. Largely non-functional since Windows Vista/UAC. |
| `<beeponshutdown/>` | Emits beep on shutdown. Debug only. |

#### Failure Handling

| Element | Description |
|---|---|
| `<onfailure>` | Repeatable. Actions on process failure. Attributes: `action` (restart/reboot/none), `delay` (e.g. `10 sec`). Actions are tried in sequence; last one repeats indefinitely. |
| `<resetfailure>` | Time after which SCM resets failure counter. Default: 1 day. |

Example failure config that always restarts:
```xml
<onfailure action="restart" delay="10 sec"/>
```

Escalating failure:
```xml
<onfailure action="restart" delay="10 sec"/>
<onfailure action="restart" delay="20 sec"/>
<onfailure action="reboot" />
```

#### Logging

| Element | Description |
|---|---|
| `<logpath>` | Custom log directory. Default: same directory as config file. |
| `<log mode="...">` | Logging mode. Modes: `append` (default), `reset`, `none`, `roll-by-size`, `roll-by-time`, `roll-by-size-time`. |

Sub-elements for roll-by-size:
```xml
<log mode="roll-by-size">
  <sizeThreshold>10240</sizeThreshold>  <!-- KB, default 10240 (10MB) -->
  <keepFiles>8</keepFiles>              <!-- default 8 -->
</log>
```

Sub-elements for roll-by-time:
```xml
<log mode="roll-by-time">
  <pattern>yyyyMMdd</pattern>
</log>
```

Log file naming: `<basename>.out.log` and `<basename>.err.log` where basename matches the exe name.

#### Environment

| Element | Description |
|---|---|
| `<env>` | Sets environment variables for child process. Repeatable. `<env name="HOME" value="c:\abc" />` |

#### Download (pre-start)

| Element | Description |
|---|---|
| `<download>` | Downloads URL to local file before starting executable. Repeatable. Attributes: `from`, `to`, `failOnError`, `auth`, `user`, `password`, `proxy`. Supports If-Modified-Since since v2.7. |

#### Security / Account

| Element | Description |
|---|---|
| `<serviceaccount>` | Service account config. Sub-elements: `<domain>`, `<user>`, `<password>`, `<allowservicelogon>`. Default: LocalSystem. |
| `<securityDescriptor>` | SDDL security descriptor string. |

Predefined accounts:
```xml
<!-- LocalSystem (default) -->
<serviceaccount><user>LocalSystem</user></serviceaccount>

<!-- LocalService -->
<serviceaccount><domain>NT AUTHORITY</domain><user>LocalService</user></serviceaccount>

<!-- NetworkService -->
<serviceaccount><domain>NT AUTHORITY</domain><user>NetworkService</user></serviceaccount>
```

#### Extensions

```xml
<extensions>
  <extension enabled="true" id="ext1" className="winsw.Plugins.SharedDirectoryMapper.SharedDirectoryMapper">
    <mapping>
      <map enabled="false" label="N:" uncpath="\\UNC"/>
    </mapping>
  </extension>
</extensions>
```

Available built-in extensions:
- SharedDirectoryMapper -- map shared drives before starting executable
- RunawayProcessKiller -- terminate leftover processes from previous runs

### 4. Environment Variable Expansion

**Yes, XML configs support environment variable expansion** using `%Name%` syntax.

- Any `%VAR_NAME%` occurrence in the XML is replaced with the actual environment variable value.
- If the env var is undefined, no substitution occurs (the literal `%Name%` remains).
- WinSW automatically sets the `BASE` environment variable, pointing to the directory containing the renamed WinSW exe. This is the primary way to reference co-located files.
- The `<env>` element also sets environment variables for the child process, and those values themselves can use `%VAR%` expansion.

Example:
```xml
<env name="JENKINS_HOME" value="%BASE%"/>
<executable>java</executable>
<arguments>-Xrs -Xmx256m -jar "%BASE%\jenkins.war" --httpPort=8080</arguments>
```

### 5. CLI Commands

WinSW accepts the following commands (passed as the first argument):

| Command | Description |
|---|---|
| `install` | Install the service to Windows Service Controller. Supports `/p` flag to prompt for account credentials. |
| `uninstall` | Uninstall the service. |
| `start` | Start the service (must already be installed). |
| `stop` | Stop the service. |
| `stopwait` | Stop the service and wait until actually stopped. |
| `restart` | Restart the service. If not running, acts like `start`. |
| `status` | Print service status to console. Returns: `NonExistent`, `Started`, or `Stopped`. |

Usage pattern:
```
myapp.exe install
myapp.exe start
myapp.exe status
myapp.exe stop
myapp.exe restart
myapp.exe uninstall
```

Exit codes follow WMI Win32_Service.Create return values. Any non-zero exit code indicates failure.

### 6. Naming Requirement (Renaming the Exe)

**Yes, WinSW must be renamed per service.** There is no parameter to specify a config file path.

The official installation steps are:
1. Rename `WinSW.exe` to your service name (e.g., `myapp.exe`)
2. Create `myapp.xml` with the same base name in the same directory
3. Place both files side by side
4. Run `myapp.exe install`

This is the fundamental constraint that motivates the PRD's architecture: the `shims/` directory holds multiple renamed copies (`shims/<svc>.exe` + `shims/<svc>.xml`), one pair per service.

WinSW also supports YAML config files (same naming convention: `myapp.yml` instead of `myapp.xml`), but XML is the primary and more commonly used format.

### 7. Permission Requirements

- **All management commands (install, uninstall, start, stop, restart, status) require Administrator privileges.**
- Since v2.8, WinSW will automatically prompt for UAC elevation in non-elevated sessions.
- The service itself runs under the configured `<serviceaccount>`, defaulting to LocalSystem (high privilege).
- For least-privilege operation, use LocalService, NetworkService, or a dedicated user account via `<serviceaccount>`.
- The `install` command with `/p` flag prompts for credentials interactively.

## External References

- [XML Configuration File](https://github.com/winsw/winsw/blob/v2.12.0/doc/xmlConfigFile.md) -- primary reference for all XML elements
- [YAML Configuration File](https://github.com/winsw/winsw/blob/v2.12.0/doc/yamlConfigFile.md) -- alternative YAML format
- [Installation Guide](https://github.com/winsw/winsw/blob/v2.12.0/doc/installation.md) -- step-by-step install instructions
- [Logging and Error Reporting](https://github.com/winsw/winsw/blob/v2.12.0/doc/loggingAndErrorReporting.md) -- log modes detailed
- [Sample: minimal](https://github.com/winsw/winsw/blob/v2.12.0/examples/sample-minimal.xml) -- minimal config example
- [Sample: all options](https://github.com/winsw/winsw/blob/v2.12.0/examples/sample-allOptions.xml) -- full config example with all options
- [WinSW README](https://github.com/winsw/winsw/blob/v2.12.0/README.md) -- CLI commands and overview

## Related Specs

- `bucket/winsw.json` -- current Scoop manifest for WinSW v2.12.0
- `.trellis/tasks/05-17-winsw-task-svc-mgr/prd.md` -- project PRD referencing this research

## Caveats / Not Found

- No CLI option exists to specify an arbitrary config file path -- the same-name convention is mandatory.
- YAML config is also supported (`.yml` extension) but less commonly documented; the XML format is the primary one.
- The `rotate` log mode is deprecated in favor of `roll`.
- The `zipOlderThanNumDays` log archiving feature is reported as broken in recent versions.
- WinSW v2.x extension APIs are not binary-compatible across versions.
