class ApiConstants {
  static const String baseUrl = 'https://harahoritelecomllp.in/api';

  // Web pages (same host, no /api prefix) — used for Privacy Policy / Terms
  static const String webBaseUrl = 'https://harahoritelecomllp.in';
  static const String privacyPolicyUrl = '$webBaseUrl/privacy';
  static const String termsUrl         = '$webBaseUrl/terms';

  // Auth
  static const String login    = '/auth/login';
  static const String register = '/auth/register';
  static const String logout   = '/auth/logout';
  static const String me       = '/auth/me';

  // Forgot Password (3-step: send OTP → verify OTP → reset)
  static const String forgotSendOtp   = '/auth/forgot-password/send-otp';
  static const String forgotVerifyOtp = '/auth/forgot-password/verify-otp';
  static const String forgotReset     = '/auth/forgot-password/reset';

  // Free gift
  static const String gift      = '/gift';
  static const String giftClaim = '/gift/claim';
  static const String giftsMine = '/gifts/mine';

  // Home & Products
  static const String home           = '/home';
  static const String products       = '/products';
  static const String productsSearch = '/products/search';
  static const String categories     = '/categories';
  static const String brands         = '/brands';
  static const String coupons        = '/coupons/active';

  // Cart
  static const String cart        = '/cart';
  static const String cartAdd     = '/cart/add';
  static const String cartCoupon  = '/cart/coupon';
  static const String cartSummary = '/cart/summary';

  // Orders
  static const String orders         = '/orders';
  static const String shippingZones  = '/shipping-zones';
  static const String razorpayVerify = '/orders/razorpay/verify';
  static const String loyaltyPreview = '/orders/loyalty-preview';
  static String orderRefundClaim(String number) => '/orders/$number/refund';
  static String orderCancel(String number)      => '/orders/$number/cancel';
  static String orderInvoiceLink(String number) => '/orders/$number/invoice-link';

  // Wishlist
  static const String wishlist = '/wishlist';

  // Profile
  static const String profile   = '/profile';
  static const String profileAvatar = '/profile/avatar';
  static const String addresses = '/profile/addresses';

  // Exchange
  static const String exchangeVerifyImei = '/exchange/verify-imei';
  static const String exchangeEstimate   = '/exchange/estimate';
  static const String tradeInModelSearch = '/exchange/trade-in-models/search';
}
