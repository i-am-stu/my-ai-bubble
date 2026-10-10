# Security and privacy

My AI Bubble opens installed Mac apps selected by the user. It does not assess whether those apps are trustworthy. Only add apps you trust.

## Data and permissions

- No app network requests, analytics, account system, chat reading or notification monitoring.
- Selected app paths, their order and the bubble position are stored in local macOS preferences (`local.stucollett.myai`). They are not encrypted; another process running as your user may read or change them.
- When usage tracking is enabled (the default), daily foreground seconds and switch counts for added apps are stored in local preferences for up to 90 days. The usage window can disable tracking or clear the data. System idle duration is queried without recording input contents.
- App icons are read from installed applications. Bubble artwork is bundled.
- No Accessibility, Screen Recording, camera, microphone, administrator or Full Disk Access permission is requested.
- The app is not App Sandbox isolated. It runs with the ordinary permissions of the logged-in user.
- Apps open through macOS Launch Services. No shell commands, downloaded code, updater or elevated helper are used by the running app.

Deleting the app does not automatically delete its local preferences. There is no server-side account or data to delete.

## Downloads

Use releases from https://github.com/i-am-stu/my-ai-bubble/releases. SHA-256 checksums help check file integrity; they do not independently establish the publisher’s identity. Current builds use ad-hoc signing, not Apple Developer ID signing or notarisation. Do not disable macOS security protections to install them.

## Reporting a problem

For a suspected security issue, use GitHub’s **Security → Report a vulnerability** on this repository when available. Do not include credentials or personal data in public issues. Ordinary bugs can be reported through Issues. This is a small personal project with no guaranteed response time.

## Scope

The latest release is the maintained version. Review and tests reduce risk but do not prove the absence of vulnerabilities. No independent penetration test or legal clearance has been performed. See [the release review](docs/REVIEW.md).
