import ProjectDescription

let project = Project(
    name: "clarity-loop-frontend",
    organizationName: "Novamind NYC",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "ENABLE_PREVIEWS": "YES",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "DEVELOPMENT_TEAM": "YOUR_TEAM_ID",
            "MARKETING_VERSION": "1.0",
            "CURRENT_PROJECT_VERSION": "1",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.novamindnyc.clarity-loop-frontend",
            "PRODUCT_NAME": "CLARITY Pulse",
            // Enable background modes
            "ENABLE_BACKGROUND_MODES": "YES",
            // Security and privacy
            "CODE_SIGN_STYLE": "Automatic",
            "ENABLE_BITCODE": "NO",
            // Swift optimization
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            "SWIFT_COMPILATION_MODE": "wholemodule",
            // Debug settings
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "GCC_OPTIMIZATION_LEVEL": "0",
            // AI-friendly build settings
            "COMPILER_INDEX_STORE_ENABLE": "YES",
            "INDEX_ENABLE_DATA_STORE": "YES"
        ],
        configurations: [
            .debug(name: "Debug", xcconfig: nil),
            .release(name: "Release", xcconfig: nil)
        ]
    ),
    targets: [
        Target(
            name: "clarity-loop-frontend",
            platform: .iOS,
            product: .app,
            bundleId: "com.novamindnyc.clarity-loop-frontend",
            deploymentTarget: .iOS(targetVersion: "17.0", devices: .iphone),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "CLARITY Pulse",
                "CFBundleName": "CLARITY Pulse",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
                "UILaunchStoryboardName": "LaunchScreen",
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                            ]
                        ]
                    ]
                ],
                // HealthKit permissions
                "NSHealthShareUsageDescription": "CLARITY Pulse reads your health data to provide personalized health insights and track your wellness journey.",
                "NSHealthUpdateUsageDescription": "CLARITY Pulse updates your health records to sync wellness data across your devices.",
                "NSHealthClinicalHealthRecordsShareUsageDescription": "CLARITY Pulse accesses clinical records to provide comprehensive health analysis.",
                // Background modes
                "UIBackgroundModes": ["fetch", "processing", "remote-notification"],
                "BGTaskSchedulerPermittedIdentifiers": ["com.novamindnyc.clarity-loop-frontend.healthsync", "com.novamindnyc.clarity-loop-frontend.refresh"],
                // Face ID permission
                "NSFaceIDUsageDescription": "CLARITY Pulse uses Face ID to securely access your health data.",
                // Network permissions
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": false,
                    "NSExceptionDomains": [
                        "localhost": [
                            "NSExceptionAllowsInsecureHTTPLoads": true
                        ]
                    ]
                ],
                // App capabilities
                "ITSAppUsesNonExemptEncryption": false,
                "UIRequiredDeviceCapabilities": ["arm64"],
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "UIStatusBarStyle": "UIStatusBarStyleLightContent",
                "UIViewControllerBasedStatusBarAppearance": true
            ]),
            sources: ["clarity-loop-frontend/**/*.swift"],
            resources: ["clarity-loop-frontend/**/*.{xcassets,json,storyboard,xib,xcdatamodeld}"],
            dependencies: [],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                    "ENABLE_TESTABILITY": "YES",
                    "SWIFT_EMIT_LOC_STRINGS": "YES",
                    "TARGETED_DEVICE_FAMILY": "1"
                ]
            )
        ),
        Target(
            name: "clarity-loop-frontendTests",
            platform: .iOS,
            product: .unitTests,
            bundleId: "com.novamindnyc.clarity-loop-frontendTests",
            deploymentTarget: .iOS(targetVersion: "17.0", devices: .iphone),
            infoPlist: .default,
            sources: ["clarity-loop-frontendTests/**/*.swift"],
            dependencies: [
                .target(name: "clarity-loop-frontend")
            ]
        ),
        Target(
            name: "clarity-loop-frontendUITests",
            platform: .iOS,
            product: .uiTests,
            bundleId: "com.novamindnyc.clarity-loop-frontendUITests",
            deploymentTarget: .iOS(targetVersion: "17.0", devices: .iphone),
            infoPlist: .default,
            sources: ["clarity-loop-frontendUITests/**/*.swift"],
            dependencies: [
                .target(name: "clarity-loop-frontend")
            ]
        )
    ]
)