# MuseDesk for Windows

[![Windows build](https://github.com/Azimn/museDesk/actions/workflows/windows-build.yml/badge.svg)](https://github.com/Azimn/museDesk/actions/workflows/windows-build.yml)

MuseDesk for Windows is an unofficial Windows port of [atameric/musedesk](https://github.com/atameric/musedesk), a desktop client for Meta's **Muse Code** CLI.

The important distinction is that this project is not a replacement for Meta's Muse phone app. Meta uses the Muse name for more than one surface. The personal Muse experience on iOS, Android, and the web connects to a dedicated Linux computer in Meta's cloud. Muse Code is Meta's coding agent for the terminal and CI. MuseDesk sits on top of **Muse Code installed on your own Windows PC** and gives that local coding agent a conventional desktop interface.

That makes MuseDesk useful when the thing you want Muse to work on is already on your computer: a Git repository, a Unity or Godot project, a Python experiment, a local website, a collection of scripts, or another development workspace that you do not want to move into a separate cloud machine just to work with it.

This repository is a Windows-port overlay rather than an unrelated rewrite. It tracks upstream MuseDesk at commit `008f1396f99e1fa64cda0fe4ea2351b391fb6313`, preserves the upstream architecture and security model, and changes only the areas needed for native Windows discovery, paths, process launching, keyboard conventions, packaging, and validation.

Upstream project: https://github.com/atameric/musedesk

Official Muse Code documentation: https://dev.meta.ai/docs/muse-code

Meta's description of the personal Muse cloud architecture: https://research.meta.ai/blog/security-and-safety-for-ai-agents-our-approach-with-muse

## What MuseDesk actually does

MuseDesk is an Electron and React desktop application. It does not contain Muse Spark, it does not replace Muse Code, and it does not bundle a hidden API client.

When MuseDesk starts, it looks for the official `muse` installation on the same Windows machine. It launches `muse serve` as a local child process and communicates with it over stdin and stdout using Muse's session protocol. The model calls, authentication, tools, approvals, sandboxing, session storage, and coding behavior still belong to the official Muse Code installation.

MuseDesk supplies the desktop experience around that local agent. It provides project and chat navigation, streamed responses, reasoning and tool activity, approval dialogs, image attachments, model and reasoning controls, token and context information, session recovery, task views, and a read-only Git changes inspector.

MuseDesk does not store your Muse credentials. Authentication remains in the official Muse Code installation. The client also retains upstream's protocol fingerprint gate. If Meta changes the Muse session protocol in a way this build has not been verified against, MuseDesk refuses to drive that unknown protocol instead of silently guessing.

## Why use this instead of only using Muse on a phone?

The phone and web Muse clients are useful when you want the personal Muse agent and its cloud computer, browser, connectors, and remote availability. MuseDesk solves a different problem.

| Scenario | MuseDesk on Windows | Muse phone or web client |
| --- | --- | --- |
| Work directly inside `C:\Projects\MyGame` | Yes. Muse Code runs locally against that workspace. | The personal Muse client connects to its cloud VM rather than directly mounting your Windows drive. |
| Inspect the current local Git working tree | Built-in read-only Changes panel for status and diffs. | The cloud Muse environment has its own filesystem and Git state. |
| Run the tests, compiler, CLI tools, or scripts already installed on your PC | Yes, through the local Muse Code tool environment and its approval and sandbox rules. | Commands run in the personal Muse cloud computer, not on your Windows machine. |
| Reuse Muse Code terminal sessions in a GUI | Yes. MuseDesk talks to the same local Muse Code session system. | This is a different product surface from the Muse Code terminal workflow. |
| Keep several local coding projects visible at once | Project sidebar groups sessions by local working folder. | The phone client is optimized around the personal Muse experience rather than a local-repository desktop cockpit. |
| Use email, personal connectors, remote browser automation, or Muse from anywhere | Not the purpose of MuseDesk. | This is where the personal Muse client is stronger. |
| Work comfortably for hours with diffs, approvals, tasks, screenshots, and multiple project sessions | This is the main use case. | Possible for some tasks, but the interaction model is designed around a mobile or web client connected to the cloud VM. |

The simplest mental model is: **Muse on your phone gives you access to Muse's computer. MuseDesk gives Muse Code a desktop interface for working on your computer.**

## Concrete examples

Suppose you have a Godot game under `C:\Projects\FrankensteinVillage`. In MuseDesk you can create a project for that folder and ask, "The inventory UI is losing focus after I close a dialogue. Find the cause, fix it, and run the relevant tests." The local Muse Code agent can inspect that exact checkout, edit the source, run commands in the local workspace, and report its work. You can then open the Changes panel and inspect the resulting Git diff without leaving MuseDesk.

Suppose you are developing an AI experiment with Python scripts, local data fixtures, and a test harness. You can keep one MuseDesk chat working on an experiment implementation while another session reviews a different part of the same repository. The sidebar keeps those sessions associated with their actual local folder, and the Overview and Tasks interfaces make long-running work easier to monitor than a single terminal window.

Suppose a local build looks wrong. You can attach a screenshot to a MuseDesk message and ask Muse Code to correlate what is visible with the source in the active project. That is particularly useful for games and UI work because the screenshot and the code repository can be discussed in the same session while Muse operates against the local files.

Suppose you normally use the Muse Code CLI but prefer not to live in a terminal. MuseDesk keeps the underlying Muse Code architecture rather than building a second agent. You get a desktop transcript, project navigation, approval dialogs, tool activity, context information, and Git inspection while retaining the same local Muse Code installation.

## Quick user guide

### Install Muse Code first

Open PowerShell and install the official Windows Muse Code CLI:

```powershell
irm https://dev.meta.ai/install.ps1 | iex
```

Then start Muse Code once and sign in:

```powershell
muse
```

You can verify the installation with:

```powershell
muse --version
```

MuseDesk does not bundle the CLI, your Meta credentials, or a Muse subscription.

### Get a Windows build

This repository contains a GitHub Actions Windows build. Open the repository's **Actions** tab, choose **Windows build**, and use **Run workflow**. The workflow builds both x64 Windows and Windows on ARM packages on real Windows runners.

For most Intel and AMD Windows PCs, download the `MuseDesk-windows-x64` artifact. For Windows on ARM devices, download `MuseDesk-windows-arm64`.

The artifact contains a portable ZIP and a SHA-256 checksum. Extract the ZIP to a normal folder and launch `MuseDesk.exe`.

These builds are currently unsigned. Windows may therefore show an unfamiliar-publisher warning. Code signing requires a publisher certificate and release infrastructure, so it is deliberately separate from the portability work in this repository.

### Start your first project

Launch MuseDesk after Muse Code is installed. Use **New Project** to choose a local working folder, such as:

```text
C:\Projects\MyGame
```

Create a chat in that project and describe the task normally. The session is created with that folder as its workspace root.

A useful first prompt is:

```text
Inspect this project, explain its structure, identify the normal build and test commands, and do not change anything yet.
```

That establishes what Muse can see before you ask it to modify the project.

### Review what Muse is doing

MuseDesk shows reasoning and tool activity in expandable groups. If Muse Code requests approval for an operation, MuseDesk surfaces the approval in the desktop UI.

The **Tasks** panel shows the agent's current plan when the protocol provides one. The **Changes** panel reads local Git status and diffs so you can inspect modifications against HEAD. Its Git integration is intentionally read-only. MuseDesk does not stage, commit, reset, or discard your files.

The context indicator shows how full the current model context is, while the token display reports session usage supplied by the host.

### Attach screenshots

Use the image button, paste an image, or drop supported images into the composer. MuseDesk accepts PNG, JPEG, GIF, and WebP images subject to the limits enforced by the client.

For game and UI development, a useful pattern is:

```text
This screenshot is from the current build of this project. Find the code responsible for the broken layout, explain the cause, fix it, and show me which files changed.
```

### Use the command palette

Press **Ctrl+K** on Windows to open MuseDesk's command palette. It can jump between sessions and expose common project and host controls without requiring terminal commands.

### Full access

Muse Code normally operates with its sandbox and approval model. MuseDesk exposes a **Full access** option that restarts the local `muse serve` host with its sandbox disabled.

Use this only for workspaces you trust. The setting increases what the coding agent can do on your machine. It is not needed for ordinary use, and enabling it does not bypass MuseDesk's protocol fingerprint check.

## Building the Windows port yourself

This repository contains a self-applying port rather than a second full copy of every upstream source file. That keeps the relationship to upstream explicit and makes it easier to review exactly what Windows changes.

From PowerShell:

```powershell
git clone https://github.com/Azimn/museDesk.git
cd museDesk
Set-ExecutionPolicy -Scope Process Bypass
.\apply-windows-port.ps1 -Arch x64
```

The script clones the pinned upstream MuseDesk source into `musedesk-windows`, applies this repository's overlay and targeted Windows edits, installs dependencies, runs TypeScript checks, ESLint, and unit tests, packages Electron for Windows, verifies the generated executable has a Windows PE signature, and writes a portable ZIP plus SHA-256 checksum under the generated source tree's `dist` folder.

For Windows on ARM:

```powershell
.\apply-windows-port.ps1 -Arch arm64
```

To apply the port to an existing clean checkout of the pinned upstream revision:

```powershell
.\apply-windows-port.ps1 -Target C:\path\to\musedesk -Arch x64
```

To apply the source changes without packaging:

```powershell
.\apply-windows-port.ps1 -NoBuild
```

The script refuses a dirty checkout or a different upstream revision unless `-Force` is supplied. That is intentional. A changed upstream tree should be reviewed rather than silently patched with assumptions from an older version.

## What the Windows port changes

The original beta.5 application code is already largely cross-platform. Most of the Windows work is around the operating-system boundary.

Windows discovery recognizes `muse.exe`, `muse.cmd`, and `muse.bat`. It also understands Meta's versioned Windows launcher layout and, when possible, resolves the command wrapper to the sibling `muse-bin-<version>.exe` executable.

Executable detection no longer assumes POSIX permission bits on Windows. Process startup can safely fall back to Windows command wrappers when a direct executable is not available. Project names and folder normalization understand both `/` and `\` separators. The desktop shortcut label uses `Ctrl+K` rather than the macOS Command symbol.

The packaging script creates a Windows icon from the upstream artwork, runs the verification gates, packages Electron for `win32`, confirms that the resulting `MuseDesk.exe` has a PE header, and produces portable x64 or ARM64 ZIPs.

The port also replaces upstream's Node 26 extraction workaround with a platform-aware version. Windows uses PowerShell's `Expand-Archive`; macOS and Linux retain the system `unzip` path.

## Security model

This port deliberately preserves upstream's security posture.

MuseDesk starts the official local Muse Code CLI instead of embedding a replacement binary. It stores no Muse API key or account password. The renderer uses Electron's preload bridge rather than direct Node access. Git inspection is read-only. Muse Code's approval and sandbox behavior remains host-controlled.

Most importantly, MuseDesk verifies the MSP protocol fingerprint reported by `muse serve`. The current upstream beta.5 source was verified against Muse Code 1.4.1. If a later Muse Code build changes the protocol fingerprint, MuseDesk reports a mismatch and stops rather than driving an unverified protocol.

Do not "fix" a fingerprint mismatch by disabling the check. The correct maintenance path is to regenerate the schema from the new Muse Code version, review the protocol changes, update the pinned files, and rerun the test suite.

## Current status

This repository targets Windows x64 and Windows ARM64. The Windows package is portable and unsigned. MSI or MSIX installation, code signing, automatic updates, and a formal release channel are not part of the initial port.

The build workflow runs on GitHub's `windows-latest` runners so Windows-specific packaging is validated on Windows rather than inferred from a macOS or Linux build.

MuseDesk remains an unofficial community project. It is not affiliated with or endorsed by Meta.

## Upstream and license

MuseDesk is Copyright (c) 2026 Ata and is distributed under the MIT License. This Windows port retains the upstream license and attribution.

The port is intentionally structured as a small overlay on the original project. If upstream adds official Windows support, those changes should take precedence and this repository can either converge on upstream or become unnecessary.
