class AppStrings {
  AppStrings._();

  // Referral
  static String referralMessage(String code, String appLink) =>
      "👋 Hi! I'm using Adhisaat for home healthcare. "
      "Use my referral code *$code* when you sign up! "
      "\n\nDownload Adhisaat now: $appLink 🏥";

  static const String referralSubject = "Join Adhisaat with my referral code!";

  static String providerReferralMessage(String code, String appLink) =>
      "👋 Hi! I'm a service partner at Adhisaat. "
      "Join me on the platform and use my referral code *$code* when you sign up! "
      "\n\nDownload the app now: $appLink 🏥";

  static const String providerReferralSubject = "Join me on Adhisaat as a Service Partner!";

  static const List<String> referralTerms = [
    'Referral bonus will be credited to your bonus wallet after the referred user completes their first booking.',
    'Bonus amount can be used towards any eligible service booking on Adhisaat.',
    'Bonus wallet balance is non-transferable and cannot be withdrawn as cash.',
    'Adhisaat reserves the right to modify or cancel this program at any time.',
    'Self-referrals or misuse of the program will lead to disqualification.',
  ];
  static const List<String> procedureFeatures = ['Quick Home Visits', 'Hourly Schedule', 'Medical Assistance'];
  static const List<String> longDurationFeatures = ['24/7 Dedicated Care', 'Long-term Stays', 'Bundle Discounts'];

  // Common UI Strings
  static const String searchHint = "Search services, clinics, doctors...";
  static const String retry = "Try again";
  static const String somethingWentWrong = "Something went wrong. Please try again later.";
  static const String aadharReject = "Aadhar card was rejected. Please re-upload a clear document.";
  static const String panReject = "PAN card was rejected. Please re-upload a clear document.";

  // Provider Onboarding
  static const String providerIntroTitle1 = "Grow Your\nCare Practice";
  static const String providerIntroSubtitle1 =
      "Connect with thousands of families seeking trusted home healthcare. Put your skills to work and build a steady, reliable patient base in your area.";
  static const String providerIntroTag1 = "GROWTH";

  static const String providerIntroTitle2 = "Work on\nYour Terms";
  static const String providerIntroSubtitle2 =
      "You stay in control. Set your own availability, choose your service areas, and shape a healthcare career that fits around your life.";
  static const String providerIntroTag2 = "FLEXIBILITY";

  static const String providerIntroTitle3 = "Earn With\nConfidence";
  static const String providerIntroSubtitle3 =
      "Track every visit and watch your income grow. Enjoy secure, on-time payouts straight to your account — no chasing, no paperwork.";
  static const String providerIntroTag3 = "EARNINGS";

  static const String providerIntroTitle4 = "We've Got\nYour Back";
  static const String providerIntroSubtitle4 =
      "From easy onboarding to a dedicated partner team, get the training, tools, and round-the-clock support you need to succeed.";
  static const String providerIntroTag4 = "SUPPORT";

  static const String skip = "Skip";
  static const String continueText = "Continue";
  static const String joinAsProvider = "Join as Partner";
  static const String reliability = "Trust";
  static const String care = "Care";
  static const String success = "Support";

  // Provider Onboarding — hero design (shared)
  static const String providerJoinNetwork = "Join Adhisaat Partner Network";
  static const String providerHeroFeature1 = "Trusted\nPlatform";
  static const String providerHeroFeature2 = "More\nEarnings";
  static const String providerHeroFeature3 = "Make a\nDifference";
  static const String partnerLabel = "Partner";

  // Page 1 — Booking requests
  static const String providerHero1HeadingTop = "Get Instant";
  static const String providerHero1HeadingBottom = "Booking Requests";
  static const String providerHero1Lead = "Connect with patients near you";
  static const String providerHero1Body =
      "Receive real-time healthcare service requests based on your expertise, location, and availability. Never miss an opportunity to serve and earn.";
  static const String hero1CardBadge = "New Booking Request";
  static const String hero1CardTrailing = "Now";
  static const String hero1CardTitle = "Ravi Sharma";
  static const String hero1CardSub = "Physiotherapy";
  static const String hero1CardMeta = "2.5 km away";
  static const String hero1CardCta = "View Details";

  // Page 2 — Work on your own terms
  static const String providerHero2HeadingTop = "Work On Your";
  static const String providerHero2HeadingBottom = "Own Terms";
  static const String providerHero2Lead = "Flexibility that fits your life";
  static const String providerHero2Body =
      "You decide when and where you work. Set your availability, choose your service areas, and balance your career around your life.";
  static const String hero2CardBadge = "Your Availability";
  static const String hero2CardTrailing = "Today";
  static const String hero2CardTitle = "You're Online";
  static const String hero2CardSub = "Accepting new requests";
  static const String hero2CardMeta = "Mon–Fri · 9 AM–6 PM";
  static const String hero2CardCta = "Edit Schedule";

  // Page 3 — Earnings
  static const String providerHero3HeadingTop = "Earn More,";
  static const String providerHero3HeadingBottom = "Stress Less";
  static const String providerHero3Lead = "Secure, on-time payouts";
  static const String providerHero3Body =
      "Track every visit and watch your earnings grow. Payouts land directly in your account — no chasing, no paperwork.";
  static const String hero3CardBadge = "Weekly Earnings";
  static const String hero3CardTrailing = "This week";
  static const String hero3CardTitle = "₹4,250";
  static const String hero3CardSub = "5 visits completed";
  static const String hero3CardMeta = "+18% vs last week";
  static const String hero3CardCta = "View Earnings";

  // Page 4 — Support
  static const String providerHero4HeadingTop = "We've Got";
  static const String providerHero4HeadingBottom = "Your Back";
  static const String providerHero4Lead = "Support whenever you need it";
  static const String providerHero4Body =
      "From easy onboarding to a dedicated partner team, get the training, tools, and round-the-clock support you need to succeed.";
  static const String hero4CardBadge = "Partner Support";
  static const String hero4CardTrailing = "24/7";
  static const String hero4CardTitle = "Live Support";
  static const String hero4CardSub = "Avg. reply 2 min";
  static const String hero4CardMeta = "We're here to help";
  static const String hero4CardCta = "Get Help";
}
