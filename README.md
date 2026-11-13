# ocbox

Run **OpenCode V2** against an entire projects directory using **Docker (Docker Desktop or OrbStack) on local** and **Apptainer on HPC**. The container also includes [XERJ](https://github.com/xerj-org/xerj), a local search/index service launched alongside OpenCode.

It exposes one common `oc` command on both machines, with the same container paths but independent machine-specific mounts, secrets, and persistent state.

## How it works

| Host | Container runtime | Image | Project path inside container |
| --- | --- | --- | --- |
| local | Docker | `ocbox:local` | `/workspace` |
| HPC | Apptainer | `opencode.sif` | `/workspace` |

The launch script:

- Mounts a **writable persistent home** at `/home/oc`, including OpenCode sessions and configuration.
- Reads host-to-container directory mappings from `dirs.txt`.
- Copies Git-tracked OpenCode configuration, global instructions, agent customizations, and skills into the persistent home before starting.
- Reads optional API keys from `secrets.env`.
- Runs `ocxerj`, which starts XERJ and then OpenCode.
- Can start in a particular project using `OC_PROJECT` while leaving the **entire** `/workspace` tree available.

## Prerequisites

**Local:** Docker Desktop or OrbStack (providing the `docker` CLI and a running Docker daemon), Git and Bash.

**HPC:** Apptainer, Git, Bash, a writable directory for `home/`, and sufficient permission to build/pull a SIF.

The container build fetches npm packages and XERJ from the internet. First-run OpenCode plugins may also require network access; this may be restricted on some clusters.

## Repository layout

```text
ocbox/
├── Dockerfile                 # Container dependencies
├── build.sh                   # Platform-specific build
├── oc                         # Cross-platform launcher
├── ocxerj                     # Starts XERJ and OpenCode inside container
├── config/                    # Tracked, non-secret configuration
│   ├── opencode.jsonc         # OpenCode V2 providers, plugins, MCP settings
│   ├── oh-my-opencode-slim.jsonc
│   ├── service.json           # MCP server configurations
│   ├── AGENTS.md              # Optional global instructions
│   ├── oh-my-opencode-slim    # oh-my-opencode-slim agents append files
│   └── skills/                # SKILL.md directories (skills must exists, subdirs are optional)
│       ├── caveman/           # Caveman skill
│       ├── ponytail/          # Ponytail skill
│       ├── ponytail-review/   # Ponytail review skill
│       ├── ponytail-audit/    # Ponytail audit skill
│       ├── ponytail-help/     # Ponytail help skill
│       ├── ponytail-gain/     # Ponytail gain skill
│       └── ponytail-debt/     # Ponytail debt skill
├── dirs.example.txt           # Example directory mappings
├── secrets.example.env        # Example secrets placeholders
├── dirs.txt                   # Local host paths; DO NOT commit
├── secrets.env                # Provider keys; DO NOT commit
├── home/                      # Persistent private runtime state; DO NOT commit
└── opencode.sif               # Generated on HPC; DO NOT commit
```

## Quick start

### 1. Get the repository

```bash
git clone git@github.com:vadmbertr/ocbox.git
cd ocbox
```

### 2. Set up local mounts: `dirs.txt`

Each line is `HOST_PATH:CONTAINER_PATH[:ro|rw]`, or simply `HOST_PATH` for a same-path bind. The default is `rw`. Lines beginning with `#` are ignored.

**local example** (replace with your own paths):

```text
/Users/YOU/projects:/workspace:rw
/Users/YOU/data:/data:ro
```

**HPC example** (replace with paths actually mounted on your cluster):

```text
/cluster/path/to/projects:/workspace:rw
/cluster/path/to/data:/data:ro
```

The important convention is that **all of your projects** map to `/workspace`. OpenCode can then access `/workspace/project-a`, `/workspace/project-b`, etc., in a single session. Bind-mounting a directory `rw` gives the container tools permission to modify the host files.

**Note:** Paths must be valid on the machine where you start `oc`. Maintain a separate, untracked `dirs.txt` on local and cluster.

### 3. Set up credentials: `secrets.env`

The launcher passes this file via Docker/Apptainer `--env-file`. Example:

```dotenv
ALAN_API_KEY=replace_me
MISTRAL_API_KEY=replace_me
```

```bash
chmod 600 secrets.env
```

Never commit keys or OAuth/session files. For built-in providers and custom endpoints, keep the **non-secret** provider definitions in `config/opencode.jsonc`; use `{env:VARIABLE_NAME}` references for keys according to the OpenCode V2 configuration supported by your installed version.

### 4. Build

On **local**:

- `./build.sh build` (or `./build.sh`) - Local Docker build tagged as `ocbox:local`
- `./build.sh publish` - Build and push multi-arch image to GHCR (default: `ghcr.io/vadmbertr/ocbox:latest`)
- `./build.sh sync` - Pull from GHCR and tag as `ocbox:local`

On **HPC**:

- `./build.sh` - Pull OCI image from GHCR and convert to `opencode.sif`

Override the default OCI image with: `ocbox_IMAGE=ghcr.io/YOUR_ACCOUNT/ocbox:VERSION ./build.sh [publish|sync]`

### 5. Run

From the `ocbox` directory:

```bash
./oc
OC_PROJECT=project-a ./oc
```

For a convenient `oc` command from anywhere, add your `ocbox` directory to `PATH`, or create a shell alias pointing to the absolute path of `oc`.

`OC_PROJECT` sets the starting directory to `/workspace/<project>`. It does **not** limit OpenCode's access to other mounted projects. The relative project path must exist inside `/workspace`.

## Git and GitHub access (optional)

The image includes **Git** and **GitHub CLI (`gh`)**. Agents can make local commits without authentication. To enable GitHub operations (`git pull`, `git push`, `gh pr create`, etc.) over HTTPS, create a [fine-grained GitHub token](https://github.com/settings/personal-access-tokens/new) restricted to the repositories you want agents to access, with **Contents: read/write** and **Pull requests: read/write** permissions as needed.

Add the token and your commit identity to the Git-ignored `secrets.env`:

```dotenv
GH_TOKEN=github_pat_...
GIT_AUTHOR_NAME=Your Name
GIT_AUTHOR_EMAIL=your-verified-or-noreply-github-email
GIT_COMMITTER_NAME=Your Name
GIT_COMMITTER_EMAIL=your-verified-or-noreply-github-email
```

At startup, `ocxerj` automatically configures GitHub CLI authentication and rewrites GitHub SSH-style remotes to HTTPS when `GH_TOKEN` is set.

No SSH keys or agent forwarding are needed. To check access from inside the container, use `gh auth status` and `git ls-remote origin HEAD`.

## OpenCode V2 configuration, plugins, and skills

Configuration is tracked under `config/` and copied by `oc` into `/home/oc/.config/opencode/` at launch. The runtime copy remains writable so OpenCode can write its generated files (such as service metadata).

For this project, the OpenCode V2 config filename is `config/opencode.jsonc`.

The `oh-my-opencode-slim` plugin, if enabled in `opencode.jsonc`, uses its separate `config/oh-my-opencode-slim.jsonc` configuration.

Reusable global skills belong in:

```text
config/skills/<skill-name>/SKILL.md
```

For example, Caveman or Ponytail variants can live alongside your own skills. On launch they are copied into `/home/oc/.config/opencode/skills/`. Project-specific skills should instead live in that project's own OpenCode configuration.

## XERJ search and persistence

`ocxerj` launches XERJ before OpenCode, stores its admin key and index in the XERJ data directory. It can index the whole workspace on demand:

```bash
OC_XERJ_INDEX=1 ./oc
```

Or a project specific directory when combined with `OC_PROJECT`:

```bash
OC_PROJECT=project-a OC_XERJ_INDEX=1 ./oc
```

Ordinary runs (`./oc`) start XERJ without invoking that explicit `autoindex /workspace` step.

### local: XERJ Docker volume

XERJ's index initialization fails in this setup when its data directory lived on a macOS-host bind mount, but succeeds on a Linux-native container filesystem. The launcher therefore mounts a persistent Docker named volume:

```text
ocbox-xerj  ->  /home/oc/.local/share/xerj
```

Create it and initialize ownership **once** for your local Docker UID/GID:

```bash
docker volume create ocbox-xerj
docker run --rm --user 0 \
  -v ocbox-xerj:/data \
  alpine:3.20 \
  chown "$(id -u):$(id -g)" /data
```

### HPC: persistent writable XERJ data

Unlike Docker, Apptainer does not provide Docker named volumes. Choose a persistent writable location appropriate for database workloads and bind it into `/home/oc/.local/share/xerj` (or configure XERJ's data directory explicitly).

Also note that Apptainer generally shares the host's networking namespace. A XERJ server bound to a fixed port may conflict with other jobs or users on the same node.

## OCI image workflow

The project uses a single Dockerfile. The `build.sh` script implements the OCI workflow:

```text
Dockerfile (single source)
        |
        v
OCI image in GHCR (linux/arm64 + linux/amd64, or amd64-only)
        |                                  |
        v                                  v
Docker/OrbStack on local           Apptainer pull on HPC
                                    -> opencode.sif
```

An OCI registry image is an **input** to Apptainer; the HPC cluster still runs a local `.sif`. The image must have a build for the cluster's CPU architecture (typically `linux/amd64`). The `oc` launcher references `ocbox:local` on local and `opencode.sif` on HPC.
