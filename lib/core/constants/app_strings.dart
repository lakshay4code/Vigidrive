/// Centralized string constants for the VigiDrive application.
abstract final class AppStrings {
  static const String appName = 'VigiDrive';
  static const String appTagline = 'Driver Monitoring & Violation Companion';

  // Login Screen Strings
  static const String loginTitle = 'Sign In';
  static const String loginSubtitle = 'Enter your credentials to access your account';
  static const String emailLabel = 'Email Address';
  static const String emailHint = 'e.g. driver@organization.com';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String signInButton = 'Sign In';
  static const String forgotPassword = 'Forgot Password?';

  // Validation Messages
  static const String emailRequired = 'Please enter your email address.';
  static const String emailInvalid = 'Please enter a valid email address.';
  static const String passwordRequired = 'Please enter your password.';
  static const String passwordMinLength = 'Password must be at least 6 characters.';

  // Active Systems Strings
  static const String activeSystemsTitle = 'Active Systems';
  static const String violationsDetected = 'Violations detected';
  static const String systemsNormal = 'Systems operating normally';
  static const String systemsOffline = 'Systems offline';

  // System Details Strings
  static const String systemStatus = 'System Status';
  static const String active = 'ACTIVE';
  static const String driver = 'Driver';
  static const String contactDriver = 'Contact Driver';
  static const String dialerError =
      'Unable to open the phone dialer. Please try again.';

  // Violations Strings
  static const String recentViolations = 'Recent Violations';
  static const String viewAllViolations = 'View All Violations';
  static const String drowsinessDetected = 'Drowsiness Detected';
  static const String detectionConfirmed = 'Detection confirmed';
  static const String date = 'Date';
  static const String time = 'Time';
  static const String duration = 'Duration';
  static const String system = 'System';
  static const String detectionResult = 'Detection Result';
  static const String sleepy = 'Sleepy';
  static const String confidence = 'Confidence';
  static const String recording = 'Recording';
  static const String recordingStoredOnPC = 'Recording stored on monitoring PC';
  static const String recordingStoredOnPCSubtext =
      'This violation has a local recording saved on the monitoring system.';
  static const String noRecordingAvailable = 'No recording available';
  static const String noRecordingAvailableSubtext =
      'This violation does not have an associated recording.';
  static const String view = 'View';

  // Settings Strings
  static const String settingsTitle = 'Settings';
  static const String accountSection = 'Account';
  static const String accountInformation = 'Account Information';
  static const String defaultAccountEmail = 'driver@organization.com';
  static const String signOut = 'Sign Out';
  static const String applicationSection = 'Application';
  static const String notifications = 'Notifications';
  static const String notificationsUnavailable =
      'Unavailable until backend service connection';
  static const String aboutApp = 'About VigiDrive';
  static const String driverSafetyMonitoring = 'Driver Safety Monitoring';
  static const String appVersion = 'Version 1.0.0+1';
  static const String close = 'Close';

  // Feedback Messages
  static const String authReadyNotice =
      'Validation passed. Navigating to active systems.';
  static const String forgotPasswordNotice =
      'Password reset request initiated. Functionality will connect to the authentication service.';

  // Navigation
  static const String navHome = 'Home';
  static const String navNotifications = 'Notifications';
  static const String navSystems = 'My Systems';
  static const String navSettings = 'Settings';

  // My Systems Screen
  static const String mySystemsTitle = 'My Systems';
  static const String noSystemsConnected = 'No monitoring systems connected';
  static const String noSystemsConnectedSubtext =
      'Connect a monitoring system to see it here.';

  // Home / Dashboard
  static const String homeWelcomePrefix = 'Welcome,';
  static const String homeSubtitle = "Here\u2019s your monitoring overview.";
  static const String monitoringSection = 'Monitoring';
  static const String monitoringOffline = 'Monitoring offline';
  static const String monitoringOfflineSubtext =
      'Your monitoring system is currently offline.';
  static const String monitoringActive = 'Monitoring active';
  static const String recentActivitySection = 'Recent Activity';
  static const String noViolationsRecorded = 'No violations recorded';
  static const String noViolationsSubtext =
      'Detected violations will appear here.';
  static const String storedRecordings = 'Stored Recordings';
  static const String storedRecordingsSubtext =
      'Review previously captured detection recordings.';

  // Notifications
  static const String notificationsTitle = 'Notifications';
  static const String noNewNotifications = 'No new notifications';
  static const String noNewNotificationsSubtext =
      'Unresolved violation alerts will appear here.';

  // Recordings
  static const String recordingsTitle = 'Stored Recordings';
  static const String noRecordingsAvailable = 'No recordings available';
  static const String recordingsSubtext =
      'Captured detection recordings will appear here.';
}
