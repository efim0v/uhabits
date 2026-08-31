// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get overview => '总览';

  @override
  String get appName => 'Loop 习惯记录';

  @override
  String get mainActivityTitle => '习惯';

  @override
  String get actionSettings => '设置';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get archive => '存档';

  @override
  String get unarchive => '取消存档';

  @override
  String get addHabit => '添加新习惯';

  @override
  String get colorPickerDefaultTitle => '选择颜色';

  @override
  String get toastHabitCreated => '习惯已创建';

  @override
  String get habitStrength => '习惯强度';

  @override
  String get history => '历史';

  @override
  String get clear => '取消';

  @override
  String get reminder => '提醒';

  @override
  String get save => '保存';

  @override
  String get streaks => '连续完成次数';

  @override
  String get noHabitsFound => '你还没有任何习惯';

  @override
  String get noHabitsLeftToDo => '你已经完成了今天所有的习惯！';

  @override
  String get longPressToToggle => '长按 标记/取消标记';

  @override
  String get reminderOff => '关闭';

  @override
  String get createHabit => '新建习惯';

  @override
  String get editHabit => '编辑习惯';

  @override
  String get check => '打卡';

  @override
  String get snooze => '稍后提醒';

  @override
  String get introTitle1 => '欢迎';

  @override
  String get introDescription1 => 'Loop 习惯记录能帮你养成和保持好习惯。';

  @override
  String get introTitle2 => '养成一些新习惯';

  @override
  String get introDescription2 => '每当你完成一项习惯后，就在应用上做一个标记';

  @override
  String get introTitle4 => '记录你的进步';

  @override
  String get introDescription4 => '详细图表展示长期以来习惯养成情况';

  @override
  String get interval15Minutes => '15 分钟';

  @override
  String get interval30Minutes => '30 分钟';

  @override
  String get interval1Hour => '1 小时';

  @override
  String get interval2Hour => '2 小时';

  @override
  String get interval4Hour => '4 小时';

  @override
  String get interval8Hour => '8 小时';

  @override
  String get interval24Hour => '24 小时';

  @override
  String get intervalAlwaysAsk => '总是询问';

  @override
  String get intervalCustom => '自定义';

  @override
  String get prefToggleTitle => '短按切换';

  @override
  String get prefToggleDescription2 => '只需点击一下即可打卡，而不是长按。';

  @override
  String get prefRateThisApp => '去 Play 商店评价此应用';

  @override
  String get prefSendFeedback => '发送反馈给开发者';

  @override
  String get prefViewSourceCode => '在 GitHub 上查看源代码';

  @override
  String get links => '链接';

  @override
  String get name => '习惯标题';

  @override
  String get settings => '设置';

  @override
  String get selectSnoozeDelay => '设定稍后提醒的时间间隔';

  @override
  String get hintTitle => '你知道吗？';

  @override
  String get hintDrag => '如果要重新排列习惯，按住习惯的名字拖到想要的位置';

  @override
  String get hintLandscape => '转至横屏查看更多日期';

  @override
  String get habitNotFound => '习惯已删/找不到';

  @override
  String get weekends => '周末';

  @override
  String get anyWeekday => '工作日';

  @override
  String get anyDay => '每天';

  @override
  String get selectWeekdays => '选择天数';

  @override
  String get exportToCsv => '导出为 CSV';

  @override
  String get doneLabel => '完成';

  @override
  String get clearLabel => '取消';

  @override
  String get selectHours => '选择小时';

  @override
  String get selectMinutes => '选择分钟';

  @override
  String get about => '关于应用';

  @override
  String get translators => '翻译者';

  @override
  String get developers => '开发者';

  @override
  String versionN(String p1) {
    return '当前版本：$p1';
  }

  @override
  String get frequency => '频率';

  @override
  String get checkmark => '标记';

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
  String get bestStreaks => '最佳连续完成次数';

  @override
  String get everyDay => '每天';

  @override
  String get everyWeek => '每周';

  @override
  String get help => '帮助 & 常见问题';

  @override
  String get couldNotExport => '导出数据失败';

  @override
  String get couldNotImport => '导入数据失败';

  @override
  String get fileNotRecognized => '无法识别文件';

  @override
  String get habitsImported => '习惯导入成功';

  @override
  String get importData => '导入数据';

  @override
  String get exportFullBackup => '导出完整备份';

  @override
  String get importDataSummary =>
      '支持本应用导出的完整备份文件，也支持 Tickmate、HabitBull 或 Rewire 的导出文件，请参阅常见问题以获取更多信息。';

  @override
  String get exportAsCsvSummary =>
      '生成可以通过电子表格软件打开的文件，如 Microsoft Excel 或 OpenOffice Calc。该文件无法重新导入。';

  @override
  String get exportFullBackupSummary => '生成一个包含所有数据的文件。该文件可以重新导入。';

  @override
  String get selectPublicBackupFolder => '选择公共备份文件夹';

  @override
  String get noPublicBackupFolderSelected => '未选择文件夹';

  @override
  String get bugReportFailed => '错误报告生成失败';

  @override
  String get generateBugReport => '生成错误报告';

  @override
  String get troubleshooting => '故障排除';

  @override
  String get helpTranslate => '帮助翻译本应用';

  @override
  String get nightMode => '深色主题';

  @override
  String get usePureBlack => '在深色主题中使用纯黑色';

  @override
  String get pureBlackDescription =>
      '以纯黑色背景代替深色主题中的灰色背景。\n这可以降低 AMOLED 屏幕手机的耗电量。';

  @override
  String get interfacePreferences => '界面';

  @override
  String get reverseDays => '逆序显示日期';

  @override
  String get reverseDaysDescription => '在主界面以相反的顺序显示日期。';

  @override
  String get day => '天';

  @override
  String get week => '周';

  @override
  String get month => '月';

  @override
  String get quarter => '季度';

  @override
  String get year => '年';

  @override
  String get total => '总数';

  @override
  String get yesOrNo => '完成与否';

  @override
  String everyXDays(int p1) {
    return '每 $p1 天';
  }

  @override
  String everyXWeeks(int p1) {
    return '每 $p1 周';
  }

  @override
  String get score => '成绩';

  @override
  String get reminderSound => '提醒提示音';

  @override
  String get none => '无';

  @override
  String get filter => '筛选';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => '隐藏已完成';

  @override
  String get hideEntered => '隐藏已输入';

  @override
  String get hideArchived => '隐藏已存档';

  @override
  String get stickyNotifications => '使通知持久';

  @override
  String get stickyNotificationsDescription => '防止通知被滑掉。';

  @override
  String get ledNotifications => '呼吸灯';

  @override
  String get ledNotificationsDescription => '有提醒时，呼吸灯会闪烁提示。仅限于有 LED 通知呼吸灯的手机。';

  @override
  String get repairDatabase => '修复数据库';

  @override
  String get databaseRepaired => '数据库已修复';

  @override
  String get uncheck => '取消选中';

  @override
  String get toggle => '切换';

  @override
  String get action => '操作';

  @override
  String get habit => '习惯';

  @override
  String get sort => '排序';

  @override
  String get manually => '手动';

  @override
  String get byName => '按名称';

  @override
  String get byColor => '按颜色';

  @override
  String get byScore => '按分数';

  @override
  String get byStatus => '按状态';

  @override
  String get export => '导出';

  @override
  String get longPressToEdit => '长按即可更改值';

  @override
  String get value => '值';

  @override
  String get calendar => '日历';

  @override
  String get unit => '单位';

  @override
  String get targetType => '目标类型';

  @override
  String get targetTypeAtLeast => '至少';

  @override
  String get targetTypeAtMost => '至多';

  @override
  String get exampleQuestionBoolean => '例如：你今天锻炼了吗？';

  @override
  String get question => '问题';

  @override
  String get target => '目标';

  @override
  String get yes => '完成了';

  @override
  String get no => '未完成';

  @override
  String get customizeNotificationSummary => '更改声音、振动、指示灯（呼吸灯）和其他通知设置';

  @override
  String get customizeNotification => '自定义通知';

  @override
  String get prefViewPrivacy => '查看隐私政策';

  @override
  String get viewAllContributors => '查看所有贡献者';

  @override
  String get database => '数据库';

  @override
  String get widgetOpacityTitle => '微件不透明度';

  @override
  String get widgetOpacityDescription => '调整主屏幕上小部件的不透明度。';

  @override
  String get firstDayOfTheWeek => '一周的第一天';

  @override
  String get defaultReminderQuestion => '你今天完成这个习惯了吗？';

  @override
  String get notes => '备注';

  @override
  String get exampleNotes => '（选填）';

  @override
  String get yesOrNoExample => '例如：你今天早起了吗？你锻炼了吗？你下棋了吗？';

  @override
  String get measurable => '可量化的';

  @override
  String get measurableExample => '例如：今天你跑了几公里？你读了几页书？';

  @override
  String xTimesPerWeek(int p1) {
    return '每周 $p1 次';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '每月 $p1 次';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '每 $p1 天 $p2 次';
  }

  @override
  String get yesOrNoShortExample => '例如：锻炼';

  @override
  String get color => '颜色';

  @override
  String get exampleTarget => '例如：15';

  @override
  String get measurableShortExample => '例如：跑步';

  @override
  String get measurableQuestionExample => '例如：今天你跑了几公里？';

  @override
  String get measurableUnitsExample => '例如：公里';

  @override
  String get everyMonth => '每月';

  @override
  String get validationCannotBeBlank => '不能为空';

  @override
  String get today => '今日';

  @override
  String get enter => '输入';

  @override
  String get noHabits => '找不到习惯';

  @override
  String get noNumericalHabits => '找不到可量化的习惯';

  @override
  String get noBooleanHabits => '找不到“是或不是”类的习惯';

  @override
  String get increment => '增加（+1）';

  @override
  String get decrement => '减少（-1）';

  @override
  String get prefSkipTitle => '启用跳过天数功能';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription => '切换两次以添加跳过而不是复选标记。跳过将保持您的得分不变，且不会打破你的连续纪录';

  @override
  String get prefUnknownTitle => '对丢失的数据显示问号';

  @override
  String get prefUnknownDescription => '区分无数据和未完成习惯的日期。要输入一个习惯未完成，请切换两次。';

  @override
  String get youAreNowADeveloper => '你现在是一个开发者！';

  @override
  String get activityNotFound => '找不到支持此操作的应用';

  @override
  String get prefMidnightDelayTitle => '将一天延长到午夜后的几个小时';

  @override
  String get prefMidnightDelayDescription =>
      '凌晨 3 点后再显示新的一天。如果你通常在午夜后入睡，这会很有用。重启应用后生效。';

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
      other: '习惯已更改',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已删除',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已存档',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已取消存档',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除习惯？',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯将被永久地删除。此操作无法撤消。',
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
  String get abstinenceHabitType => 'Freedom';

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

/// The translations for Chinese, as used in China (`zh_CN`).
class L10nZhCn extends L10nZh {
  L10nZhCn() : super('zh_CN');

  @override
  String get overview => '总览';

  @override
  String get appName => 'Loop 习惯记录';

  @override
  String get mainActivityTitle => '习惯';

  @override
  String get actionSettings => '设置';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get archive => '存档';

  @override
  String get unarchive => '取消存档';

  @override
  String get addHabit => '添加新习惯';

  @override
  String get colorPickerDefaultTitle => '选择颜色';

  @override
  String get toastHabitCreated => '习惯已创建';

  @override
  String get habitStrength => '习惯强度';

  @override
  String get history => '历史';

  @override
  String get clear => '取消';

  @override
  String get reminder => '提醒';

  @override
  String get save => '保存';

  @override
  String get streaks => '连续完成次数';

  @override
  String get noHabitsFound => '你还没有任何习惯';

  @override
  String get noHabitsLeftToDo => '你已经完成了今天所有的习惯！';

  @override
  String get longPressToToggle => '长按 标记/取消标记';

  @override
  String get reminderOff => '关闭';

  @override
  String get createHabit => '新建习惯';

  @override
  String get editHabit => '编辑习惯';

  @override
  String get check => '打卡';

  @override
  String get snooze => '稍后提醒';

  @override
  String get introTitle1 => '欢迎';

  @override
  String get introDescription1 => 'Loop 习惯记录能帮你养成和保持好习惯。';

  @override
  String get introTitle2 => '养成一些新习惯';

  @override
  String get introDescription2 => '每当你完成一项习惯后，就在应用上做一个标记';

  @override
  String get introTitle4 => '记录你的进步';

  @override
  String get introDescription4 => '详细图表展示长期以来习惯养成情况';

  @override
  String get interval15Minutes => '15 分钟';

  @override
  String get interval30Minutes => '30 分钟';

  @override
  String get interval1Hour => '1 小时';

  @override
  String get interval2Hour => '2 小时';

  @override
  String get interval4Hour => '4 小时';

  @override
  String get interval8Hour => '8 小时';

  @override
  String get interval24Hour => '24 小时';

  @override
  String get intervalAlwaysAsk => '总是询问';

  @override
  String get intervalCustom => '自定义';

  @override
  String get prefToggleTitle => '短按切换';

  @override
  String get prefToggleDescription2 => '只需点击一下即可打卡，而不是长按。';

  @override
  String get prefRateThisApp => '去 Play 商店评价此应用';

  @override
  String get prefSendFeedback => '发送反馈给开发者';

  @override
  String get prefViewSourceCode => '在 GitHub 上查看源代码';

  @override
  String get links => '链接';

  @override
  String get name => '习惯标题';

  @override
  String get settings => '设置';

  @override
  String get selectSnoozeDelay => '设定稍后提醒的时间间隔';

  @override
  String get hintTitle => '你知道吗？';

  @override
  String get hintDrag => '如果要重新排列习惯，按住习惯的名字拖到想要的位置';

  @override
  String get hintLandscape => '转至横屏查看更多日期';

  @override
  String get habitNotFound => '习惯已删/找不到';

  @override
  String get weekends => '周末';

  @override
  String get anyWeekday => '工作日';

  @override
  String get anyDay => '每天';

  @override
  String get selectWeekdays => '选择天数';

  @override
  String get exportToCsv => '导出为 CSV';

  @override
  String get doneLabel => '完成';

  @override
  String get clearLabel => '取消';

  @override
  String get selectHours => '选择小时';

  @override
  String get selectMinutes => '选择分钟';

  @override
  String get about => '关于应用';

  @override
  String get translators => '翻译者';

  @override
  String get developers => '开发者';

  @override
  String versionN(String p1) {
    return '当前版本：$p1';
  }

  @override
  String get frequency => '频率';

  @override
  String get checkmark => '标记';

  @override
  String get bestStreaks => '最佳连续完成次数';

  @override
  String get everyDay => '每天';

  @override
  String get everyWeek => '每周';

  @override
  String get help => '帮助 & 常见问题';

  @override
  String get couldNotExport => '导出数据失败';

  @override
  String get couldNotImport => '导入数据失败';

  @override
  String get fileNotRecognized => '无法识别文件';

  @override
  String get habitsImported => '习惯导入成功';

  @override
  String get importData => '导入数据';

  @override
  String get exportFullBackup => '导出完整备份';

  @override
  String get importDataSummary =>
      '支持本应用导出的完整备份文件，也支持 Tickmate、HabitBull 或 Rewire 的导出文件，请参阅常见问题以获取更多信息。';

  @override
  String get exportAsCsvSummary =>
      '生成可以通过电子表格软件打开的文件，如 Microsoft Excel 或 OpenOffice Calc。该文件无法重新导入。';

  @override
  String get exportFullBackupSummary => '生成一个包含所有数据的文件。该文件可以重新导入。';

  @override
  String get selectPublicBackupFolder => '选择公共备份文件夹';

  @override
  String get noPublicBackupFolderSelected => '未选择文件夹';

  @override
  String get bugReportFailed => '错误报告生成失败';

  @override
  String get generateBugReport => '生成错误报告';

  @override
  String get troubleshooting => '故障排除';

  @override
  String get helpTranslate => '帮助翻译本应用';

  @override
  String get nightMode => '深色主题';

  @override
  String get usePureBlack => '在深色主题中使用纯黑色';

  @override
  String get pureBlackDescription =>
      '以纯黑色背景代替深色主题中的灰色背景。\n这可以降低 AMOLED 屏幕手机的耗电量。';

  @override
  String get interfacePreferences => '界面';

  @override
  String get reverseDays => '逆序显示日期';

  @override
  String get reverseDaysDescription => '在主界面以相反的顺序显示日期。';

  @override
  String get day => '天';

  @override
  String get week => '周';

  @override
  String get month => '月';

  @override
  String get quarter => '季度';

  @override
  String get year => '年';

  @override
  String get total => '总数';

  @override
  String get yesOrNo => '完成与否';

  @override
  String everyXDays(int p1) {
    return '每 $p1 天';
  }

  @override
  String everyXWeeks(int p1) {
    return '每 $p1 周';
  }

  @override
  String get score => '成绩';

  @override
  String get reminderSound => '提醒提示音';

  @override
  String get none => '无';

  @override
  String get filter => '筛选';

  @override
  String get hideCompleted => '隐藏已完成';

  @override
  String get hideEntered => '隐藏已输入';

  @override
  String get hideArchived => '隐藏已存档';

  @override
  String get stickyNotifications => '使通知持久';

  @override
  String get stickyNotificationsDescription => '防止通知被滑掉。';

  @override
  String get ledNotifications => '呼吸灯';

  @override
  String get ledNotificationsDescription => '有提醒时，呼吸灯会闪烁提示。仅限于有 LED 通知呼吸灯的手机。';

  @override
  String get repairDatabase => '修复数据库';

  @override
  String get databaseRepaired => '数据库已修复';

  @override
  String get uncheck => '取消选中';

  @override
  String get toggle => '切换';

  @override
  String get action => '操作';

  @override
  String get habit => '习惯';

  @override
  String get sort => '排序';

  @override
  String get manually => '手动';

  @override
  String get byName => '按名称';

  @override
  String get byColor => '按颜色';

  @override
  String get byScore => '按分数';

  @override
  String get byStatus => '按状态';

  @override
  String get export => '导出';

  @override
  String get longPressToEdit => '长按即可更改值';

  @override
  String get value => '值';

  @override
  String get calendar => '日历';

  @override
  String get unit => '单位';

  @override
  String get targetType => '目标类型';

  @override
  String get targetTypeAtLeast => '至少';

  @override
  String get targetTypeAtMost => '至多';

  @override
  String get exampleQuestionBoolean => '例如：你今天锻炼了吗？';

  @override
  String get question => '问题';

  @override
  String get target => '目标';

  @override
  String get yes => '完成了';

  @override
  String get no => '未完成';

  @override
  String get customizeNotificationSummary => '更改声音、振动、指示灯（呼吸灯）和其他通知设置';

  @override
  String get customizeNotification => '自定义通知';

  @override
  String get prefViewPrivacy => '查看隐私政策';

  @override
  String get viewAllContributors => '查看所有贡献者';

  @override
  String get database => '数据库';

  @override
  String get widgetOpacityTitle => '微件不透明度';

  @override
  String get widgetOpacityDescription => '调整主屏幕上小部件的不透明度。';

  @override
  String get firstDayOfTheWeek => '一周的第一天';

  @override
  String get defaultReminderQuestion => '你今天完成这个习惯了吗？';

  @override
  String get notes => '备注';

  @override
  String get exampleNotes => '（选填）';

  @override
  String get yesOrNoExample => '例如：你今天早起了吗？你锻炼了吗？你下棋了吗？';

  @override
  String get measurable => '可量化的';

  @override
  String get measurableExample => '例如：今天你跑了几公里？你读了几页书？';

  @override
  String xTimesPerWeek(int p1) {
    return '每周 $p1 次';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '每月 $p1 次';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '每 $p1 天 $p2 次';
  }

  @override
  String get yesOrNoShortExample => '例如：锻炼';

  @override
  String get color => '颜色';

  @override
  String get exampleTarget => '例如：15';

  @override
  String get measurableShortExample => '例如：跑步';

  @override
  String get measurableQuestionExample => '例如：今天你跑了几公里？';

  @override
  String get measurableUnitsExample => '例如：公里';

  @override
  String get everyMonth => '每月';

  @override
  String get validationCannotBeBlank => '不能为空';

  @override
  String get today => '今日';

  @override
  String get enter => '输入';

  @override
  String get noHabits => '找不到习惯';

  @override
  String get noNumericalHabits => '找不到可量化的习惯';

  @override
  String get noBooleanHabits => '找不到“是或不是”类的习惯';

  @override
  String get increment => '增加（+1）';

  @override
  String get decrement => '减少（-1）';

  @override
  String get prefSkipTitle => '启用跳过天数功能';

  @override
  String get prefSkipDescription => '切换两次以添加跳过而不是复选标记。跳过将保持您的得分不变，且不会打破你的连续纪录';

  @override
  String get prefUnknownTitle => '对丢失的数据显示问号';

  @override
  String get prefUnknownDescription => '区分无数据和未完成习惯的日期。要输入一个习惯未完成，请切换两次。';

  @override
  String get youAreNowADeveloper => '你现在是一个开发者！';

  @override
  String get activityNotFound => '找不到支持此操作的应用';

  @override
  String get prefMidnightDelayTitle => '将一天延长到午夜后的几个小时';

  @override
  String get prefMidnightDelayDescription =>
      '凌晨 3 点后再显示新的一天。如果你通常在午夜后入睡，这会很有用。重启应用后生效。';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已更改',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已删除',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已存档',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯已取消存档',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除习惯？',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '习惯将被永久地删除。此操作无法撤消。',
    );
    return '$_temp0';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class L10nZhTw extends L10nZh {
  L10nZhTw() : super('zh_TW');

  @override
  String get overview => '總覽';

  @override
  String get appName => 'Loop 習以為常';

  @override
  String get mainActivityTitle => '習慣';

  @override
  String get actionSettings => '偏好設定';

  @override
  String get edit => '編輯';

  @override
  String get delete => '刪除';

  @override
  String get archive => '封存';

  @override
  String get unarchive => '取消封存';

  @override
  String get addHabit => '加入新習慣';

  @override
  String get colorPickerDefaultTitle => '選擇顏色';

  @override
  String get toastHabitCreated => '習慣已增加';

  @override
  String get habitStrength => '習慣強度';

  @override
  String get history => '歴史紀錄';

  @override
  String get clear => '清空';

  @override
  String get reminder => '提醒';

  @override
  String get save => '儲存';

  @override
  String get streaks => '記錄';

  @override
  String get noHabitsFound => '你還沒有建立任何習慣';

  @override
  String get noHabitsLeftToDo => '今天預定的任務已全數完成！';

  @override
  String get longPressToToggle => '請以長按來標記或取消標記';

  @override
  String get reminderOff => '關閉';

  @override
  String get createHabit => '新增習慣';

  @override
  String get editHabit => '編輯習慣';

  @override
  String get check => '打勾';

  @override
  String get snooze => '稍後';

  @override
  String get introTitle1 => '歡迎使用';

  @override
  String get introDescription1 => '「Loop 習以為常」可以幫您記錄並培養好習慣。';

  @override
  String get introTitle2 => '開始來建立一些習慣吧';

  @override
  String get introDescription2 => '每天完成你的習慣後，進入 APP 來打個勾吧。';

  @override
  String get introTitle4 => '追蹤您的進度';

  @override
  String get introDescription4 => '詳細的圖表將顯示你的持續進步';

  @override
  String get interval15Minutes => '15 分鐘';

  @override
  String get interval30Minutes => '30 分鐘';

  @override
  String get interval1Hour => '1 小時';

  @override
  String get interval2Hour => '2 小時';

  @override
  String get interval4Hour => '4 小時';

  @override
  String get interval8Hour => '8 小時';

  @override
  String get interval24Hour => '24 小時';

  @override
  String get intervalAlwaysAsk => '每次都詢問';

  @override
  String get intervalCustom => '自訂';

  @override
  String get prefToggleTitle => '換成輕碰來記錄習慣';

  @override
  String get prefToggleDescription2 => '輕碰即可打勾，不需要長按';

  @override
  String get prefRateThisApp => '在 Google Play 上評價這個 App';

  @override
  String get prefSendFeedback => '傳送改進意見給開發者';

  @override
  String get prefViewSourceCode => '在 GitHub 上查看原始碼';

  @override
  String get links => '連結';

  @override
  String get name => '習慣名稱';

  @override
  String get settings => '偏好設定';

  @override
  String get selectSnoozeDelay => '選擇延後通知';

  @override
  String get hintTitle => '你知道嗎？';

  @override
  String get hintDrag => '如果要重新排列習慣，可以將其拖曳到理想的位置';

  @override
  String get hintLandscape => '把手機橫放可以看到更多天數';

  @override
  String get habitNotFound => '習慣已刪除 / 搜尋不到';

  @override
  String get weekends => '週末';

  @override
  String get anyWeekday => '工作日';

  @override
  String get anyDay => '每天';

  @override
  String get selectWeekdays => '選擇天數';

  @override
  String get exportToCsv => '匯出數據 (CSV)';

  @override
  String get doneLabel => '確定';

  @override
  String get clearLabel => '清除';

  @override
  String get selectHours => '選擇小時';

  @override
  String get selectMinutes => '選擇分鐘';

  @override
  String get about => '關於本程式';

  @override
  String get translators => '翻譯人員';

  @override
  String get developers => '開發團隊';

  @override
  String versionN(String p1) {
    return '$p1 版';
  }

  @override
  String get frequency => '頻率';

  @override
  String get checkmark => '選取標記';

  @override
  String get bestStreaks => '最佳紀錄';

  @override
  String get everyDay => '每天';

  @override
  String get everyWeek => '每週';

  @override
  String get help => '幫助 & 常見問題';

  @override
  String get couldNotExport => '輸出資料失敗';

  @override
  String get couldNotImport => '匯入資料失敗';

  @override
  String get fileNotRecognized => '無法辨識檔案';

  @override
  String get habitsImported => '習慣成功輸入';

  @override
  String get importData => '資料輸入';

  @override
  String get exportFullBackup => '匯出完整備份';

  @override
  String get importDataSummary =>
      '可使用本程式所匯出的資料。\n另外也支援其他 App「Tickmate」、「HabitBull」或「Rewire」所產生的文件。\n請參閱「常見問題」來了解更多訊息。';

  @override
  String get exportAsCsvSummary =>
      '產生可以利用表格軟體打開的文件，如「Microsoft Excel」或「OpenOffice Calc」。\n此文件無法重新輸入本程式。';

  @override
  String get exportFullBackupSummary => '產生一個包含所有資料的文件。\n該文件可以再重新輸入回來。';

  @override
  String get selectPublicBackupFolder => '選擇公開備份資料夾';

  @override
  String get noPublicBackupFolderSelected => '未選取資料夾';

  @override
  String get bugReportFailed => '錯誤報告：製作失敗';

  @override
  String get generateBugReport => '製作錯誤報告';

  @override
  String get troubleshooting => '問題排除';

  @override
  String get helpTranslate => '協助翻譯本程式';

  @override
  String get nightMode => '夜間模式';

  @override
  String get usePureBlack => '在夜間模式中使用深色設定';

  @override
  String get pureBlackDescription =>
      '在夜間模式中，使用黑色背景取代灰色背景。這樣可以減少 AMOLED 螢幕手機的電量消耗。';

  @override
  String get interfacePreferences => '介面';

  @override
  String get reverseDays => '反向排序日期';

  @override
  String get reverseDaysDescription => '在主畫面上顯示反向排序的結果';

  @override
  String get day => '日';

  @override
  String get week => '週';

  @override
  String get month => '月';

  @override
  String get quarter => '季';

  @override
  String get year => '年';

  @override
  String get total => '總計';

  @override
  String get yesOrNo => '是 / 否';

  @override
  String everyXDays(int p1) {
    return '每 $p1 天';
  }

  @override
  String everyXWeeks(int p1) {
    return '每 $p1 週';
  }

  @override
  String get score => '分數';

  @override
  String get reminderSound => '提醒音效';

  @override
  String get none => '無';

  @override
  String get filter => '篩選';

  @override
  String get hideCompleted => '隱藏已完成的習慣';

  @override
  String get hideEntered => '隱藏已記錄的習慣';

  @override
  String get hideArchived => '隱藏已封存習慣';

  @override
  String get stickyNotifications => '使提醒保持常駐';

  @override
  String get stickyNotificationsDescription => '防止提醒被滑動移除';

  @override
  String get ledNotifications => '閃爍燈光通知';

  @override
  String get ledNotificationsDescription => '顯示閃爍燈光提醒。僅限於有內建 LED 通知燈的手機。';

  @override
  String get repairDatabase => '修復資料庫';

  @override
  String get databaseRepaired => '資料庫已修復';

  @override
  String get uncheck => '取消選取';

  @override
  String get toggle => '切換';

  @override
  String get action => '操作';

  @override
  String get habit => '習慣';

  @override
  String get sort => '排序';

  @override
  String get manually => '手動';

  @override
  String get byName => '根據名稱';

  @override
  String get byColor => '根據顏色';

  @override
  String get byScore => '根據分數';

  @override
  String get byStatus => '依據狀態';

  @override
  String get export => '匯出';

  @override
  String get longPressToEdit => '持續按住來改換數值';

  @override
  String get value => '值';

  @override
  String get calendar => '日曆';

  @override
  String get unit => '單位';

  @override
  String get targetType => '目標標準';

  @override
  String get targetTypeAtLeast => '以上';

  @override
  String get targetTypeAtMost => '以下';

  @override
  String get exampleQuestionBoolean => '例如：你今天運動了嗎？';

  @override
  String get question => '提示問題';

  @override
  String get target => '目標';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get customizeNotificationSummary => '變更音效、震動、燈光和其他通知設定';

  @override
  String get customizeNotification => '自訂通知';

  @override
  String get prefViewPrivacy => '檢視隱私權政策';

  @override
  String get viewAllContributors => '查看全部的貢獻者';

  @override
  String get database => '資料庫';

  @override
  String get widgetOpacityTitle => '小工具透明度';

  @override
  String get widgetOpacityDescription => '調整主畫面小工具的透明度。';

  @override
  String get firstDayOfTheWeek => '一週的第一天';

  @override
  String get defaultReminderQuestion => '你今天完成這個習慣了嗎？';

  @override
  String get notes => '備註';

  @override
  String get exampleNotes => '（非必要的）';

  @override
  String get yesOrNoExample => '例如： 你今天有早起嗎？你有運動嗎？你有下棋嗎？';

  @override
  String get measurable => '可量化的';

  @override
  String get measurableExample => '例如：今天你跑了幾英哩？你讀了幾頁書？';

  @override
  String xTimesPerWeek(int p1) {
    return '每周 $p1 次';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '每月 $p1 次';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 次每 $p2 日';
  }

  @override
  String get yesOrNoShortExample => '例如：運動';

  @override
  String get color => '顏色';

  @override
  String get exampleTarget => '例如：15';

  @override
  String get measurableShortExample => '例如：跑步';

  @override
  String get measurableQuestionExample => '例如：你今天跑了幾英里？';

  @override
  String get measurableUnitsExample => '例如：英里';

  @override
  String get everyMonth => '每個月';

  @override
  String get validationCannotBeBlank => '必填';

  @override
  String get today => '今天';

  @override
  String get enter => '輸入';

  @override
  String get noHabits => '找不到任何習慣';

  @override
  String get noNumericalHabits => '找不到可衡量的習慣';

  @override
  String get noBooleanHabits => '找不到是非題的習慣';

  @override
  String get increment => '遞增';

  @override
  String get decrement => '遞减';

  @override
  String get prefSkipTitle => '啟用跳過天數功能';

  @override
  String get prefSkipDescription =>
      '切換兩次、設定跳過，以取代完成標記。跳過功能將維持你的分數不變，不打破你的連續紀錄。';

  @override
  String get prefUnknownTitle => '在資料缺漏處顯示問號';

  @override
  String get prefUnknownDescription => '將沒有數據的天數與逾期者分開。要更改逾期設定，請切換兩次。';

  @override
  String get youAreNowADeveloper => '你現在已成為開發人員！';

  @override
  String get activityNotFound => '找不到可以處理這個動作的應用程式。';

  @override
  String get prefMidnightDelayTitle => '將一天延長到午夜過後幾個小時';

  @override
  String get prefMidnightDelayDescription =>
      '凌晨3點後再顯示新的一天。如果你通常在午夜以後才睡，這能幫上忙。重新啟動後才生效。';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣更改完成',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣已刪除',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣已封存',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣已取消封存',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你確定要刪除習慣？',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此習慣會被永久刪除，而且無法復原',
    );
    return '$_temp0';
  }
}
