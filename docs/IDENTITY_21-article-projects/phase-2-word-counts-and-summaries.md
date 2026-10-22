# Article Projects — Phase 2: Word Counts and Summaries

## Status

Planned. Phase 1 database/model work is a prerequisite.

## Objective

Expose computed Article Project summaries while keeping assignment target word count independent from Article content.

## Required behavior

- `target_word_count` remains user-editable Article Project data.
- `actual_word_count` is read-only and computed from the linked Article body.
- `word_count_remaining` is `target_word_count - actual_word_count`.
- No linked Article returns `actual_word_count: null`.
- A linked Article with blank content returns `actual_word_count: 0`.
- No target returns `word_count_remaining: null`.
- Negative remaining values are valid and indicate an over-target draft.

## Counting rule

Create a shared service unless a reliable existing implementation is discovered during coding. It must:

1. Read `Article#body`.
2. Remove `script` and `style` contents.
3. Preserve boundaries between HTML blocks, including `<p>Hello</p><p>world</p>`.
4. Decode entities.
5. Normalize whitespace.
6. Count normalized whitespace-separated tokens.

Document the final implementation and use it consistently in Article Project detail serialization.

## Summary behavior

Provide vintage counts for `total`, `requested`, `received`, `selected`, and `tasted`. Counts overlap and must not be summed.

`overdue` is true only when `deadline < Date.current` and `project_status` is neither `published` nor `cancelled`. A deadline today is not overdue; `on_hold` remains overdue when past due.

## Query strategy

- Detail endpoints may use loaded `project_vintages` joins to calculate counts.
- Paginated list endpoints must use grouped aggregation and must not load full Article bodies unless displaying actual word count.
- List serializers should follow the existing lean-list pattern in `app/serializers/article_list_serializer.rb`.

## Tests required

Cover HTML block boundaries, entities, scripts/styles, blank content, link/unlink/replacement, independent target preservation, overlapping vintage counts, and deadline edge cases using the configured application date.

## Exit gate

Changing Article body changes the computed Article Project actual count without modifying the Article Project target or requiring an Article Project write.