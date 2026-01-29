# Session Diary: 2026-01-15

**Project**: /Users/dev/myapp
**Branch**: feature/auth-system
**Session**: 2

## What Happened
Implemented JWT-based authentication with refresh tokens. Refactored the middleware stack to support route-level auth guards. Debugged a CORS issue that was blocking the login flow from the frontend.

## Work Done
- Created `auth.middleware.ts` with JWT verification
- Added refresh token rotation in `auth.service.ts`
- Set up route guards for protected API endpoints
- Fixed CORS configuration to allow credentials

## Decisions Made
- Chose short-lived access tokens (15min) + long-lived refresh tokens (7d) over session-based auth for better scalability
- Stored refresh tokens in httpOnly cookies rather than localStorage for XSS protection

## Preferences Observed
- User prefers explicit error types over generic error messages
- User writes tests alongside implementation, not after
- User uses barrel exports for module organization

## Challenges & Solutions
- CORS was rejecting preflight requests because `credentials: true` requires explicit origin (not `*`). Fixed by setting origin to the frontend URL from env config.

## Patterns
- User follows controller → service → repository layering consistently
- Error handling uses custom exception classes that map to HTTP status codes
