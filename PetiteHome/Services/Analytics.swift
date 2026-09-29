import Foundation
import PostHog

/// PostHog, the one approved dependency. No PII in properties, ever.
enum AnalyticsEvent: String {
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingCompleted = "onboarding_completed"
    case familyFileCompleteness = "family_file_completeness"
    case paywallViewed = "paywall_viewed"
    case trialStarted = "trial_started"
    case subscriptionConverted = "subscription_converted"
    case pdfExported = "pdf_exported"
    case partnerInvited = "partner_invited"
    case foundingCodeRedeemed = "founding_code_redeemed"
    case lifeSyncEnabled = "life_sync_enabled"
    case recipeShared = "recipe_shared"
    case recipeImported = "recipe_imported"
    case mealPlanned = "meal_planned"
    case planCreated = "plan_created"
    case sitterSheetSent = "sitter_sheet_sent"
}

enum Analytics {
    /// Set in Settings.bundle or a build config; empty disables tracking.
    static var apiKey: String { Bundle.main.object(forInfoDictionaryKey: "PostHogAPIKey") as? String ?? "" }
    static var host: String { Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String ?? "https://us.i.posthog.com" }
    private static var isEnabled = false

    static func start() {
        guard !apiKey.isEmpty else { return }
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    static func track(_ event: AnalyticsEvent, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
