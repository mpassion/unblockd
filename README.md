# Unblockd

> **Pull Requests are a state, not an event.**

Stop letting PRs rot in silence. Unblockd is a native macOS menu bar app that shows you *exactly* which Pull Requests need your attention - without the notification spam.

**The only PR monitor for Bitbucket, GitHub, and GitLab. All in one place.**

Native macOS PR monitor for Bitbucket, GitHub, and GitLab.  
No notification spam. No context switching. Just your PRs.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

---

## Why Unblockd?

**If you work across multiple repos and providers, you've felt this pain:**

- 🌐 **Provider chaos** - Switching between Bitbucket, GitHub, and GitLab in browser tabs
- 📊 **Scale problem** - 10+ repositories? You've lost track of what needs review
- 🔔 **Notification fatigue** - Email/Slack alerts for *every* PR event (comment, CI, approval)
- 🎯 **No unified view** - "Which PRs are blocking my team *right now*?"

**The traditional approach fails:**  
Open 3 browser tabs → Check each provider manually → Miss critical PRs anyway → Get interrupted by notification spam you've already muted.

**Unblockd solves this with a unified workspace:**  
All your PRs (Bitbucket + GitHub + GitLab) in one menu bar. Smart filtering shows only what needs *your* attention. Check once/hour on *your* terms, not when an email decides to ping you.

### Core Benefits

🔄 **One place for everything** - Bitbucket, GitHub, GitLab - stop context switching between providers

📈 **Scales with you** - From 3 repos to 50+ across multiple providers (Bitbucket for work + GitHub personal + GitLab clients)

🎯 **Smart filtering** - Only shows PRs that *you* can act on right now (assigned reviews, your PRs waiting, team blockers)

🤫 **Quiet by design** - Checks at configurable intervals (default: 30 min). You're in control, not your notifications

⏰ **Respects your schedule** - Set office hours (9-5). Badge goes dark after work. Guilt-free evenings

🔒 **Privacy-first** - 100% local. No tracking. No servers. Your data stays on your Mac

---

## Features

### Smart PR Classification

- **To Review** - PRs where you're assigned and haven't acted yet
- **Waiting** - Open PRs you've already reviewed, waiting for others or merge
- **Merged** - PRs merged while your assigned review was still pending
- **My PRs** - Your open PRs (including drafts)
- **Other / Team** - Everything else your team is working on
- **Snoozed** - PRs you've temporarily hidden

### Multi-Provider Support

- ✓ **Bitbucket Cloud** - Finally, a modern tool for Bitbucket
- ✓ **GitHub** - Public and private repositories
- ✓ **GitLab** - GitLab.com (cloud)

### Workflow Features

- ✓ Draft PR detection across all providers
- ✓ Repository discovery and monitoring
- ✓ Active days/hours scheduling
- ✓ Configurable refresh intervals (15-120 min)
- ✓ Launch at login
- ✓ Secure token storage in macOS Keychain
- ✓ Local rate-limit tracking per provider
- ✓ Battery-aware polling
- ✓ Lightweight memory footprint

---

## Installation

### Homebrew (Recommended)

```bash
brew install --cask mpassion/tap/unblockd
```

### Build from Source

```bash
git clone https://github.com/mpassion/unblockd.git
cd unblockd
swift build
```

---

## Getting Started

### 1. Connect Your Providers

Open **Preferences → Account** and add your credentials:

**Bitbucket Cloud**
- Create token: https://id.atlassian.com/manage-profile/security/api-tokens
- Required scopes: `read:user:bitbucket`, `read:repository:bitbucket`, `read:pullrequest:bitbucket`

**GitHub**
- Create token: https://github.com/settings/tokens
- Fine-grained PAT (recommended): Pull requests (Read-only), Metadata (Read-only)
- Classic PAT: `repo` or `public_repo`, `read:user`

**GitLab**
- Create token: https://gitlab.com/-/user_settings/personal_access_tokens
- Required scope: `read_api`
- Note: Requires at least Developer access to monitored projects

### 2. Add Repositories

Go to **Preferences → Discovery** to search and add repositories you want to monitor.

### 3. Configure Your Schedule

In **Preferences → Schedule**, set your:
- Active days (e.g., Mon-Fri)
- Active hours (e.g., 9:00-17:00)
- Refresh interval (default: 30 min, configurable 15-120 min)

That's it! Unblockd will now quietly monitor your PRs during work hours.

---

## Philosophy

### One Workspace, All Your PRs

The fundamental problem isn't just notification spam - it's **fragmentation**.

When your work spans Bitbucket, GitHub, and GitLab, you're forced to:
- Context switch between provider UIs
- Remember which repo lives where  
- Check multiple places to answer "what needs me?"
- Piece together a mental model from scattered sources

**Unblockd unifies this into a single view.** All providers. All repos. One place.

### State Over Events

Traditional tools treat PRs as a stream of events (comments, approvals, CI updates) and ping you for each one. This creates noise.

**Unblockd treats PRs as ongoing state** that you check when ready - like a dashboard, not an inbox.

- Check once/hour, not once/minute
- Passive awareness, not reactive alerts  
- You decide when to engage, not your notifications

**But here's the key:** This doesn't mean "no notifications ever." It means notifications should be **optional and smart** - not the default mode of operation.

### Built for Scale

Whether you monitor 3 repos or 50, across one provider or three, Unblockd gives you:

**Clarity** - Smart filters show only actionable PRs  
**Control** - Office hours, snooze, custom refresh intervals  
**Privacy** - 100% local processing, no server dependencies

---

## macOS Security Note

Early builds may be distributed without Apple notarization.

If macOS blocks app launch:

1. Right-click `Unblockd.app` → **Open**
2. Confirm **Open** in the dialog
3. If needed: `System Settings → Privacy & Security → Open Anyway`

**Note on Keychain Access:** macOS may prompt you to allow Unblockd to access your Keychain when you first connect a provider. This is normal - click **Allow** to securely store your API tokens. You may see this prompt multiple times (once per provider).

---

## Development

### Prerequisites

- macOS 13.0+
- Xcode 15.1+ (Swift 6.2 support)

### Testing

```bash
swift test
```

### Linting

The project uses [SwiftLint](https://github.com/realm/SwiftLint) via SwiftPM build tool plugin.

```bash
swift package plugin --allow-writing-to-package-directory swiftlint
```

### Project Structure

```
Sources/Unblockd/
├── Core/           # Configuration, logging, extensions
├── Features/       # UI (Dashboard, Settings)
├── Services/       # Provider clients, auth, rules engine
└── Resources/      # Assets
```

---

## Performance & Battery

Unblockd is designed to be lightweight and battery-friendly:

- Polling runs **only** during your configured active hours
- Conservative refresh intervals (default 30 min, configurable 15-120 min)
- Avatars cached in memory with bounded cache size
- Background refresh paused outside working window

---

## Contributing

This is a personal project, but thoughtful contributions are welcome:

- 🐛 **Bug reports** - Open an issue with reproduction steps
- 💡 **Feature requests** - Discuss in issues before implementing
- 🔧 **Pull requests** - Keep them focused and well-tested

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built with:
- [Swift](https://swift.org/) - Apple's modern programming language
- [SwiftUI](https://developer.apple.com/documentation/swiftui) - Declarative UI framework
- Love for developer productivity ❤️

---

**Made for developers who value their focus.**

[⭐ Star on GitHub](https://github.com/mpassion/unblockd) • [Download for macOS](#installation) • [Report Issue](https://github.com/mpassion/unblockd/issues)
