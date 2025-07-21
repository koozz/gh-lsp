# gh-lsp

The [GitHub CLI](https://cli.github.com) Language Server Protocol (LSP) client.

Why use different tools in your workflows than you use locally.
Language Servers integrate well in the local developer environments.
Time to enjoy this in your workflows too.

Using `gh lsp` leverages the LSP to get the same checks and feedback you would get in your IDE.

## Usage

Bring your own Language Server and instruct `gh lsp` how to start it up.
Configure what files to pass to the Language Server (`gh pr diff --name-only` comes a long way).
Use `timeout-minutes` to prevent your build from hanging if the LSP response takes too long.

```yaml
    - name: Checkout code
      uses: actions/checkout@v4 # preferred solution is to pin on a hash
    - name: Install the language server
      run: brew install zls
    - name: Install gh lsp GitHub commandline tool extension
      run: gh extensions install koozz/gh-lsp
    - name: Get changed .zig files
      run: echo "GH_LSP_FILES=\"$(gh pr diff --name-only | grep '.zig$')\"" >> $GITHUB_OUTPUT
    - name: Run gh lsp with configured LSP and passing files as arguments
      env:
        GH_LSP_SERVER: zls
      run: gh lsp ${GH_LSP_FILES}
      timeout-minutes: 3
```

Or if you prefer it one go (passing all files, not bothering whether they changed or not):

```yaml
    - uses: actions/checkout@v4 # preferred solution is to pin on a hash
    - run: |
        brew install zls
        gh extensions install koozz/gh-lsp
        GH_LSP_SERVER="zls" gh lsp src/*.zig
```

Silencing the output is possible by redirect standard error to `/dev/null`:

```yaml
    - uses: actions/checkout@v4 # preferred solution is to pin on a hash
    - run: |
        brew install zls
        gh extensions install koozz/gh-lsp
        GH_LSP_SERVER="zls" gh lsp src/*.zig 2>/dev/null
```

## Language servers
| `GH_LSP_SERVER`                | Diagnostics | Clean exit | Notes |
|--------------------------------|-------------|------------|-------|
| `bash-language-server start`   | No          | Yes        |       |
| `biome lsp-proxy`              | No          | No         |       |
| `helm_ls serve`                      | No          | No         | ❌    |
| `lua-language-server`                | Yes         | Yes        | ✅    |
| `marksman server`                    | No          | No         | ❌    |
| `ruff server`                        | No          | No         | ❌    |
| `vale-ls`                            | Yes         | No         | ❌    |
| `superhtml lsp`                      | Yes         | Yes        | ✅    |
| `typescript-language-server --stdio` | Yes         | Yes        | ✅    |
| `yaml-language-server --stdio`       | Yes         | Yes        | ✅ Including JSON Schema validation |
| `ziggy lsp`                          | No          | No         | ❌    |
| `zls`                                | Yes         | Yes        | ✅    |

## Development

Build the project with `zig build`.
Set the environment variable `GH_LSP_SERVER` and run `gh-lsp` with one or more files, for example:

```bash
# This should not yield any warnings or errors:
GH_LSP_SERVER="zls" zig run src/main.zig -- src/main.zig 2>/dev/null

# Test files with warnings and errors:
GH_LSP_SERVER="zls" zig run src/main.zig -- test/zls.zig 2>/dev/null

# Test file where the language server supplies JSON schema validation:
GH_LSP_SERVER="yaml-language-server --stdio" zig run src/main.zig -- test/yaml-language-server.yaml 2>/dev/null
```

## Contributions

All contributions are welcome.
Clearly describe issues including reproducible steps.
Describe on pull request what it fixes.
Make sure to describe and run tests.

Please double check if the issue is actually in `gh-lsp` and not in the used language server.

## License

[MIT](./LICENSE)
