# Design Principles

## Product design goals
- Calm, modern, premium-feeling mobile experience
- Strong hierarchy and spacing
- Clear, trust-building screens
- No clutter
- Reusable patterns

## UX principles
- Optimize for the main job to be done
- Make the next action obvious
- Keep booking flows step-by-step
- Use progressive disclosure
- Reduce cognitive load

## Visual principles
- Consistent design tokens
- Reusable components
- Every modal bottom sheet goes through `showAppSheet` (`lib/src/features/shared/app_sheet.dart`), never `showModalBottomSheet` directly: it lifts the sheet above the keyboard and caps its height. A sheet with a text field keeps its handle and header outside a `Flexible(SingleChildScrollView(...))`. A fixed footer (submit, save) lives in the body as `Column[Expanded(scroll view), footer]`, never in `bottomNavigationBar`, which the keyboard covers. Enforced by `test/architecture/sheets_go_through_app_sheet_test.dart`.
- Good loading, empty, and error states
- Avoid generic scaffold look
- Keep visual quality high enough for launch confidence

## Screen quality checklist
- Does the screen have a single dominant action?
- Is the hierarchy obvious in 3 seconds?
- Are empty and error states useful?
- Is the mobile layout clean?
- Is spacing consistent with the system?
