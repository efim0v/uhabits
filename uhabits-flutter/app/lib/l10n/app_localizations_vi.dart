// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class L10nVi extends L10n {
  L10nVi([String locale = 'vi']) : super(locale);

  @override
  String get overview => 'Tổng quan';

  @override
  String get appName => 'Trình theo dõi thói quen Loop';

  @override
  String get mainActivityTitle => 'Thói quen';

  @override
  String get actionSettings => 'Cài đặt';

  @override
  String get edit => 'Chỉnh sửa';

  @override
  String get delete => 'Xoá';

  @override
  String get archive => 'Lưu trữ';

  @override
  String get unarchive => 'Hủy lưu trữ';

  @override
  String get addHabit => 'Thêm thói quen';

  @override
  String get colorPickerDefaultTitle => 'Thay đổi màu sắc';

  @override
  String get toastHabitCreated => 'Thói quen đã được tạo';

  @override
  String get habitStrength => 'Độ mạnh của thói quen';

  @override
  String get history => 'Lịch sử';

  @override
  String get clear => 'Xoá';

  @override
  String get reminder => 'Nhắc nhở';

  @override
  String get save => 'Lưu';

  @override
  String get streaks => 'Mức độ';

  @override
  String get noHabitsFound => 'Bạn có không có thói quen nào đang hoạt động';

  @override
  String get noHabitsLeftToDo => 'Bạn đã xong tất cả cho ngày hôm nay!';

  @override
  String get longPressToToggle => 'Nhấn giữ để đánh dấu hoặc bỏ đánh dấu';

  @override
  String get reminderOff => 'Tắt';

  @override
  String get createHabit => 'Tạo thói quen';

  @override
  String get editHabit => 'Chỉnh sửa thói quen';

  @override
  String get check => 'Đánh dấu';

  @override
  String get snooze => 'Lúc khác';

  @override
  String get introTitle1 => 'Chào mừng';

  @override
  String get introDescription1 =>
      'Theo dõi thói quen Loop giúp bạn tạo ra và duy trì những thói quen tốt.';

  @override
  String get introTitle2 => 'Tạo một số thói quen mới';

  @override
  String get introDescription2 =>
      'Mỗi ngày, sau khi thực hiện các thói quen của bạn, hãy đánh dấu vào ứng dụng.';

  @override
  String get introTitle4 => 'Theo dõi quá trình của bạn';

  @override
  String get introDescription4 =>
      'Đồ thị chi tiết cho bạn thấy các thói quen của bạn được cải thiện như thế nào theo thời gian.';

  @override
  String get interval15Minutes => '15 phút';

  @override
  String get interval30Minutes => '30 phút';

  @override
  String get interval1Hour => '1 giờ';

  @override
  String get interval2Hour => '2 giờ';

  @override
  String get interval4Hour => '4 giờ';

  @override
  String get interval8Hour => '8 giờ';

  @override
  String get interval24Hour => '24 giờ';

  @override
  String get intervalAlwaysAsk => 'Luôn hỏi';

  @override
  String get intervalCustom => 'Tùy chỉnh...';

  @override
  String get prefToggleTitle => 'Bấm nhanh để chuyển trạng thái';

  @override
  String get prefToggleDescription2 =>
      'Đặt dấu kiểm bằng một lần nhấn thay vì nhấn và giữ.';

  @override
  String get prefRateThisApp => 'Đánh giá ứng dụng trên Google Play';

  @override
  String get prefSendFeedback => 'Gửi phản hồi cho nhà phát triển';

  @override
  String get prefViewSourceCode => 'Xem mã nguồn trên Github';

  @override
  String get links => 'Liên kết';

  @override
  String get name => 'Tên';

  @override
  String get settings => 'Cài đặt';

  @override
  String get selectSnoozeDelay => 'Chọn độ trễ báo lại';

  @override
  String get hintTitle => 'Bạn có biết?';

  @override
  String get hintDrag =>
      'Để sắp xếp lại các mục, nhấn giữ tên thói quen, sau đó kéo tới vị trí chính xác.';

  @override
  String get hintLandscape =>
      'Bạn có thể xoay ngang điện thoại để xem được nhiều ngày hơn.';

  @override
  String get habitNotFound => 'Thói quen đã bị xoá hoặc không tìm thấy';

  @override
  String get weekends => 'Cuối tuần';

  @override
  String get anyWeekday => 'Thứ hai đến thứ sáu';

  @override
  String get anyDay => 'Tất cả các ngày trong tuần';

  @override
  String get selectWeekdays => 'Chọn ngày';

  @override
  String get exportToCsv => 'Xuất dưới dạng CSV';

  @override
  String get doneLabel => 'Xong';

  @override
  String get clearLabel => 'Xoá';

  @override
  String get selectHours => 'Chọn giờ';

  @override
  String get selectMinutes => 'Chọn phút';

  @override
  String get about => 'Giới thiệu';

  @override
  String get translators => 'Dịch giả';

  @override
  String get developers => 'Nhà phát triển';

  @override
  String versionN(String p1) {
    return 'Phiên bản $p1';
  }

  @override
  String get frequency => 'Tần suất';

  @override
  String get checkmark => 'Đánh dấu';

  @override
  String get checkmarkStackWidget => 'Checkmark Stack Widget';

  @override
  String get frequencyStackWidget => 'Frequency Stack Widget';

  @override
  String get scoreStackWidget => 'Score Stack Widget';

  @override
  String get historyStackWidget => 'History Stack Widget';

  @override
  String get streaksStackWidget => 'Streaks Stack Widget';

  @override
  String get bestStreaks => 'Chuỗi dài nhất';

  @override
  String get everyDay => 'Hàng ngày';

  @override
  String get everyWeek => 'Hàng tuần';

  @override
  String get help => 'Trợ giúp & Câu hỏi';

  @override
  String get couldNotExport => 'Xuất dữ liệu thất bại.';

  @override
  String get couldNotImport => 'Nhập dữ liệu thất bại.';

  @override
  String get fileNotRecognized => 'Không nhận ra được tệp.';

  @override
  String get habitsImported => 'Thói quen được nhập thành công.';

  @override
  String get importData => 'Nhập dữ liệu';

  @override
  String get exportFullBackup => 'Xuất bản sao lưu đầy đủ';

  @override
  String get importDataSummary =>
      'Hỗ trợ các bản sao lưu đầy đủ được xuất ra bởi ứng dụng, cũng như các file được tạo bởi Tickmate, HabitBull hoặc Rewire. Xem FAQ để biết thêm thông tin.';

  @override
  String get exportAsCsvSummary =>
      'Tạo ra các tệp có thể được mở bằng các phần mềm bảng tính như Microsoft Excel hoặc OpenOffice Calc. Tệp này không thể được nhập lại.';

  @override
  String get exportFullBackupSummary =>
      'Tạo ra một tệp chứa tất cả dữ liệu của bạn. Tệp này có thể nhập lại.';

  @override
  String get selectPublicBackupFolder => 'Chọn thư mục sao lưu công khai';

  @override
  String get noPublicBackupFolderSelected => 'Không có thư mục nào được chọn';

  @override
  String get bugReportFailed => 'Tạo báo cáo về lỗi.';

  @override
  String get generateBugReport => 'Tạo báo cáo lỗi';

  @override
  String get troubleshooting => 'Xử lí sự cố';

  @override
  String get helpTranslate => 'Giúp dịch ứng dụng';

  @override
  String get nightMode => 'Chế độ ban đêm';

  @override
  String get usePureBlack => 'Sử dụng màu đen thuần trong chế độ ban đêm';

  @override
  String get pureBlackDescription =>
      'Thay thế nền màu xám bởi màu đen thuần trong chế độ ban đêm. Giảm thiểu việc sử dụng pin của điện thoại có màn hình AMOLED.';

  @override
  String get interfacePreferences => 'Giao diện';

  @override
  String get reverseDays => 'Đảo ngược thứ tự của ngày';

  @override
  String get reverseDaysDescription =>
      'Hiển thị ngày ngược trên màn hình chính';

  @override
  String get day => 'Ngày';

  @override
  String get week => 'Tuần';

  @override
  String get month => 'Tháng';

  @override
  String get quarter => 'Quý';

  @override
  String get year => 'Năm';

  @override
  String get total => 'Tổng';

  @override
  String get yesOrNo => 'Có hay không';

  @override
  String everyXDays(int p1) {
    return 'Mỗi $p1 ngày';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Mỗi $p1 tuần';
  }

  @override
  String get score => 'Điểm';

  @override
  String get reminderSound => 'Âm báo';

  @override
  String get none => 'Không có';

  @override
  String get filter => 'Lọc';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Ẩn mục đã hoàn thành';

  @override
  String get hideEntered => 'Ẩn đã nhập';

  @override
  String get hideArchived => 'Ẩn mục đã lưu trữ';

  @override
  String get stickyNotifications => 'Gửi thông báo cố định';

  @override
  String get stickyNotificationsDescription =>
      'Không cho các thông báo bị vuốt ngang mất.';

  @override
  String get ledNotifications => 'Đèn báo';

  @override
  String get ledNotificationsDescription =>
      'Hiển thị đèn nhấp nháy cho lời nhắc. Chỉ có sẵn trong điện thoại có đèn thông báo LED.';

  @override
  String get repairDatabase => 'Sửa cơ sở dữ liệu';

  @override
  String get databaseRepaired => 'Cơ sở dữ liệu đã được sửa.';

  @override
  String get uncheck => 'Bỏ đánh dấu';

  @override
  String get toggle => 'Bật/tắt';

  @override
  String get action => 'Hành động';

  @override
  String get habit => 'Thói quen';

  @override
  String get sort => 'Sắp xếp';

  @override
  String get manually => 'Thủ công';

  @override
  String get byName => 'Theo tên';

  @override
  String get byColor => 'Theo màu sắc';

  @override
  String get byScore => 'Theo điểm số';

  @override
  String get byStatus => 'Theo trạng thái';

  @override
  String get export => 'Xuất dữ liệu ra';

  @override
  String get longPressToEdit => 'Nhấn và giữ để thay đổi giá trị';

  @override
  String get value => 'Giá trị';

  @override
  String get calendar => 'Lịch';

  @override
  String get unit => 'Đơn vị';

  @override
  String get targetType => 'Loại mục tiêu';

  @override
  String get targetTypeAtLeast => 'Ít nhất';

  @override
  String get targetTypeAtMost => 'Nhiều nhất';

  @override
  String get exampleQuestionBoolean => 'v.d. Hôm nay bạn đã tập thể dục chưa?';

  @override
  String get question => 'Câu hỏi';

  @override
  String get target => 'Mục tiêu';

  @override
  String get yes => 'Có';

  @override
  String get no => 'Không';

  @override
  String get customizeNotificationSummary =>
      'Thay đổi âm thanh, độ rung, ánh sáng và các cài đặt thông báo khác';

  @override
  String get customizeNotification => 'Tùy chỉnh thông báo';

  @override
  String get prefViewPrivacy => 'Xem chính sách bảo mật';

  @override
  String get viewAllContributors => 'Xem tất cả những người đóng góp…';

  @override
  String get database => 'Cơ sở dữ liệu';

  @override
  String get widgetOpacityTitle => 'Độ mờ của tiện ích';

  @override
  String get widgetOpacityDescription =>
      'Làm cho các tiện ích trong suốt hơn hoặc mờ hơn trên màn hình chính của bạn.';

  @override
  String get firstDayOfTheWeek => 'Ngày đầu tiên trong tuần';

  @override
  String get defaultReminderQuestion =>
      'Bạn đã hoàn thành thói quen này hôm nay chưa?';

  @override
  String get notes => 'Ghi chú';

  @override
  String get exampleNotes => '(Không bắt buộc)';

  @override
  String get yesOrNoExample =>
      'Ví dụ: Hôm nay bạn có dậy sớm không? Bạn có tập thể dục? Bạn có chơi cờ vua không?';

  @override
  String get measurable => 'Có thể đo lường';

  @override
  String get measurableExample =>
      'Ví dụ: Hôm nay bạn đã chạy bao nhiêu dặm? Bạn đã đọc bao nhiêu trang?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 lần mỗi tuần';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 lần mỗi tháng';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 lần trong $p2 ngày';
  }

  @override
  String get yesOrNoShortExample => 'Ví dụ: Tập thể dục';

  @override
  String get color => 'Màu sắc';

  @override
  String get exampleTarget => 'Ví dụ: 15';

  @override
  String get measurableShortExample => 'Ví dụ: Chạy';

  @override
  String get measurableQuestionExample =>
      'Ví dụ: Bao nhiêu dặm bạn đã chạy ngày hôm nay?';

  @override
  String get measurableUnitsExample => 'Ví dụ: Dặm';

  @override
  String get everyMonth => 'Hàng tháng';

  @override
  String get validationCannotBeBlank => 'Không thể để trống';

  @override
  String get today => 'Hôm nay';

  @override
  String get enter => 'Nhập';

  @override
  String get noHabits => 'Không tìm thấy thói quen nào';

  @override
  String get noNumericalHabits =>
      'Không tìm thấy thói quen có thể đo lường nào';

  @override
  String get noBooleanHabits => 'Không tìm thấy thói quen có hoặc không nào';

  @override
  String get increment => 'Tăng lên';

  @override
  String get decrement => 'Giảm xuống';

  @override
  String get prefSkipTitle => 'Bật bỏ qua ngày';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Bật/tắt hai lần để thêm một lần bỏ qua thay vì dấu kiểm. Bỏ qua giữ cho số điểm của bạn không thay đổi và không phá vỡ chuỗi của bạn.';

  @override
  String get prefUnknownTitle => 'Hiện dấu hỏi cho dữ liệu bị thiếu';

  @override
  String get prefUnknownDescription =>
      'Phân biệt những ngày không có dữ liệu với những lần trôi đi thực tế. Để nhập một lần trôi đi, hãy bật/tắt hai lần.';

  @override
  String get youAreNowADeveloper => 'Bạn đã là nhà phát triển';

  @override
  String get activityNotFound =>
      'Không tìm thấy ứng dụng nào để hỗ trợ hành động này';

  @override
  String get prefMidnightDelayTitle =>
      'Kéo dài ngày thêm một vài giờ sau nửa đêm';

  @override
  String get prefMidnightDelayDescription =>
      'Chờ đến 3:00 sáng để hiện một ngày mới. Rất hữu ích nếu bạn thường đi ngủ sau nửa đêm. Yêu cầu khởi động lại ứng dụng.';

  @override
  String get prefAnimationsTitle => 'Disable animations';

  @override
  String get prefAnimationsDescription =>
      'Disable confetti animation after adding a checkmark.';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thói quen đã được thay đổi',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thói quen đã bị xóa',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thói quen đã được lưu trữ',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thói quen đã bị huỷ lưu trữ',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Xoá thói quen?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Thói quen sẽ bị xoá vĩnh viễn. Hành động này không thể được hoàn tác.',
    );
    return '$_temp0';
  }

  @override
  String get sleepLastNight => 'Last night';

  @override
  String get sleepBedtime => 'Bedtime';

  @override
  String get sleepWakeTime => 'Wake time';

  @override
  String get sleepDuration => 'Sleep';

  @override
  String get sleepNights => 'Nights';

  @override
  String get sleepStability => 'Stability';

  @override
  String get sleepNoData => 'No data yet';

  @override
  String sleepSpreadMinutes(String minutes) {
    return '±$minutes min';
  }

  @override
  String sleepSkippedCount(int skipped, int days) {
    return '$skipped of $days days skipped';
  }

  @override
  String get sleepMarkSkipped => 'Mark';

  @override
  String sleepLastSkipped(String date) {
    return 'Last: $date';
  }

  @override
  String get sleepWeakestSleep =>
      'Went to bed and got up on time, but slept less than the goal.';

  @override
  String get sleepWeakestBed =>
      'Slept enough and got up on time, but went to bed off schedule.';

  @override
  String get sleepWeakestWake =>
      'Slept enough and went to bed on time, but got up off schedule.';

  @override
  String get sleepPerfectNight => 'On schedule and slept enough.';

  @override
  String get sleepQuestionExample => 'e.g. How did you sleep last night?';

  @override
  String get sleepSkipThisDay => 'Skip this day';

  @override
  String get sleepSkipExplained =>
      'Recorded, but not counted for or against you.';

  @override
  String get sleepTargetBedtime => 'Target bedtime';

  @override
  String get sleepTargetWakeTime => 'Target wake time';

  @override
  String get sleepMinimumSleep => 'Minimum sleep';

  @override
  String get sleepHomeTimezone => 'Home time zone';

  @override
  String get sleepAdaptationRate => 'Adaptation';

  @override
  String sleepAdaptationPerDay(int minutes) {
    return '$minutes min per day';
  }

  @override
  String get sleepEnterNight => 'Enter night';

  @override
  String get sleepActuallyAsleep => 'Actually asleep';

  @override
  String get sleepHealthAccess => 'Allow access to Health';

  @override
  String get sleepHealthDenied =>
      'Without access to Health, nights have to be entered by hand.';

  @override
  String sleepSuggestGoalBed(String time) {
    return 'You have been going to bed around $time. Move the goal?';
  }

  @override
  String sleepSuggestGoalWake(String time) {
    return 'You have been getting up around $time. Move the goal?';
  }

  @override
  String get sleepSuggestSkip =>
      'Your time zone changed. Mark these days as skipped?';

  @override
  String get sleepSuggestApply => 'Move';

  @override
  String get sleepSuggestDismiss => 'Not now';

  @override
  String get sleepSkipped => 'Skipped';

  @override
  String get sleepHabitType => 'Sleep';

  @override
  String get sleepHabitTypeExample =>
      'e.g. Go to bed at 23:00, get up at 07:00, and sleep at least 7:30 — scored from Health or entered by hand.';

  @override
  String get sleepAdvanced => 'Advanced';

  @override
  String get sleepWeightSleep => 'Weight: sleep';

  @override
  String get sleepWeightBed => 'Weight: bedtime';

  @override
  String get sleepWeightWake => 'Weight: wake time';

  @override
  String get sleepHalfCreditTime => 'Half credit at (times)';

  @override
  String get sleepHalfCreditSleep => 'Half credit at (sleep)';

  @override
  String sleepMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimezoneOffset(String sign, String hours, String minutes) {
    return 'UTC$sign$hours:$minutes';
  }

  @override
  String get abstinenceHabitType => 'Abstinence';

  @override
  String get abstinenceHabitTypeExample =>
      'e.g. No alcohol. No doomscrolling. Silence is a clean day — you only mark the days you slipped.';

  @override
  String get abstinenceQuestionExample => 'e.g. Did you slip today?';

  @override
  String get abstinenceAllowance => 'Allowance';

  @override
  String get abstinenceAllowanceExample => 'e.g. 30';

  @override
  String get abstinenceAllowanceUnit => 'Counted in';

  @override
  String get abstinenceAllowanceUnitExample => 'e.g. minutes';

  @override
  String get abstinenceCommittedFrom => 'Committed since';

  @override
  String abstinenceSince(String date) {
    return 'Since $date';
  }

  @override
  String abstinenceLastLapse(String date) {
    return 'Last lapse: $date';
  }

  @override
  String get abstinenceLapseToday => 'I lapsed today';

  @override
  String get abstinenceUndoToday => 'Undo today';

  @override
  String get abstinenceGoalNever => 'Not once';

  @override
  String abstinenceAmountPrompt(String allowance, String unit) {
    return 'No more than $allowance $unit a day';
  }

  @override
  String abstinenceAmountPromptNoUnit(String allowance) {
    return 'No more than $allowance a day';
  }

  @override
  String abstinenceDurationYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String get abstinenceOfRecord => 'of the record';

  @override
  String get abstinenceOfPrevious => 'of the previous run';

  @override
  String get abstinenceIsRecord => 'record';

  @override
  String get abstinenceLapsesTotal => 'lapses';
}
