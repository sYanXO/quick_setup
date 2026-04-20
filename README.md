# quicksetup

Opinionated one-line workstation bootstrap for:

- Ubuntu
- Arch / Omarchy

It installs a current stable development stack for:

- C++ (`gcc`, `clang`, `cmake`, `ninja`)
- Rust (`rustup`, `cargo`, `rustfmt`, `clippy`)
- Go
- Python + `pipx`
- Node.js + TypeScript

It also applies repo-managed shell/editor defaults for:

- `git`
- `zsh`
- `tmux`
- `neovim`
- `vscode`
- `docker`

## Bootstrap

Remote one-liner for the current project:

```bash
curl -fsSL https://example.com/quicksetup/bootstrap.sh | bash -s -- --project "$PWD"
```

If you want a couple of terminal prompts, omit `--non-interactive`.

Examples:

```bash
curl -fsSL https://example.com/quicksetup/bootstrap.sh | bash -s -- --project ~/code/myapp
bash bootstrap.sh --project "$PWD" --dry-run
```

For local development:

```bash
bash bootstrap.sh --project "$PWD" --dry-run
```

## Config

Defaults live in [config/default.env](/home/sreayan/work/quicksetup/config/default.env).

Supported flags:

- `--project <path>`
- `--config <path>`
- `--only <group1,group2>`
- `--skip <component1,component2>`
- `--non-interactive`
- `--dry-run`

Component groups:

- `basics`
- `cpp`
- `rust`
- `go`
- `python`
- `node`
- `editors`
- `shell`
- `docker`
- `dotfiles`

## Layout

- [bootstrap.sh](/home/sreayan/work/quicksetup/bootstrap.sh)
- [scripts/linux/install.sh](/home/sreayan/work/quicksetup/scripts/linux/install.sh)

The installer inspects the project path for `Cargo.toml`, `go.mod`, `package.json`, `pyproject.toml`, `requirements.txt`, `uv.lock`, `CMakeLists.txt`, `Makefile`, and common C++ source files. In interactive mode it can narrow installation to the detected language stacks plus common tooling.
