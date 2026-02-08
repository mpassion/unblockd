# Contributing

Thanks for your interest in contributing to Unblockd.

## License

By contributing to Unblockd, you agree that:

- Your contributions will be licensed under MIT License (same as the project)
- You grant the Unblockd project perpetual rights to use your contributions in both free and commercial versions

This dual approach ensures:
- Community edition stays free and open (MIT)
- Development is sustainable (Pro version possible in future)
- Contributors are credited in both versions

By submitting a pull request, you accept these terms.

## Development Setup

1. Clone the repository.
2. Build the project:

```bash
swift build
```

3. Run tests:

```bash
swift test
```

4. Run lint (optional but recommended):

```bash
swift package plugin --allow-writing-to-package-directory swiftlint
```

## Pull Request Guidelines

- Keep changes focused and small.
- Include tests for behavior changes when possible.
- Update documentation when behavior/configuration changes.
- Use clear commit messages (Conventional Commits are welcome).

## Reporting Bugs

Please open an issue with:

- expected behavior,
- actual behavior,
- steps to reproduce,
- macOS + Xcode/Swift version.

## Scope

Unblockd is currently a read-only PR monitoring tool. Proposals outside current scope are still welcome, but may be scheduled for later milestones.
