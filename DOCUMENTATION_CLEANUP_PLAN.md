# Documentation Cleanup Plan

## Overview
This document categorizes all files in the docs/archive folder based on their relevance to the current state of the CLARITY Loop Frontend, which now uses:
- AWS Amplify for authentication
- AWS Cognito for user management
- Backend hosted at https://clarity.novamindnyc.com
- SwiftUI + MVVM architecture

## Categorization Legend
- 🗑️ **DELETE**: Outdated, no longer relevant
- ✅ **KEEP**: Still relevant, core architectural patterns
- 🔄 **UPDATE**: Contains useful information but needs updating

## Document Analysis

### Authentication & Security Documents

| Document | Status | Reason |
|----------|---------|---------|
| ALB_FIX_INSTRUCTIONS.md | 🗑️ DELETE | Old ALB configuration, now handled by AWS infrastructure |
| AUTH_BUG_FINAL_DIAGNOSIS.md | 🗑️ DELETE | Firebase auth bugs, no longer relevant |
| AUTH_CRITICAL_AUDIT_REPORT.md | 🗑️ DELETE | Firebase audit, replaced by Amplify |
| AUTH_DEBUG_GUIDE.md | 🗑️ DELETE | Firebase debugging, not applicable |
| AUTH_FIX_SUMMARY.md | 🗑️ DELETE | Firebase fixes, obsolete |
| AUTH_FIX_VERIFICATION.md | 🗑️ DELETE | Firebase verification, not needed |
| AUTH_PRODUCTION_VERIFICATION.md | 🗑️ DELETE | Old production checks for Firebase |
| AUTH-SANITY-CHECK.md | 🗑️ DELETE | Firebase sanity checks |
| AUTHENTICATION_AUDIT_UPDATE.md | 🗑️ DELETE | Firebase audit updates |
| AUTHENTICATION_DEEP_AUDIT.md | 🗑️ DELETE | Firebase deep dive |
| AUTHENTICATION_FIX_PLAN.md | 🗑️ DELETE | Firebase fix plan, already implemented |
| IOS_AUTH_FLOW.md | 🗑️ DELETE | Firebase auth flow documentation |
| iOS_TOKEN_REFRESH_IMPLEMENTATION.md | 🗑️ DELETE | Manual token refresh, now handled by Amplify |
| iOS Authentication & Client-Side Security.md | 🔄 UPDATE | Security principles valid, but auth details outdated |
| SINGULARITY-AUTH-SOLUTION.md | 🔄 UPDATE | Documents transition to AWS, needs Amplify updates |

### Backend Integration Documents

| Document | Status | Reason |
|----------|---------|---------|
| BACKEND_AUTH_EXPECTATIONS.md | 🗑️ DELETE | Old Firebase expectations |
| BACKEND_DEBUG_PROMPT.md | 🗑️ DELETE | Outdated debugging for old backend |
| BACKEND_INTEGRATION_README.md | ✅ KEEP | Contract Adapter Pattern still valid |
| BACKEND-CENTRIC-AUTH-IMPLEMENTATION.md | 🗑️ DELETE | Old auth implementation |
| DEFINITIVE_AUTH_TIMELINE.md | 🗑️ DELETE | Historical timeline, not needed |
| END_TO_END_AUTH_FLOW.md | 🗑️ DELETE | Old Firebase flow |
| FRONTEND-BACKEND-SYNC.md | 🔄 UPDATE | Sync patterns valid, needs URL updates |

### API & Contract Documents

| Document | Status | Reason |
|----------|---------|---------|
| API_CONTRACT.md | 🗑️ DELETE | Old Modal backend contracts |
| API_contracts.md | 🗑️ DELETE | Duplicate of above |
| API_contracts.md.bak | 🗑️ DELETE | Backup file |
| JSON_ENCODING_FIX.md | 🗑️ DELETE | Old bug fix documentation |
| JSON_PAYLOAD_AUDIT_REPORT.md | 🗑️ DELETE | Old payload audit |

### Architecture & Implementation Documents

| Document | Status | Reason |
|----------|---------|---------|
| overal_blueprint.md | ✅ KEEP | Core MVVM architecture patterns |
| Technical Blueprint.md | ✅ KEEP | SwiftData, sync, error handling patterns |
| SwiftUI Architecture & State Management with SwiftData.md | ✅ KEEP | Core architectural guidance |
| IMPLEMENTATION_PLAN_Core_Architecture.md | ✅ KEEP | Core patterns still valid |
| IMPLEMENTATION_PLAN_Data_Models.md | ✅ KEEP | Data model design patterns |
| IMPLEMENTATION_PLAN_Networking_Layer.md | 🔄 UPDATE | Network patterns valid, needs auth updates |
| IMPLEMENTATION_PLAN_Authentication.md | 🗑️ DELETE | Firebase implementation plan |
| IMPLEMENTATION_PLAN_Project_Setup.md | 🔄 UPDATE | Setup process needs AWS updates |
| IMPLEMENTATION_PLAN_Security_and_HIPAA.md | ✅ KEEP | HIPAA compliance always relevant |

### Feature Implementation Documents

| Document | Status | Reason |
|----------|---------|---------|
| IMPLEMENTATION_PLAN_HealthKit_Integration.md | ✅ KEEP | HealthKit integration details |
| IMPLEMENTATION_PLAN_Main_Dashboard.md | ✅ KEEP | Dashboard UI patterns |
| IMPLEMENTATION_PLAN_PAT_and_Gemini_Insights.md | ✅ KEEP | PAT feature implementation |
| HealthKit Data Pipeline.md | ✅ KEEP | Data pipeline architecture |
| PAT and GEMINI.md | ✅ KEEP | Feature specifications |
| PULSE_DASHBOARD.md | ✅ KEEP | Dashboard specifications |

### Status & Fix Documents

| Document | Status | Reason |
|----------|---------|---------|
| ALL_TESTS_FIXED_SUMMARY.md | 🗑️ DELETE | Old test fixes |
| CRITICAL_BUGS_CHECKLIST.md | 🗑️ DELETE | Old bugs, likely resolved |
| DEPRECATION_DOSSIER.md | 🗑️ DELETE | Old deprecations |
| FINAL_AUTH_STATUS.md | 🗑️ DELETE | Firebase auth status |
| FRONTEND_FINDINGS_SUMMARY.md | 🗑️ DELETE | Old findings |
| FRONTEND_VS_BACKEND_TRUTH.md | 🗑️ DELETE | Old sync issues |
| PRODUCTION_READINESS_VERIFICATION.md | 🗑️ DELETE | Old production checks |
| PRODUCTION_READY_FINAL_STATUS.md | 🗑️ DELETE | Old status |
| TEST_FIX_SUMMARY.md | 🗑️ DELETE | Old test fixes |
| UI_RENDERING_ISSUES.md | 🗑️ DELETE | Old UI bugs |
| XC_TEST_LINT.md | 🗑️ DELETE | Old linting issues |

### Project Documentation

| Document | Status | Reason |
|----------|---------|---------|
| CLAUDE.md | 🗑️ DELETE | Old version, current one in root |
| FRONTEND_INTEGRATION_GUIDE.md | 🔄 UPDATE | Integration patterns valid, needs updates |
| FRONTEND-ACTION-PLAN.md | 🗑️ DELETE | Old action items |
| FRONTEND-AUTH-IMPLEMENTATION.md | 🗑️ DELETE | Firebase implementation |
| FRONTEND-AUTH-TASKS.md | 🗑️ DELETE | Old auth tasks |
| FRONTEND-TO-BACKEND-NOTES.md | 🗑️ DELETE | Old notes |
| FRONTEND-TO-BACKEND-NOTES-UPDATE.md | 🗑️ DELETE | Old notes update |

## Summary

### Documents to Keep (13 files)
- Architecture blueprints (3)
- Implementation plans for non-auth features (5)
- Feature specifications (3)
- Integration patterns (2)

### Documents to Update (5 files)
- iOS Authentication & Client-Side Security.md
- SINGULARITY-AUTH-SOLUTION.md
- FRONTEND-BACKEND-SYNC.md
- IMPLEMENTATION_PLAN_Networking_Layer.md
- IMPLEMENTATION_PLAN_Project_Setup.md
- FRONTEND_INTEGRATION_GUIDE.md

### Documents to Delete (41 files)
- All Firebase/old auth documents (23)
- Old bug fixes and status reports (11)
- Deprecated backend integration docs (7)

## Next Steps
1. Delete all files marked for deletion
2. Update files marked for updating with current AWS Amplify implementation
3. Create new canonical documentation structure
4. Write new docs for AWS Amplify auth flow
5. Document current frontend-backend integration