// All user-visible strings for Delivery Management, Arabic + English.
//
// The app ships Arabic-first (default) with an English option in the
// Application settings. Every screen reads its strings from here via
// `S.of(context)` — no hardcoded Arabic (or English) literals in UI
// code, so switching language switches the WHOLE UI (nav, tabs,
// details, dialogs, buttons, messages) with no half-translated
// screen. RTL follows the locale automatically (MaterialApp.locale).
//
// Data is never translated: driver names, adjustment reasons and
// log entries stay exactly as stored.

import 'package:flutter/widgets.dart';

/// The app's two supported languages.
enum AppLanguage { arabic, english }

/// Central strings holder. [isArabic] drives RTL/LTR-sensitive
/// choices (chevron directions, label order) next to the text.
class DmStrings {
  const DmStrings._(this.isArabic);

  static const arabic = DmStrings._(true);
  static const english = DmStrings._(false);

  final bool isArabic;

  static DmStrings forLocale(Locale locale) =>
      locale.languageCode == 'en' ? english : arabic;

  static DmStrings of(BuildContext context) =>
      forLocale(Localizations.localeOf(context));

  // ---- money ----
  String money(double value) =>
      isArabic ? '${value.toStringAsFixed(0)} ج.م' : 'EGP ${value.toStringAsFixed(0)}';
  String signedMoney(double value, {required bool isBonus}) {
    final sign = isBonus ? '+' : '−';
    return isArabic
        ? '$sign${value.toStringAsFixed(0)} ج.م'
        : '$sign EGP ${value.toStringAsFixed(0)}';
  }

  // ---- common ----
  String get reconnect => isArabic ? 'إعادة الاتصال' : 'Reconnect';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get delete => isArabic ? 'مسح' : 'Delete';
  String get tapAgainToConfirm =>
      isArabic ? 'اضغط تاني للتأكيد' : 'Tap again to confirm';
  String get noData => isArabic ? 'مفيش بيانات' : 'No data';
  String get bonusWord => isArabic ? 'بونص' : 'Bonus';
  String get deductionWord => isArabic ? 'خصم' : 'Deduction';
  String get phoneLabel => isArabic ? 'التليفون' : 'Phone';
  String get emailLabel => isArabic ? 'الإيميل' : 'Email';
  String get payoutMethodLabel => isArabic ? 'طريقة القبض' : 'Payout method';
  String get payoutNotSet => isArabic ? 'غير محدد' : 'Not set';
  String get payoutVodafoneCash => isArabic ? 'فودافون كاش' : 'Vodafone Cash';
  String get payoutManual => isArabic ? 'يدوي' : 'Manual';
  String get transferNumberLabel => isArabic ? 'رقم التحويل' : 'Transfer number';
  String get walletNameLabel => isArabic ? 'اسم المحفظة' : 'Wallet name';
  String get diagnosticsTitle => isArabic ? 'سجل التشخيص' : 'Diagnostics log';
  String get clearLog => isArabic ? 'مسح السجل' : 'Clear log';
  String get logEmpty => isArabic
      ? 'السجل فاضي — مفيش أخطاء ولا أحداث متسجلة '
          'من ساعة ما فتحت التطبيق.'
      : 'The log is empty — no errors or events recorded '
          'since you opened the app.';
  String get emptyLog => isArabic
      ? 'السجل فاضي — مفيش أخطاء ولا أحداث متسجلة '
          'من ساعة ما فتحت التطبيق.'
      : 'Log is empty — no errors or events recorded since the app opened.';
  String liveStopped(String what, Object e) => isArabic
      ? 'الاتصال المباشر وقف ($what): $e'
      : 'Live connection stopped ($what): $e';
  String get liveStoppedGeneric => isArabic
      ? 'الاتصال المباشر وقف. اضغط تحديث لإعادة الاتصال.'
      : 'Live connection stopped. Tap refresh to reconnect.';
  String get fallbackNote => isArabic
      ? 'البيانات المعروضة من جلب لمرة واحدة — '
          'اضغط إعادة الاتصال لاستعادة المباشر.'
      : 'Showing one-time fetched data — tap Reconnect to restore live.';
  String fallbackFailed(Object e) => isArabic
      ? '\nتعذر الجلب الاحتياطي: $e'
      : '\nFallback fetch failed: $e';
  String failed(Object e) => isArabic ? 'فشل: $e' : 'Failed: $e';
  String saveFailed(Object e) => isArabic ? 'فشل الحفظ: $e' : 'Save failed: $e';
  String weekOf(String dayLabel) =>
      isArabic ? 'أسبوع $dayLabel' : 'Week of $dayLabel';
  String ordersCount(int n) =>
      isArabic ? '$n أوردر' : (n == 1 ? '1 order' : '$n orders');
  String kmValue(double km) => isArabic ? '$km كم' : '$km km';
  String durationLabel(int minutes, int seconds) => isArabic
      ? (seconds == 0 ? '$minutes د' : '$minutes د $seconds ث')
      : (seconds == 0 ? '$minutes min' : '$minutes min $seconds sec');

  // ---- calendar labels ----
  String dayLabel(String key) {
    final d = parseDayKey(key);
    if (isArabic) {
      const weekdays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      const months = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
    }
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  /// Weekday short names for the week chart, Sunday..Saturday.
  List<String> get dayShort => isArabic
      ? const ['أحد', 'إثنين', 'ثلاث', 'أربع', 'خميس', 'جمعة', 'سبت']
      : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // ---- dashboard ----
  String get dashboardTitle => isArabic ? 'لوحة التحكم' : 'Dashboard';
  String get teamCountLabel => isArabic ? 'فريق العمل' : 'Team';
  String get syncedTodayLabel => isArabic ? 'متزامن اليوم' : 'Synced today';
  String get ordersTodayLabel => isArabic ? 'أوردرات اليوم' : 'Orders today';
  String get kmTodayLabel => isArabic ? 'كم اليوم' : 'Km today';
  String get ordersWeekLabel => isArabic ? 'أوردرات الأسبوع' : 'Orders this week';
  String get kmWeekLabel => isArabic ? 'كم الأسبوع' : 'Km this week';
  String get kmSuffix => isArabic ? ' كم' : ' km';
  String get weekDueLabel => isArabic ? 'مستحق الأسبوع' : 'Week total due';
  String get weekDueNote => isArabic
      ? 'ج.م — شامل البونص والخصومات'
      : 'EGP — incl. bonuses and deductions';
  String get needsAttention => isArabic ? 'محتاج انتباه' : 'Needs attention';
  String notSyncedNames(String names) =>
      isArabic ? 'غير متزامن: $names' : 'Not synced: $names';
  String zeroOrdersNames(String names) =>
      isArabic ? 'صفر أوردرات: $names' : 'Zero orders: $names';
  String get teamTodayTitle => isArabic ? 'الفريق اليوم' : 'Team today';
  String driverRowLine(int orders, String km) => isArabic
      ? '$orders أوردر • $km كم'
      : '$orders orders • $km km';
  String get notSyncedToday => isArabic ? 'غير متزامن اليوم' : 'Not synced today';

  // ---- payroll ----
  String get payrollTitle => isArabic ? 'الأجور الأسبوعية' : 'Weekly payroll';
  String get noTeamForPayroll => isArabic
      ? 'مفيش أعضاء فريق لعرض أجورهم.'
      : 'No team members to show payroll for.';
  String payoutMethodLine(String method) =>
      isArabic ? 'طريقة القبض: $method' : 'Payout method: $method';
  String bonusLine(String money) =>
      isArabic ? 'بونص: +$money' : 'Bonus: +$money';
  String deductionLine(String money) =>
      isArabic ? 'خصم: −$money' : 'Deduction: −$money';
  String payoutTitle(String name) =>
      isArabic ? 'قبض $name' : '$name payout';
  String get dueTitle => isArabic ? 'المستحق' : 'Total due';
  String dayTotals(String money) =>
      isArabic ? 'مجاميع الأيام: $money' : 'Day totals: $money';
  String bonusAdjustments(String money) =>
      isArabic ? 'بونص (تعديلات): +$money' : 'Bonus (adjustments): +$money';
  String deductionAdjustments(String money) => isArabic
      ? 'خصومات (تعديلات): −$money'
      : 'Deductions (adjustments): −$money';
  String get otherWeekAdjustments => isArabic
      ? 'تعديلات تانية لنفس الأسبوع'
      : 'Other adjustments for the same week';
  String get otherWeekAdjustmentsNote => isArabic
      ? 'محسوبة في المجموع، لكن اتعملت في يوم '
          'بره الأسبوع.'
      : 'Counted in the total, but made on a day outside this week.';

  // ---- team ----
  String get teamTitle => isArabic ? 'فريق العمل' : 'Team';
  String daySummaryLine(int orders, String km, String money) => isArabic
      ? 'أوردرات: $orders • كم: $km • المجموع: $money'
      : 'Orders: $orders • Km: $km • Total: $money';
  String orderPriceLine(String price, String fixed) => isArabic
      ? 'سعر الأوردر: $price • ثابت اليوم: $fixed'
      : 'Order price: $price • Fixed day pay: $fixed';
  String bonusesLine(String distance, String manual, String flat) => isArabic
      ? 'بونص مسافة: $distance • بونص يدوي: $manual • بونص ثابت: $flat'
      : 'Distance bonus: $distance • Manual bonus: $manual • Flat bonus: $flat';
  String get searchByName => isArabic ? 'ابحث بالاسم' : 'Search by name';
  String get noMatches => isArabic ? 'مفيش نتائج مطابقة.' : 'No matching results.';
  String get managerRoleLabel => isArabic ? 'مدير' : 'Manager';
  String get driverRoleLabel => isArabic ? 'سواق' : 'Driver';
  String get currentlyBlocked => isArabic ? 'محظور حاليًا' : 'Currently blocked';
  String daySectionTitle(String label) => isArabic ? 'يوم $label' : label;
  String get noDayData => isArabic ? 'مفيش بيانات لليوم ده.' : 'No data for this day.';
  String get managerEditedNote =>
      isArabic ? 'آخر تعديل كان من المدير.' : 'Last edit was by a manager.';
  String get editDayTitle => isArabic ? 'تعديل بيانات اليوم' : 'Edit day data';
  String get daySaved => isArabic ? 'تم حفظ اليوم' : 'Day saved';
  String get weekTotalTitle => isArabic ? 'مجموع الأسبوع' : 'Week total';
  String weekBonus(String money) => isArabic ? 'بونص: +$money' : 'Bonus: +$money';
  String weekDeduction(String money) =>
      isArabic ? 'خصم: −$money' : 'Deduction: −$money';
  String netTotal(String money) => isArabic ? 'الصافي: $money' : 'Net: $money';
  String get loadingOrders => isArabic ? 'جاري تحميل الأوردرات...' : 'Loading orders...';
  String get selfRoleNote => isArabic
      ? 'ده حسابك — مينفعش تغيّر دورك أو تحظر '
          'نفسك بنفسك.'
      : 'This is your account — you cannot change your own role or block yourself.';
  String get promoteToManagerQ => isArabic ? 'ترقية لمدير؟' : 'Promote to manager?';
  String get demoteToDriverQ => isArabic ? 'تنزيل لسواق؟' : 'Demote to driver?';
  String promoteBody(String name) => isArabic
      ? '$name هيبقى مدير '
          'ويشوف كل بيانات الفريق.'
      : '$name will become a manager and see all team data.';
  String demoteBody(String name) => isArabic
      ? '$name هيرجع سواق '
          'ومش هيشوف صفحة المديرين.'
      : '$name will go back to driver and will not see the managers pages.';
  String get promoteAction => isArabic ? 'ترقية' : 'Promote';
  String get demoteAction => isArabic ? 'تنزيل' : 'Demote';
  String get promoteToManager => isArabic ? 'ترقية لمدير' : 'Promote to manager';
  String get demoteToDriver => isArabic ? 'تنزيل لسواق' : 'Demote to driver';
  String get blockDriverQ => isArabic ? 'حظر السواق؟' : 'Block driver?';
  String get blockDriverBody => isArabic
      ? 'مش هيقدر يسجل دخول، وهيختفي '
          'من الفريق، وأجوره مش هتتحسب. '
          'داتاه محفوظة — فك الحظر بيرجّعه '
          'كامل. مفيش حاجة بتتمسح.'
      : 'They will not be able to sign in, will disappear '
          'from the team, and their pay will not be counted. '
          'Their data is kept — unblocking restores them '
          'fully. Nothing is deleted.';
  String get blockAction => isArabic ? 'حظر' : 'Block';
  String get unblockDriverQ => isArabic ? 'فك حظر السواق؟' : 'Unblock driver?';
  String unblockBody(String name) => isArabic
      ? '$name هيرجع '
          'يسجل دخول بداتاه كاملة.'
      : '$name will sign in again with their full data.';
  String get unblockAction => isArabic ? 'فك الحظر' : 'Unblock';
  String get todayOrdersTitle => isArabic ? 'أوردرات اليوم' : "Today's orders";
  String get noOrderHistory => isArabic
      ? 'مفيش سجل أوردرات لليوم ده.'
      : 'No order history for this day.';
  String get orderUploadNote => isArabic
      ? 'تفاصيل الأوردر الواحد لسه مش بتترفع للسحابة من '
          'تطبيق السواق — أول ما تحديث الرفع ده ينزل، '
          'الأوردرات هتظهر هنا بالتفصيل.'
      : 'Single-order details are not uploaded to the cloud from '
          'the driver app yet — once that upload update lands, '
          'orders will show here in full detail.';
  String get managerAdjustmentsTitle =>
      isArabic ? 'تعديلات المدير (بونص / خصم)' : 'Manager adjustments (bonus / deduction)';
  String get noAdjustmentsYet =>
      isArabic ? 'مفيش تعديلات لحد دلوقتي.' : 'No adjustments yet.';
  String weekTag(String weekKey) =>
      isArabic ? '(أسبوع $weekKey)' : '(week $weekKey)';
  String get deleteAdjustmentQ => isArabic ? 'مسح التعديل؟' : 'Delete adjustment?';
  String get deleteAdjustmentBody => isArabic
      ? 'التعديل هيتشال من مجموع الأسبوع.'
      : 'The adjustment will be removed from the week total.';
  String get amountLabelEgp => isArabic ? 'المبلغ (ج.م)' : 'Amount (EGP)';
  String get reasonRequiredLabel => isArabic ? 'السبب (مطلوب)' : 'Reason (required)';
  String get addAdjustment => isArabic ? 'إضافة التعديل' : 'Add adjustment';
  String get ordersCountField => isArabic ? 'عدد الأوردرات' : 'Orders count';
  String get totalKmField => isArabic ? 'إجمالي الكم' : 'Total km';
  String get orderPriceField => isArabic ? 'سعر الأوردر (ج.م)' : 'Order price (EGP)';
  String get fixedPayField => isArabic ? 'ثابت اليوم (ج.م)' : 'Fixed day pay (EGP)';
  String get distanceBonusField => isArabic ? 'بونص مسافة (ج.م)' : 'Distance bonus (EGP)';
  String get manualBonusField => isArabic ? 'بونص يدوي (ج.م)' : 'Manual bonus (EGP)';
  String get flatBonusField => isArabic ? 'بونص ثابت (ج.م)' : 'Flat bonus (EGP)';
  String get validNumbersError => isArabic
      ? 'أدخل أرقام صحيحة أكبر من أو تساوي صفر.'
      : 'Enter valid numbers greater than or equal to zero.';
  String get validNumbersShort => isArabic ? 'أدخل أرقام صحيحة.' : 'Enter valid numbers.';
  String get validNumbersShortError =>
      isArabic ? 'أدخل أرقام صحيحة.' : 'Enter valid numbers.';
  String get editOrderTitle => isArabic ? 'تعديل الأوردر' : 'Edit order';
  String get addressNotesField => isArabic ? 'العنوان / ملاحظات' : 'Address / notes';
  String get customerPhoneField => isArabic ? 'تليفون العميل' : 'Customer phone';
  String get kmOutField => isArabic ? 'كم الذهاب' : 'Km out';
  String get kmBackField => isArabic ? 'كم العودة' : 'Km back';
  String get routePointsNote => isArabic
      ? 'ملحوظة: الخريطة نفسها مش موجودة في نسخة المدير الأولى — كل حقول البيانات موجودة هنا.'
      : 'Note: the map itself is not in this first manager version — all data fields are shown here.';
  String get fullOrderNumber => isArabic ? 'رقم الأوردر الكامل' : 'Full order number';
  String orderTitle(String shortId) => isArabic ? 'أوردر #$shortId' : 'Order #$shortId';
  String get dayField => isArabic ? 'اليوم' : 'Day';
  String get distancesSection => isArabic ? 'المسافات' : 'Distances';
  String kmOutLine(String km) => isArabic ? 'ذهاب: $km كم' : 'Out: $km km';
  String get manualMarker => isArabic ? ' (يدوي)' : ' (manual)';
  String kmBackLine(String km) => isArabic ? 'عودة: $km كم' : 'Back: $km km';
  String kmTotalLine(String km) => isArabic ? 'إجمالي: $km كم' : 'Total: $km km';
  String gpsKmLine(String out, String back) => isArabic
      ? 'GPS ذهاب: $out كم • GPS عودة: $back كم'
      : 'GPS out: $out km • GPS back: $back km';
  String manualKmLine(String out, String back) => isArabic
      ? 'يدوي ذهاب: $out كم • يدوي عودة: $back كم'
      : 'Manual out: $out km • Manual back: $back km';
  String get timesSection => isArabic ? 'التوقيتات والمدد' : 'Times and durations';
  String pickupLabel(String t) => isArabic ? 'بدأ التوصيل: $t' : 'Pickup started: $t';
  String deliveredLabel(String t) => isArabic ? 'وصل للعميل: $t' : 'Delivered: $t';
  String martLabel(String t) => isArabic ? 'وصل للمارت: $t' : 'Arrived at mart: $t';
  String durationsLine(String out, String back, String total) => isArabic
      ? 'مدة الذهاب: $out • مدة العودة: $back • الإجمالي: $total'
      : 'Out duration: $out • Back duration: $back • Total: $total';
  String get moneyStatusSection => isArabic ? 'مالية وحالة' : 'Money and status';
  String manualBonusLine(String money) =>
      isArabic ? 'بونص يدوي: $money' : 'Manual bonus: $money';
  String countOnlyYes(bool yes) =>
      isArabic ? 'إدخال عددي فقط: ${yes ? 'نعم' : 'لا'}' : 'Count-only entry: ${yes ? 'Yes' : 'No'}';
  String createdUpdatedLine(String created, String updated) => isArabic
      ? 'اتعمل: $created • آخر تحديث: $updated'
      : 'Created: $created • Last updated: $updated';
  String routePointsLine(int route, int road) => isArabic
      ? 'نقاط المسار المسجلة: $route • نقاط الطريق: $road'
      : 'Recorded route points: $route • Road points: $road';
  String get noMapNote => isArabic
      ? 'ملحوظة: الخريطة نفسها مش موجودة في نسخة '
          'المدير الأولى — كل حقول البيانات موجودة هنا.'
      : 'Note: the map itself is not in the first manager '
          'version — every data field is here.';
  String completedOrdersLine(int n, String km) => isArabic
      ? '$n أوردر مكتمل • $km كم'
      : '$n completed orders • $km km';
  String orderStatusLabel(int status) => switch (status) {
        1 => isArabic ? 'في الطريق للعميل' : 'On the way to customer',
        2 => isArabic ? 'في الطريق للمارت' : 'On the way to mart',
        3 => isArabic ? 'مكتمل' : 'Completed',
        _ => isArabic ? 'معلق' : 'Pending',
      };

  // ---- block ----
  String get blockTitle => isArabic ? 'محظور' : 'Blocked';
  String get blockedLabel => isArabic ? 'محظور' : 'Blocked';
  String get noBlockedNow => isArabic ? 'مفيش حد محظور حاليًا.' : 'Nobody is blocked right now.';
  String blockedDay(String label) => isArabic ? 'محظور يوم $label' : 'Blocked on $label';
  String get blockDataKept => isArabic
      ? 'داتاه كلها محفوظة — فك الحظر بيرجّعه كامل، '
          'بنفس الأوردرات والأجور والتعديلات.'
      : 'All their data is kept — unblocking restores them fully, '
          'with the same orders, pay and adjustments.';
  String unblockTitle(String name) =>
      isArabic ? 'فك حظر $name؟' : 'Unblock $name?';
  String get unblockDetailBody => isArabic
      ? 'هيرجع يسجل دخول بداتاه كاملة، ويرجع '
          'يظهر في الفريق والأجور.'
      : 'They will sign in again with their full data, and return '
          'to the team and payroll.';

  // ---- application ----
  String get managerSignedIn => isArabic ? 'مدير • مسجل دخول' : 'Manager • signed in';
  String get usernameLabel => isArabic ? 'اسم المستخدم' : 'Username';
  String get teamEntrySubtitle => isArabic
      ? 'كل الناس اللي شغالة معانا — سواقين ومديرين'
      : 'Everyone working with us — drivers and managers';
  String get appSettingsTitle => isArabic ? 'إعدادات التطبيق' : 'App settings';
  String get themeAuto => isArabic ? 'تلقائي' : 'Auto';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get themeDark => isArabic ? 'داكن' : 'Dark';
  String get languageTitle => isArabic ? 'اللغة' : 'Language';
  String get languageArabic => 'العربية';
  String get languageEnglish => 'English';
  String get applicationTitle => isArabic ? 'Application' : 'Application';
  String get diagnosticsSubtitle => isArabic
      ? 'كل الأحداث والأخطاء بأسبابها الحقيقية'
      : 'Every event and error with its real cause';
  String get signOut => isArabic ? 'تسجيل الخروج' : 'Sign out';
  String get signOutQ => isArabic ? 'تسجيل الخروج؟' : 'Sign out?';
  String get signOutBody => isArabic
      ? 'هتخرج من حساب المدير، وهتحتاج تسجل '
          'دخول تاني عشان ترجع.'
      : 'You will leave the manager account, and will need to sign '
          'in again to return.';
  String get fillAllFields => isArabic ? 'املأ كل الحقول.' : 'Fill in all fields.';
  String get passwordMinLength => isArabic
      ? 'كلمة المرور الجديدة لازم 6 حروف على الأقل.'
      : 'The new password must be at least 6 characters.';
  String get passwordMismatch => isArabic
      ? 'كلمة المرور الجديدة مش مطابقة للتأكيد.'
      : 'The new password does not match the confirmation.';
  String get passwordChanged => isArabic ? 'تم تغيير كلمة المرور.' : 'Password changed.';
  String get changePasswordTitle => isArabic ? 'تغيير كلمة المرور' : 'Change password';
  String get currentPasswordLabel => isArabic ? 'كلمة المرور الحالية' : 'Current password';
  String get newPasswordLabel => isArabic ? 'كلمة المرور الجديدة' : 'New password';
  String get confirmPasswordLabel =>
      isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm new password';
  String get emailCopied => isArabic ? 'تم نسخ الإيميل' : 'Email copied';
  String get linkCopied => isArabic ? 'تم نسخ الرابط' : 'Link copied';
  String get helpSupportTitle => isArabic ? 'المساعدة والدعم' : 'Help & Support';
  String get aboutApp => isArabic ? 'عن التطبيق' : 'About the app';
  String get designedBy => isArabic ? 'تصميم' : 'Designed by';
  String get contactLabel => isArabic ? 'التواصل' : 'Contact';
  String get callUs => isArabic ? 'اتصل بنا' : 'Call us';
  String get personalWebsite => isArabic ? 'الموقع الشخصي' : 'Personal website';

  // ---- login / session ----
  String get loginSubtitle => isArabic
      ? 'تطبيق المديرين — نفس بيانات DeliveryFlow'
      : 'Managers app — same DeliveryFlow credentials';
  String get firebaseNotReady => isArabic
      ? 'لم يتم ربط Firebase بعد — مش هينفع '
          'تسجيل الدخول لحد ما الإعدادات '
          'الحقيقية تتحط في النسخة.'
      : 'Firebase is not linked yet — sign-in cannot work '
          'until the real settings are in the build.';
  String get identifierLabel =>
      isArabic ? 'اسم المستخدم أو رقم التليفون' : 'Username or phone number';
  String get passwordLabel => isArabic ? 'كلمة المرور' : 'Password';
  String get signInAction => isArabic ? 'دخول' : 'Sign in';
  String get noSignupNote => isArabic
      ? 'الحسابات بتتعمل من DeliveryFlow وبتترقى لمدير '
          'من هناك. مفيش إنشاء حساب من هنا.'
      : 'Accounts are created in DeliveryFlow and promoted to manager '
          'there. No account creation here.';
  String get restoreFailed => isArabic
      ? 'تعذر استعادة الجلسة. سجّل دخولك من جديد.'
      : 'Could not restore the session. Please sign in again.';
  String get noAccountForIdentifier => isArabic
      ? 'لا يوجد حساب بهذا الاسم أو الرقم.'
      : 'No account with this name or number.';
  String get invalidCredentials => isArabic ? 'بيانات الدخول غير صحيحة.' : 'Invalid login credentials.';
  String signInFailed(Object e) =>
      isArabic ? 'تعذر تسجيل الدخول: $e' : 'Could not sign in: $e';
  String get accountBlocked => isArabic
      ? 'هذا الحساب محظور. تواصل مع مدير آخر.'
      : 'This account is blocked. Contact another manager.';
  String get mustChangePasswordNote => isArabic
      ? 'لازم تغيّر كلمة المرور الأول من تطبيق DeliveryFlow، '
          'وبعدها ادخل هنا تاني.'
      : 'You must change your password first in the DeliveryFlow app, '
          'then sign in here again.';
  String get managersOnlyApp => isArabic ? 'هذا التطبيق للمديرين فقط.' : 'This app is for managers only.';
  String get noProfileDoc => isArabic
      ? 'لا يوجد ملف حساب لهذا المستخدم.'
      : 'No profile document for this user.';

  // ---- backend / validation errors, mapped by message ----
  String localizeError(Object e) {
    final raw = e.toString();
    const map = {
      'غير مسموح': 'Not allowed.',
      'هذا الحساب محظور.': 'This account is blocked.',
      'هذا التطبيق للمديرين فقط.': 'This app is for managers only.',
      'لا يمكن للمدير تعديل أجره بنفسه.': 'A manager cannot edit their own pay.',
      'لا يمكن تغيير دور حسابك بنفسك.': 'You cannot change your own role.',
      'لا يمكن حظر حسابك بنفسك.': 'You cannot block yourself.',
      'لا توجد جلسة دخول حالية.': 'No current session.',
      'كلمة المرور الحالية غير صحيحة.': 'Current password is incorrect.',
      'غير مسجل دخول.': 'Not signed in.',
      'أدخل مبلغ أكبر من صفر.': 'Enter an amount greater than zero.',
      'السبب مطلوب — السواق لازم يعرف ليه.':
          'A reason is required — the driver must know why.',
      'manager only': 'Managers only.',
      'لم يتم ربط Firebase بعد. سجّل تطبيق Android جديد في '
          'كونسول Firebase بنفس المشروع ثم الصق إعدادات Firebase '
          'في lib/data/firebase_options.dart.':
          'Firebase is not linked yet. Register a new Android app in '
              'the Firebase console for the same project, then paste the '
              'Firebase settings into lib/data/firebase_options.dart.',
    };
    if (isArabic) return raw;
    return map[raw] ?? raw;
  }

  String get notConfiguredMessage => isArabic
      ? 'لم يتم ربط Firebase بعد. سجّل تطبيق Android جديد في '
          'كونسول Firebase بنفس المشروع ثم الصق إعدادات Firebase '
          'في lib/data/firebase_options.dart.'
      : 'Firebase is not linked yet. Register a new Android app in '
          'the Firebase console for the same project, then paste the '
          'Firebase settings into lib/data/firebase_options.dart.';
}

/// Parses a yyyy-MM-dd key without depending on week_utils (which
/// imports nothing from here, avoiding a cycle).
DateTime parseDayKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
