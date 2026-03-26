# Sentinel Red Flag Checklist

> Merged from skill-vetter + dependency security enhancements

## Skill Review Red Flags

### Basic Red Flags (inherited from skill-vetter)

- curl/wget to unknown URLs
- Sending data to external servers
- Requesting credentials/tokens/API keys
- Reading `~/.ssh`, `~/.aws`, `~/.config` (without clear justification)
- Accessing `MEMORY.md`, `USER.md`, `SOUL.md`, `IDENTITY.md`
- Using base64 decode
- Using `eval()`/`exec()` on external input
- Modifying system files outside the workspace
- Installing undeclared packages
- Network calls using IP addresses instead of domain names
- Obfuscated code (compressed, encoded, minified)
- Requesting sudo privileges
- Accessing browser cookies/sessions
- Touching credential files

### Enhanced Red Flags (added by sentinel)

- Contains `.pth` files
- Large blocks of base64/hex encoded content (>100 characters)
- Modifying `CLAUDE.md` or `settings.json` (privilege escalation attack)
- Registering Claude Code Hooks (can hijack other operations)
- scripts/ contains network calls targeting URLs listed in known-malicious.md
- Introducing external dependencies not declared in documentation

## Dependency Installation Red Flags

### Metadata Red Flags

- Version published < 48 hours ago
- Maintainer differs from the previous version
- Abnormal version number jumps (skipping multiple minor versions)
- Package name highly similar to a well-known package (typosquatting)
- Has medium/high severity records in the OSV vulnerability database
- Listed in known-malicious.md

### Code Content Red Flags

- `.pth` files containing executable code (`import`, `exec`, `eval`, `subprocess`)
- `setup.py` overriding `cmdclass` (install/develop/egg_info)
- `setup.py` containing network calls or process creation
- `__init__.py` with top-level network exfiltration calls
- `exec()`/`eval()` executing base64/hex decoded content
- Large base64 encoded strings (>200 characters)
- Accessing `~/.ssh`, `~/.aws`, `~/.kube`, `~/.gnupg`
- Bulk enumeration of `os.environ` (>10 references)
- npm `postinstall`/`preinstall` scripts containing `child_process` or network calls
