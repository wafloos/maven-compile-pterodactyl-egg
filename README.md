# Maven Compile Pterodactyl Egg — Quick Instructions

Basic local image build and Egg configuration.

Local image
- Clone the repo:
```bash
git clone https://github.com/wafloos/maven-compile-pterodactyl-egg.git
```

- Build the Docker image:
```bash
docker build -t pterodactyl-maven:latest ./maven-compile-pterodactyl-egg
```

Use this image in your Pterodactyl Egg configuration (set the image to `pterodactyl-maven:latest` or your registry path).

Server control
- Stop command: ^C

Start config
```json
{
  "done": [
    "BUILD SUCCESS"
  ]
}
```

Startup command
```
mvn clean package
```

Custom variable creation on the Egg
- Name: Plugin Directory(ies)
- Environment Variable: PLUGIN_DIR
- Permissions: Users can View, Users can access [Ease of Access to change the directories]
- Input Rules: required|string

Notes
- PLUGIN_DIR should point to the directory (relative to `/home/container` or absolute) containing the Maven project (pom.xml).
- If you need multiple directories or globs, configure the Egg to pass appropriate values (e.g., use comma/colon/semicolon separated lists) to `PLUGIN_DIR` or adjust the entrypoint as needed.
