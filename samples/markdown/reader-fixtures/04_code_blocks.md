# Reader Fixture: Code Blocks

## Swift

```swift
struct ReviewNote {
    let id: String
    var comment: String
}

func included(_ note: ReviewNote) -> Bool {
    return !note.comment.isEmpty
}
```

## JSON

```json
{
  "version": "1",
  "sourceHash": "abc123",
  "notes": []
}
```

## Shell

```bash
swift build
swift test
```

## Indented Code

    MARKPROMPT_REVIEW=1
    swift test --filter MarkdownParserTests

    if [[ -n "$MARKPROMPT_REVIEW" ]]; then
        echo "native indented code"
    fi

## YAML

```yaml
title: "Reader settings"
owner: local
enabled: true
width: 760
```

## Diff

```diff
@@ reader table block @@
- render raw pipe table
+ render native TextKit table
  context unchanged
```
