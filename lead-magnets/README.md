# Lead-magnet PDFs

The eight downloadable PDFs for the Klaviyo flow, specified in
`docs/lead-magnets.md`. `build.py` draws them with reportlab from the brand
tokens; the finished files are committed in `pdf/` so they can be uploaded or
copied to the website as they are.

    pip install reportlab fonttools pypdfium2
    python3 lead-magnets/build.py --preview

`fonts/` holds static instances of Fraunces cut from the app's variable font
(OFL) and Source Sans Pro (OFL) for body text. `--preview` renders every page
to `preview/` (ignored by git) for a visual check.
