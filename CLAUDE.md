# Computing Workspace Context

This document provides context for Claude when started in the computing workspace.

## Workspace Overview

When Claude is started in this directory (`/Users/erik/code`), we're typically working on infrastructure and development tools projects. The `computing.code-workspace` file defines the related projects.

## Active Projects

Focus on these directories when working in this context:

- **dotfiles** - Personal macOS configuration and setup scripts
- **vscode** - VS Code and Cursor settings synchronization  
- **raycast** - Raycast scripts and workflows
- **homelab** - Home infrastructure, Ansible playbooks, and server configuration

## Other Directories

These directories exist but are typically NOT part of the computing workspace context:

- **letsrun** - Separate web application project
- **pequod** - Separate application project  
- **projects** - Various other unrelated projects
- **servers** - Legacy server configurations
- **tmp** - Temporary files and experiments

## Working Guidelines

1. When asked about "the workspace" or "the project", assume the user means one of the four active projects listed above
2. Use the workspace file (`computing.code-workspace`) to understand project relationships
3. Each project has its own CLAUDE.md with project-specific context
4. Don't explore unrelated directories unless specifically asked

## Quick Navigation

- To see workspace structure: `cat computing.code-workspace`
- To work on dotfiles: `cd dotfiles` (has its own CLAUDE.md)
- To work on VS Code sync: `cd vscode`
- To work on Raycast scripts: `cd raycast`
- To work on homelab/infrastructure: `cd homelab`