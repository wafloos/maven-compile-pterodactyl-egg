# Maven Compile Pterodactyl Egg

Small Docker image + entrypoint to build Java/Maven plugins inside a Pterodactyl egg (Wings). Intended for compiling plugin projects uploaded to the server and making the build artifacts available to the panel File Manager.

This README covers:
- how the entrypoint chooses what to build
- environment variables / egg service variables to expose
- common startup examples for Pterodactyl
- troubleshooting tips

---

## How it works (short)
- The container runs `/entrypoint.sh` which builds one or more Maven projects.
- If `PLUGIN_DIR` is set, that single path is built (relative to `/home/container` unless absolute).
- Otherwise `PLUGIN_PATHS` is used; this can be a list (comma/colon/semicolon-separated) and supports globs (`/home/container/*`).
- By default Maven writes artifacts to each project's `target/` directory (Maven behaviour).
- If `OUT_DIR` is set (non-empty), the script copies `*.jar` and `*.war` from each project's `target/` into `OUT_DIR` (useful for having all artifacts in one place for download via the panel).
- If `mvnw` exists in a project, the script uses that; otherwise it uses the image's `mvn`.
- Optional `MAVEN_SETTINGS` will be passed to Maven with `-s <path>`.

---

## Environment / Egg Service Variables

Recommended service variables to add to your Egg:

- `PLUGIN_DIR` (optional)
  - If set, builds this single project directory (relative to `/home/container` if not absolute).
  - Example: `pluginA` or `/data/pluginB`

- `PLUGIN_PATHS`
  - Default: `/home/container/*`
  - Comma/colon/semicolon-separated list or globs to build when `PLUGIN_DIR` is empty.
  - Examples: `/home/container/*` or `/home/container/pluginA,/home/container/pluginB`

- `OUT_DIR`
  - Default: empty (do not copy; leave artifacts in each `project/target/`)
  - Set to `/home/container/artifacts` to gather built jars/wars in one place (visible in Panel File Manager)

- `MAVEN_SETTINGS`
  - Path to a `settings.xml` inside container (e.g. `/home/container/settings.xml`) if you need private repos, auth, etc.

- `MAVEN_OPTS`
  - Default: `-Xmx512m`
  - Passed to Maven via env for heap / tuning

- `KEEP_ALIVE`
  - Default: `false`
  - Set `true` to keep the container running after builds (so panel shows server online). When true the entrypoint will tail -f /dev/null after builds.

- `PUID` / `PGID`
  - Optional numeric UID/GID used to create or rebind the runtime `container` user so artifact files are owned by the host's user. If image starts as root and `PUID` is set, the entrypoint will create/ensure the user and re-exec as that uid:gid.

---

## Startup / Usage examples

Pterodactyl startup command (pick one):

- One-shot build (container will exit when done):
  - `/entrypoint.sh`

- Build then keep server online (useful to inspect files via panel console):
  - Set `KEEP_ALIVE=true` in Egg variables, and use `/entrypoint.sh` as startup
  - Or: `sh -c "/entrypoint.sh; tail -f /dev/null"`

Examples for running locally (docker):

- Build a single mounted plugin, leaving artifacts in `target/`:
  - docker run --rm -v /host/pluginA:/home/container/pluginA my-image -e PLUGIN_DIR=pluginA

- Build and copy artifacts to a single folder:
  - docker run --rm -v /host/pluginA:/home/container/pluginA -v /host/out:/home/container/artifacts -e OUT_DIR=/home/container/artifacts -e PLUGIN_DIR=pluginA my-image

- Build all subfolders under `/home/container`:
  - docker run --rm -v /host/plugins:/home/container -e PLUGIN_PATHS=/home/container/* my-image

---

## File locations & panel visibility

- Default runtime `HOME` is `/home/container`. Panel File Manager shows this root for servers.
- If you want the File Manager to show a combined artifacts directory, set:
  - `OUT_DIR=/home/container/artifacts`
- Otherwise retrieve artifacts from each project's `target/` directory (e.g. `/home/container/pluginA/target/...`).

---

## Building the image

Example local build:
- docker build -t wafloos/maven-compile-pterodactyl-egg:latest .

If you change `CONTAINER_UID` / `CONTAINER_GID` build args:
- docker build --build-arg CONTAINER_UID=1001 --build-arg CONTAINER_GID=1001 -t my-image .

Push to your registry and update the Egg's image reference accordingly.

---

## Troubleshooting

- Exit code 126 / permission denied (common in Pterodactyl):
  - If `/entrypoint.sh` is not executable on the host or was uploaded via the Panel and lost exec-bit, run it with the shell: use `sh -c "/entrypoint.sh"` as startup. The image also runs via `sh` by default to avoid this problem.

- "bad substitution" or shell syntax errors:
  - Ensure the entrypoint uses POSIX /bin/ash syntax (the image is Alpine-based). Do not use Bash-only constructs (like `${!var}`).

- CRLF vs LF line endings:
  - Use LF (Unix) line endings for `entrypoint.sh`. CRLF can break the shebang and cause errors.

- File ownership:
  - If artifacts on the host show as root, set `PUID`/`PGID` to match the panel host user, or rebuild the image with matching `CONTAINER_UID`/`CONTAINER_GID`.

- No artifacts copied to `OUT_DIR`:
  - By default the script only copies `*.jar` and `*.war`. Maven may produce other outputs (e.g. shaded jars with different extensions); adjust script if needed or leave artifacts in `target/`.

---

## Notes & tips

- The entrypoint uses project-local `mvnw` if present. This helps consistent builds independent of the image's Maven version.
- For quick debugging: start the container with a shell and run the entrypoint manually with verbose logging from the console.
- Consider zipping `OUT_DIR` into a single archive for easy download via Panel if you produce multiple artifacts.

---

If you want I can:
- Add an automatic `artifacts.zip` creation step at the end of the build,
- Produce the exact Pterodactyl Egg JSON for service variables and startup command,
- Create a small patch (git diff) to apply these files into your repository.

Which would you like next?
