/// Build-time configuration for the therapist app.
///
///   flutter run --dart-define=API_BASE_URL=https://api.touchofcure.in/api/v1
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String agoraAppId = String.fromEnvironment('AGORA_APP_ID');

  static const String appName = 'Touch of Cure Doctor';
  static const int pageSize = 20;
}

abstract final class ApiRoutes {
  // Auth: therapists sign in with a password, not an OTP
  static const String login = '/auth/login';
  static const String socialLogin = '/auth/social';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';

  // Profile
  static const String me = '/users/me';
  static const String avatar = '/users/me/avatar';
  static const String fcmToken = '/users/me/fcm-token';
  static const String therapistProfile = '/therapists/me';
  static const String availabilityToggle = '/therapists/me/availability-toggle';
  static const String certificates = '/therapists/me/certificates';
  static const String bankDetails = '/therapists/me/bank-details';
  static const String myReviews = '/therapists/me/reviews';

  // Availability
  static const String availability = '/availability/me';

  // Appointments
  static const String appointments = '/appointments';
  static const String todaySchedule = '/appointments/today';
  static const String dashboardStats = '/appointments/stats';

  // Patients
  static const String myPatients = '/patients/my-patients';
  static String patientHistory(String patientId) =>
      '/patients/$patientId/history';

  // Clinical
  static const String prescriptions = '/prescriptions';
  static const String exercises = '/exercises';
  static const String assignExercises = '/exercises/assign';
  static String patientProgress(String patientId) =>
      '/progress/patient/$patientId';

  // Money
  static const String earnings = '/wallet/earnings';
  static const String payouts = '/wallet/payouts';

  // Chat and video
  static const String chatThreads = '/chat/threads';
  static const String chatUnread = '/chat/unread-count';
  static String joinCall(String appointmentId) =>
      '/video-call/$appointmentId/join';
  static String endCall(String appointmentId) =>
      '/video-call/$appointmentId/end';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';
}
