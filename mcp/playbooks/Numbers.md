# Numbers Playbook

Bundle id: `com.apple.iWork.Numbers`.

## Editing cells

- **Append / edit**: one click on the cell to focus.
- **Replace**: three clicks on the cell (`alma cu click <ref> --clicks=3`).

For value entry, dispatch the click and the keyboard write in parallel:
```bash
alma cu click <ref> --clicks=3        # select + clear
alma cu type_text "42" --pid <pid>    # enter the new value
```

## Batch entry

One row at a time is fine — use `\t` delimiters to jump between columns in
a single `type_text` call. **Don't** pack multiple rows into one call;
Numbers will reject it. Same for multiple formulas — one per call.

## Notes

- Focused cells sometimes show a "text entry area" with extra formatting
  (e.g. Markdown-bold table headers). Ignore it.
- Values save immediately — no need to press Return unless you're done
  editing the whole spreadsheet.
- Checkbox cells: type `0` or `1`.
