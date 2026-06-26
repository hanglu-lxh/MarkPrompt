# Reader Fixture: Long Outline

## 1. Overview

This fixture checks long-document scrolling and outline generation.

### 1.1 Background

MarkPrompt should keep selection and scroll position stable.

### 1.2 Constraints

The reader stays native and selectable.

## 2. Requirements

### 2.1 Reader Width

The body should remain centered.

### 2.2 Text Selection

Selection should not jump to the top.

### 2.3 Annotation Anchors

Anchors should survive rendering changes.

## 3. Evaluation

### 3.1 Tables

Wide tables need native layout.

### 3.2 Code

Code blocks need readable labels.

### 3.3 Footnotes

Footnotes need stable fallback.

## 4. Follow-up

### 4.1 Live Preview

Refresh must not break anchors.

### 4.2 Current Section

Section highlighting should be throttled.

### 4.3 Source Preview

Source preview should stay read-only.

