# Install Marp for VS Code Extension

Since you're already in VS Code, here's how to install the Marp extension:

## Method 1: Extensions Panel (Easiest)

1. Click the **Extensions** icon in the sidebar (or press `Cmd+Shift+X`)
2. Search for: `Marp for VS Code`
3. Look for the extension by **Marp Team**
4. Click **Install**

## Method 2: Quick Open

1. Press `Cmd+P` to open Quick Open
2. Type: `ext install marp-team.marp-vscode`
3. Press Enter

## Method 3: VS Code Marketplace

Visit: https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode

Click "Install" and it will open in VS Code

## Verify Installation

Once installed:

1. Open `PRESENTATION.md`
2. You should see a **Marp preview icon** in the top right corner
3. Click it (or press `Cmd+K V`) to preview the slides

## After Installation

Try these features:

- **Preview Slides**: Click preview icon or `Cmd+K V`
- **Export**: Click "Export slide deck" in preview
- **Navigate**: Use arrow keys in preview mode
- **Toggle Theme**: Change theme in frontmatter and preview updates

## Troubleshooting

**Don't see preview icon?**
- Ensure file is named `PRESENTATION.md` (or has `.md` extension)
- Verify frontmatter starts with `---` and includes `marp: true`
- Reload VS Code window (`Cmd+Shift+P` → "Reload Window")

**Preview not rendering?**
- Check VS Code output panel for errors
- Ensure Marp extension is enabled
- Try restarting VS Code

## Already Installed?

If you already have the extension:
- Open `PRESENTATION.md`
- The preview should work automatically
- Try clicking the preview icon in the top right

---

**Note:** The Marp CLI is already installed in this project and ready to use!
Test it with: `./export-presentation.sh`
