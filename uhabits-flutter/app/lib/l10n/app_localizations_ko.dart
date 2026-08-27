// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get overview => '한눈에 보기';

  @override
  String get appName => 'Loop 습관제조기';

  @override
  String get mainActivityTitle => '습관';

  @override
  String get actionSettings => '설정';

  @override
  String get edit => '수정';

  @override
  String get delete => '삭제';

  @override
  String get archive => '보관';

  @override
  String get unarchive => '보관 해제';

  @override
  String get addHabit => '습관 추가하기';

  @override
  String get colorPickerDefaultTitle => '색상 변경';

  @override
  String get toastHabitCreated => '습관이 생성되었습니다.';

  @override
  String get habitStrength => '습관 강도';

  @override
  String get history => '이력';

  @override
  String get clear => '취소';

  @override
  String get reminder => '알림';

  @override
  String get save => '저장';

  @override
  String get streaks => '연속';

  @override
  String get noHabitsFound => '활성화된 습관이 없습니다.';

  @override
  String get noHabitsLeftToDo => '오늘 할 일을 모두 마쳤습니다';

  @override
  String get longPressToToggle => '체크하거나 해제하려면 길게 누르세요.';

  @override
  String get reminderOff => '끔';

  @override
  String get createHabit => '습관 만들기';

  @override
  String get editHabit => '습관 수정하기';

  @override
  String get check => '완료';

  @override
  String get snooze => '나중에';

  @override
  String get introTitle1 => '환영합니다';

  @override
  String get introDescription1 => 'Loop은 당신이 좋은 습관을 만들고 유지하도록 도와줍니다.';

  @override
  String get introTitle2 => '새로운 습관을 만들어 보세요.';

  @override
  String get introDescription2 => '매일 습관을 수행하고 앱에 기록하세요.';

  @override
  String get introTitle4 => '습관을 관리하세요';

  @override
  String get introDescription4 => '자세한 그래프로 시간에 따라 당신의 습관이 어떻게 향상되었는지 보여줍니다.';

  @override
  String get interval15Minutes => '15분';

  @override
  String get interval30Minutes => '30분';

  @override
  String get interval1Hour => '1시간';

  @override
  String get interval2Hour => '2시간';

  @override
  String get interval4Hour => '4시간';

  @override
  String get interval8Hour => '8시간';

  @override
  String get interval24Hour => '24시간';

  @override
  String get intervalAlwaysAsk => '항상 묻기';

  @override
  String get intervalCustom => '사용자 지정...';

  @override
  String get prefToggleTitle => '짧게 눌러서 전환하기';

  @override
  String get prefToggleDescription2 => '길게 누르는 대신 탭 한 번으로 확인 표시를 합니다.';

  @override
  String get prefRateThisApp => 'Google Play에서 평가';

  @override
  String get prefSendFeedback => '개발자에게 피드백 보내기';

  @override
  String get prefViewSourceCode => 'Github에서 소스 보기';

  @override
  String get links => '링크';

  @override
  String get name => '제목';

  @override
  String get settings => '설정';

  @override
  String get selectSnoozeDelay => '일시중지 시간 설정';

  @override
  String get hintTitle => '아시나요?';

  @override
  String get hintDrag => '목록의 순서를 재배치하려면, 습관의 제목을 길게 누르고 다른 위치로 드래그하면 됩니다.';

  @override
  String get hintLandscape => '가로 모드에서는 더 많은 날짜를 볼 수 있습니다.';

  @override
  String get habitNotFound => '습관 삭제 / 찾을 수 없음';

  @override
  String get weekends => '주말';

  @override
  String get anyWeekday => '주중';

  @override
  String get anyDay => '매일';

  @override
  String get selectWeekdays => '요일 선택';

  @override
  String get exportToCsv => 'CSV로 내보내기';

  @override
  String get doneLabel => '완료';

  @override
  String get clearLabel => '지우기';

  @override
  String get selectHours => '시간 선택';

  @override
  String get selectMinutes => '분 선택';

  @override
  String get about => '정보';

  @override
  String get translators => '번역한 사람들';

  @override
  String get developers => '개발자';

  @override
  String versionN(String p1) {
    return '버전 $p1';
  }

  @override
  String get frequency => '빈도';

  @override
  String get checkmark => '체크';

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
  String get bestStreaks => '최고 연속 기록';

  @override
  String get everyDay => '매일';

  @override
  String get everyWeek => '매주';

  @override
  String get help => '도움 & FAQ';

  @override
  String get couldNotExport => '데이터 내보내기에 실패했습니다.';

  @override
  String get couldNotImport => '데이터 가져오기에 실패했습니다.';

  @override
  String get fileNotRecognized => '파일을 인식할 수 없습니다.';

  @override
  String get habitsImported => '습관 가져오기에 성공했습니다.';

  @override
  String get importData => '데이터 가져오기';

  @override
  String get exportFullBackup => '백업 내보내기';

  @override
  String get importDataSummary =>
      'Tickmate, HabitBull, Rewire에서 생성된 파일도 지원합니다. 더 자세한 설명은 FAQ에 있습니다.';

  @override
  String get exportAsCsvSummary =>
      'Microsoft Excel나 OpenOffice Calc 같은 스프레드시트 소프트웨어로 열 수 있는 파일을 생성합니다. 이 파일은 다시 가져올 수 없습니다.';

  @override
  String get exportFullBackupSummary =>
      '모든 데이터를 포함한 파일을 생성합니다. 이 파일은 다시 가져올 수 있습니다.';

  @override
  String get selectPublicBackupFolder => '공용 백업 폴더 선택';

  @override
  String get noPublicBackupFolderSelected => '선택된 폴더가 없습니다';

  @override
  String get bugReportFailed => '오류보고서 작성에 실패했습니다.';

  @override
  String get generateBugReport => '오류보고서 작성하기';

  @override
  String get troubleshooting => '문제 해결';

  @override
  String get helpTranslate => '이 앱의 번역을 도와주세요';

  @override
  String get nightMode => '야간 모드';

  @override
  String get usePureBlack => '야간 모드에서 검정색 사용하기';

  @override
  String get pureBlackDescription =>
      '야간 모드의 회색 배경을 검정색으로 대체합니다. AMOLED 디스플레이를 사용하는 기기에서 배터리 사용량을 감소시킵니다.';

  @override
  String get interfacePreferences => '인터페이스';

  @override
  String get reverseDays => '날짜 순서 뒤집기';

  @override
  String get reverseDaysDescription => '메인 화면의 날짜를 역순으로 보여줍니다.';

  @override
  String get day => '일';

  @override
  String get week => '주';

  @override
  String get month => '월';

  @override
  String get quarter => '분기';

  @override
  String get year => '년';

  @override
  String get total => '전체';

  @override
  String get yesOrNo => '예 또는 아니요';

  @override
  String everyXDays(int p1) {
    return '$p1일 마다';
  }

  @override
  String everyXWeeks(int p1) {
    return '$p1주 마다';
  }

  @override
  String get score => '점수';

  @override
  String get reminderSound => '알림음';

  @override
  String get none => '무음';

  @override
  String get filter => '필터';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => '완료된 항목 숨기기';

  @override
  String get hideEntered => '입력한 항목을 숨기기';

  @override
  String get hideArchived => '보관된 항목 숨기기';

  @override
  String get stickyNotifications => '알림 고정하기';

  @override
  String get stickyNotificationsDescription => '알림을 스와이프해서 제거하는 것을 방지합니다.';

  @override
  String get ledNotifications => '알림 표시등';

  @override
  String get ledNotificationsDescription =>
      '리마인더가 있으면알림 표시등이 깜박입니다. LED 알림 표시등이있는 전화기에서만 사용할 수 있습니다.';

  @override
  String get repairDatabase => '데이터베이스 복구';

  @override
  String get databaseRepaired => '데이터베이스가 복구되었습니다.';

  @override
  String get uncheck => '선택 해제';

  @override
  String get toggle => '전환';

  @override
  String get action => '동작';

  @override
  String get habit => '습관';

  @override
  String get sort => '정렬';

  @override
  String get manually => '수동으로';

  @override
  String get byName => '이름 순으로';

  @override
  String get byColor => '색상 순으로';

  @override
  String get byScore => '점수 순으로';

  @override
  String get byStatus => '상태별로';

  @override
  String get export => '내보내기';

  @override
  String get longPressToEdit => '길게 누르면 값이 변경됩니다.';

  @override
  String get value => '값';

  @override
  String get calendar => '캘린더';

  @override
  String get unit => '단위';

  @override
  String get targetType => '목표 유형';

  @override
  String get targetTypeAtLeast => '적어도';

  @override
  String get targetTypeAtMost => '최대';

  @override
  String get exampleQuestionBoolean => '예 : 오늘 운동을 했습니까?';

  @override
  String get question => '질문';

  @override
  String get target => '목표';

  @override
  String get yes => '네';

  @override
  String get no => '아니요';

  @override
  String get customizeNotificationSummary => '소리, 진동, 밝기 및 기타 알림 설정';

  @override
  String get customizeNotification => '알림 커스터마이징';

  @override
  String get prefViewPrivacy => '개인 정보 취급 방침 보기';

  @override
  String get viewAllContributors => '모든 기여자보기…';

  @override
  String get database => '데이터베이스';

  @override
  String get widgetOpacityTitle => '위젯 투명도';

  @override
  String get widgetOpacityDescription => '위젯을 홈 화면에서 더 투명하게 또는 더 불투명하게 합니다.';

  @override
  String get firstDayOfTheWeek => '첫번째 요일';

  @override
  String get defaultReminderQuestion => '오늘 습관을 지키셨나요?';

  @override
  String get notes => '메모';

  @override
  String get exampleNotes => '(선택사항)';

  @override
  String get yesOrNoExample => '예) 오늘 일찍 일어났나요? 운동 하셨나요? 체스를 하셨나요?';

  @override
  String get measurable => '측정 가능한';

  @override
  String get measurableExample => '예) 오늘 몇 마일을 달렸습니까? 몇 페이지를 읽었습니까?';

  @override
  String xTimesPerWeek(int p1) {
    return '일주일에 몇 번';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '한 달에 몇 번';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 번 $p2 일 동안';
  }

  @override
  String get yesOrNoShortExample => '예) 운동';

  @override
  String get color => '색';

  @override
  String get exampleTarget => '예) 15';

  @override
  String get measurableShortExample => '예) 달리기';

  @override
  String get measurableQuestionExample => '예) 오늘 몇 km를 달렸나요?';

  @override
  String get measurableUnitsExample => '예) km';

  @override
  String get everyMonth => '매월';

  @override
  String get validationCannotBeBlank => '비워 둘 수 없습니다';

  @override
  String get today => '오늘';

  @override
  String get enter => '입력';

  @override
  String get noHabits => '설정한 습관이 없습니다';

  @override
  String get noNumericalHabits => '수치형 습관 목표가 없습니다';

  @override
  String get noBooleanHabits => '단답형 습관 목표가 없습니다';

  @override
  String get increment => '증가';

  @override
  String get decrement => '감소';

  @override
  String get prefSkipTitle => '날짜 스킵 허용';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      '두번 토글하면, 확인 표시 대신에 해당 일자의 기록을 제외합니다. 제외된 날은 점수에 반영되지 않고, 연속 기록도 유지됩니다.';

  @override
  String get prefUnknownTitle => '기록이 없는 날에 물음표 표시';

  @override
  String get prefUnknownDescription =>
      '데이터가 없는 날과 넘겼다고 실제로 기록한 날에 차이를 둡니다. 넘겼다고 기록하려면 두 번 누르세요.';

  @override
  String get youAreNowADeveloper => '당신은 이제 개발자입니다.';

  @override
  String get activityNotFound => '이 작업을 지원하는 앱을 찾을 수 없습니다.';

  @override
  String get prefMidnightDelayTitle => '하루를 자정 이후까지 연장합니다.';

  @override
  String get prefMidnightDelayDescription =>
      '오전 3시를 기점으로 하루가 변경됩니다. 자정 이후 잠드는 경우 유용합니다. 변경시 앱 재시작 후 적용됩니다.';

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
      other: '습관이 변경되었습니다',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '습관이 삭제되었습니다',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '습관이 보관 되었습니다',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '습관 보관이 취소되었습니다',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '습관을 삭제하시겠습니까?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '습관을 영구적으로 삭제합니다. 삭제 후 취소할 수 없습니다.',
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
  String get abstinenceTitle => 'Without a lapse';

  @override
  String abstinenceCleanDaysLabel(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'days without a lapse',
      one: 'day without a lapse',
    );
    return '$_temp0';
  }

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
  String abstinenceAmountPrompt(String allowance, String unit) {
    return 'No more than $allowance $unit a day';
  }

  @override
  String abstinenceAmountPromptNoUnit(String allowance) {
    return 'No more than $allowance a day';
  }
}
