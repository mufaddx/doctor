/// Environment configuration supplied at build time with --dart-define, so no
/// endpoint or key is hard-coded into the binary.
///
/// Example:
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

  static const String razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  static const String agoraAppId = String.fromEnvironment('AGORA_APP_ID');

  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const String appName = 'Touch of Cure';
  static const String supportPhone = '+919876543210';

  /// Page size used by every paginated list in the app.
  static const int pageSize = 20;
}

abstract final class ApiRoutes {
  // Auth
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String socialLogin = '/auth/social';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Users
  static const String me = '/users/me';
  static const String avatar = '/users/me/avatar';
  static const String fcmToken = '/users/me/fcm-token';

  // Patients
  static const String addresses = '/patients/me/addresses';
  static const String referral = '/patients/me/referral';

  // Therapists
  static const String therapists = '/therapists';
  static const String topRatedTherapists = '/therapists/top-rated';

  // Availability
  static String slots(String therapistId) =>
      '/availability/therapist/$therapistId/slots';

  // Appointments
  static const String appointments = '/appointments';

  // Payments
  static const String paymentOrder = '/payments/order';
  static const String paymentVerify = '/payments/verify';

  // Wallet
  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String applyReferral = '/wallet/referral/apply';

  // Coupons
  static const String availableCoupons = '/coupons/available';
  static const String applyCoupon = '/coupons/apply';

  // Clinical
  static const String prescriptions = '/prescriptions';
  static const String exercises = '/exercises';
  static const String myExercisePlan = '/exercises/my-plan';
  static const String progress = '/progress';
  static const String progressChart = '/progress/chart';

  // Reviews
  static const String reviews = '/reviews';
  static const String pendingReviews = '/reviews/pending';

  // Chat
  static const String chatThreads = '/chat/threads';
  static const String chatUnread = '/chat/unread-count';

  // Video
  static String joinCall(String appointmentId) =>
      '/video-call/$appointmentId/join';
  static String endCall(String appointmentId) =>
      '/video-call/$appointmentId/end';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnread = '/notifications/unread-count';

  // Content
  static const String banners = '/content/banners';
  static const String faqs = '/content/faqs';
  static const String tickets = '/content/tickets';
}
