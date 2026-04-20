# quicksetup

This is for when your Linux dev setup is broken and you want it back fast.

This is mainly for my own stack and habits: C++, Rust, Go, Python, and TypeScript on Ubuntu or Arch/Omarchy. If your setup is very different, this probably is not the right bootstrap as-is.

Contributions are open, but I do not review them quickly.

Works on:

- Ubuntu
- Arch / Omarchy

## Use This

Fresh machine, no local projects yet:

```bash
curl -fsSL https://raw.githubusercontent.com/sYanXO/quick_setup/main/bootstrap.sh | bash
```

Fresh machine, no questions:

```bash
curl -fsSL https://raw.githubusercontent.com/sYanXO/quick_setup/main/bootstrap.sh | bash -s -- --non-interactive
```

From inside your project:

```bash
curl -fsSL https://raw.githubusercontent.com/sYanXO/quick_setup/main/bootstrap.sh | bash -s -- --project "$PWD"
```

That version may ask a couple of questions in the terminal.

If you want no questions:

```bash
curl -fsSL https://raw.githubusercontent.com/sYanXO/quick_setup/main/bootstrap.sh | bash -s -- --project "$PWD" --non-interactive
```

If your project is somewhere else:

```bash
curl -fsSL https://raw.githubusercontent.com/sYanXO/quick_setup/main/bootstrap.sh | bash -s -- --project ~/code/my-project
```

## What It Sets Up

- C++: `gcc`, `clang`, `cmake`, `ninja`
- Rust: `rustup`, `cargo`, `rustfmt`, `clippy`
- Go
- Python + `pipx`
- Node.js + TypeScript
- `git`, `zsh`, `tmux`, `neovim`, `vscode`, `docker`

It also copies the repo's default config for shell, git, neovim, tmux, and VS Code.

## How It Decides What To Install

If you do not pass `--project`, it uses the default full setup from the repo config.

If you pass `--project`, it looks at that project folder.

If it finds files like these, it can set up only what you need:

- `Cargo.toml`
- `go.mod`
- `package.json`
- `pyproject.toml`
- `requirements.txt`
- `uv.lock`
- `CMakeLists.txt`
- `Makefile`

## Safe Check First

If you want to see what it would do without changing anything:

```bash
bash bootstrap.sh --project "$PWD" --dry-run
```

## If You Screw It Up Again

Run the same command again. The installer is meant to be rerun.

## Files

- [bootstrap.sh](/home/sreayan/work/quicksetup/bootstrap.sh)
- [config/default.env](/home/sreayan/work/quicksetup/config/default.env)
- [scripts/linux/install.sh](/home/sreayan/work/quicksetup/scripts/linux/install.sh)
