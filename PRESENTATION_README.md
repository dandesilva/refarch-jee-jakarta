# Presentation Files

This directory contains presentation materials for the Jakarta EE migration project.

## Files

- **PRESENTATION_OUTLINE.md** - Detailed outline with speaker notes (45-60 min talk)
- **PRESENTATION.md** - Marp-based slide deck (ready to present)
- **export-presentation.sh** - Script to export to PDF/HTML/PowerPoint

## Quick Start

### View Slides in VS Code

1. Install **Marp for VS Code** extension:
   ```
   code --install-extension marp-team.marp-vscode
   ```

2. Open `PRESENTATION.md`

3. Click the preview icon or press `Cmd+K V`

4. Use the Marp toolbar to:
   - Navigate slides
   - Toggle presenter mode
   - Export to PDF/HTML/PPTX

### Export to Other Formats

**Install Marp CLI:**
```bash
npm install -g @marp-team/marp-cli
```

**Run export script:**
```bash
./export-presentation.sh
```

This creates:
- `presentation.pdf` - For printing or sharing
- `presentation.html` - For web viewing
- `presentation.pptx` - For PowerPoint/Google Slides

**Manual export:**
```bash
# PDF
marp PRESENTATION.md --pdf -o presentation.pdf

# HTML (standalone)
marp PRESENTATION.md --html -o presentation.html

# PowerPoint
marp PRESENTATION.md --pptx -o presentation.pptx
```

## Presentation Structure

**Total Slides:** ~60 slides
**Duration:** 45-60 minutes

### Sections:
1. **Introduction** (5 min) - The challenge and application overview
2. **Migration Journey** (30-35 min) - Six phases of migration
3. **Challenges** (8 min) - Problems encountered and solutions
4. **Results** (5 min) - Metrics and business value
5. **Lessons Learned** (5 min) - Technical and process insights
6. **Next Steps** (3 min) - Future roadmap
7. **Conclusion** (2 min) - Key takeaways
8. **Q&A** (5-10 min) - Resources and questions

## Customization

### Change Theme

Edit frontmatter in `PRESENTATION.md`:
```yaml
---
marp: true
theme: default  # or: gaia, uncover
---
```

### Adjust Font Size

```yaml
style: |
  section {
    font-size: 28px;  # Adjust as needed
  }
```

### Add Your Branding

Replace header/footer:
```yaml
header: 'Your Company Name'
footer: 'Your Event | Date'
```

## Tips for Presenting

1. **Practice timing** - ~1 minute per slide average
2. **Use presenter notes** - Reference PRESENTATION_OUTLINE.md for details
3. **Live demos** - Consider showing actual endpoints in Phase 6
4. **Code examples** - Syntax highlighting included automatically
5. **Q&A prep** - Review "Questions to Anticipate" section

## Slide Navigation

- **Arrow keys** - Next/previous slide
- **Page Up/Down** - Fast navigation
- **Home/End** - First/last slide
- **Click** - Advance slide
- **F** - Full screen (in browser)
- **P** - Presenter mode (shows notes)

## Printing

For best results when printing from PDF:
- Use landscape orientation
- Print one slide per page
- Enable "Fit to page"

## Converting to Google Slides

1. Export to PowerPoint: `marp PRESENTATION.md --pptx -o presentation.pptx`
2. Upload to Google Drive
3. Open with Google Slides
4. Make any final adjustments

## Live Presentation Mode

For best experience presenting:

**In VS Code:**
- Use Marp extension preview
- Navigate with arrow keys
- Full screen mode

**In Browser (HTML export):**
- Press `F` for fullscreen
- Press `P` for presenter mode (shows upcoming slide)
- Share your screen in video calls

## Additional Resources

- **Marp Documentation:** https://marp.app/
- **Marp CLI:** https://github.com/marp-team/marp-cli
- **VS Code Extension:** https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode

## Troubleshooting

**Slides not rendering?**
- Ensure Marp extension is installed in VS Code
- Verify file starts with Marp frontmatter (`---`)

**Export fails?**
- Install Marp CLI: `npm install -g @marp-team/marp-cli`
- Check Node.js is installed: `node --version`

**Code blocks not highlighting?**
- Marp uses highlight.js automatically
- Ensure language is specified: ```java

**Images not showing?**
- Use relative paths: `![](./images/diagram.png)`
- Or use `--allow-local-files` flag when exporting

## License

This presentation is part of the refarch-jee-jakarta project.
See LICENSE file in the root directory.
