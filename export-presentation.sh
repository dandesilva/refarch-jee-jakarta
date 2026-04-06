#!/bin/bash

# Export Marp presentation to various formats
# Uses local Marp CLI installation (installed via npm)

echo "Exporting presentation..."

# Use npx to run local marp-cli
MARP="npx @marp-team/marp-cli"

# Export to PDF
echo "Creating PDF..."
$MARP PRESENTATION.md --pdf --allow-local-files -o presentation.pdf

# Export to HTML
echo "Creating HTML..."
$MARP PRESENTATION.md --html --allow-local-files -o presentation.html

# Export to PowerPoint
echo "Creating PowerPoint..."
$MARP PRESENTATION.md --pptx --allow-local-files -o presentation.pptx

echo "Done! Generated:"
echo "  - presentation.pdf"
echo "  - presentation.html"
echo "  - presentation.pptx"
