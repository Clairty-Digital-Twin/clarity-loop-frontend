# CLARITY Loop Frontend Documentation

## Overview
This documentation provides comprehensive guidance for the CLARITY Loop iOS application, a SwiftUI-based health tracking app integrated with AWS services.

## Current State
- **Authentication**: AWS Amplify + Cognito
- **Backend**: https://clarity.novamindnyc.com (AWS hosted)
- **Architecture**: SwiftUI + MVVM + SwiftData
- **Platform**: iOS 17.0+

## Documentation Structure

### 📐 [Architecture](./architecture/)
Core architectural patterns and design decisions
- [Core Architecture](./architecture/CORE_ARCHITECTURE.md) - MVVM, Repository Pattern, DI
- [SwiftUI & State Management](./architecture/SWIFTUI_STATE_MANAGEMENT.md)
- [Data Models & SwiftData](./architecture/DATA_MODELS.md)
- [Networking Layer](./architecture/NETWORKING_LAYER.md)

### 🔐 [Security](./security/)
Security, privacy, and compliance documentation
- [HIPAA Compliance](./security/HIPAA_COMPLIANCE.md)
- [Authentication Flow](./security/AUTHENTICATION_FLOW.md)
- [Data Security](./security/DATA_SECURITY.md)

### 🔌 [API](./api/)
Backend integration and API documentation
- [API Contracts](./api/API_CONTRACTS.md)
- [Frontend-Backend Integration](./api/FRONTEND_BACKEND_INTEGRATION.md)
- [WebSocket Communication](./api/WEBSOCKET_COMMUNICATION.md)

### ✨ [Features](./features/)
Feature-specific implementation guides
- [HealthKit Integration](./features/HEALTHKIT_INTEGRATION.md)
- [PAT & Gemini Insights](./features/PAT_GEMINI_INSIGHTS.md)
- [Main Dashboard](./features/MAIN_DASHBOARD.md)
- [Pulse Dashboard](./features/PULSE_DASHBOARD.md)

### 📚 [Guides](./guides/)
Development and operational guides
- [Project Setup](./guides/PROJECT_SETUP.md)
- [Development Workflow](./guides/DEVELOPMENT_WORKFLOW.md)
- [Testing Strategy](./guides/TESTING_STRATEGY.md)
- [Deployment Guide](./guides/DEPLOYMENT_GUIDE.md)

## Quick Links
- [Implementation Roadmap](./IMPLEMENTATION_ROADMAP.md)
- [AWS Amplify Configuration](./guides/AMPLIFY_CONFIGURATION.md)
- [Troubleshooting](./guides/TROUBLESHOOTING.md)

## Key Technologies
- **Frontend**: SwiftUI, SwiftData, AWS Amplify iOS SDK
- **Authentication**: AWS Cognito (via Amplify)
- **Backend**: FastAPI on AWS ECS
- **Storage**: DynamoDB, S3
- **Analytics**: Custom metrics API

## Getting Started
1. Review the [Project Setup Guide](./guides/PROJECT_SETUP.md)
2. Understand the [Core Architecture](./architecture/CORE_ARCHITECTURE.md)
3. Check the [Authentication Flow](./security/AUTHENTICATION_FLOW.md)
4. Explore feature implementations in the [Features](./features/) section

## Archive
Historical documentation from previous implementations is available in [docs/archive](./archive/) for reference purposes only. These documents may contain outdated information.