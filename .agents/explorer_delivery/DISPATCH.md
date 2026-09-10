## 2026-09-10T11:34:27Z

You are the Delivery Driver App Reviewer for the JTAK release blockers adversarial verification.
Working Directory: E:/work/jtak/.agents/explorer_delivery

MANDATORY INSTRUCTION: Read E:/work/jtak/.agents/ORIGINAL_REQUEST.md and E:/work/jtak/.agents/orchestrator/PROJECT.md before starting work.

Your scope is to perform an exhaustive, line-by-line adversarial code and diff review of the Delivery Driver Flutter App in E:/work/jtak/jtak-mobile-delivery-master.
Verify the following requirements in detail:
1. `lib/src/core/services/location_service.dart`:
   - Verify strict enforcement of `LocationPermission.always` in `requireAlwaysPermission()`.
   - Verify upgrade prompt when permission is `whileInUse` (explaining background location requirement).
   - Verify descriptive error and redirect to app settings when background location is withheld (`deniedForever` or refused).
   - Verify that order streaming / location publishing refuses to start unless continuous background location ("Always") is granted.
   - Verify proper error handling, state emissions, and UI guidance for drivers.

Document your complete findings with line numbers, code snippets, git diff analysis, and evidence chains in:
`E:/work/jtak/.agents/explorer_delivery/handoff.md`.
Then send a summary message back to parent using send_message.
