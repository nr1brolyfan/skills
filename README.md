# Personal Agent Skills

Custom, version-controlled skills for OpenCode and other agents that support the
`SKILL.md` format.

## Structure

Each skill lives in its own top-level directory:

```text
.
├── cloudflare-system-design/
│   ├── SKILL.md
│   └── references/
├── docs/
│   └── creating-skills.md
└── scripts/
    └── install.sh
```

## Installation

Install all skills globally for OpenCode:

```bash
./scripts/install.sh --global
```

Install selected skills globally:

```bash
./scripts/install.sh --global cloudflare-system-design
```

Install all skills in a specific project:

```bash
./scripts/install.sh --project /path/to/project
```

Skills are copied by default, and existing installations are not overwritten.
Use `--force` to update them:

```bash
./scripts/install.sh --global --force cloudflare-system-design
```

While developing a skill, you can create a symbolic link instead of a copy:

```bash
./scripts/install.sh --global --link cloudflare-system-design
```

Restart OpenCode after installation. Configuration and skills are not reloaded
during an active session.

## Adding a Skill

1. Create a directory, such as `database-design/`.
2. Add a `SKILL.md` file to it.
3. Set `name` to match the directory name exactly.
4. Use `description` to explain what the skill does and when it should run.
5. Install it locally and test it with a realistic task.

For complete guidelines and a template, see
[`docs/creating-skills.md`](docs/creating-skills.md).

## Publishing

You can publish the repository on GitHub like any other Git project. After
creating an empty GitHub repository, run:

```bash
git remote add origin git@github.com:OWNER/REPOSITORY.git
git branch -M main
git push -u origin main
```

Users can clone the repository and run the installer. The directory layout is
also compatible with the Agent Skills ecosystem, allowing published skills to
be installed with tools that support repositories containing `SKILL.md` files.
