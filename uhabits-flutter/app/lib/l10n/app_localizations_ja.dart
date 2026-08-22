// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class L10nJa extends L10n {
  L10nJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'ループ習慣トラッカー';

  @override
  String get mainActivityTitle => '習慣';

  @override
  String get actionSettings => '設定';

  @override
  String get edit => '編集';

  @override
  String get delete => '削除';

  @override
  String get archive => 'アーカイブ';

  @override
  String get unarchive => 'アーカイブを解除';

  @override
  String get addHabit => '習慣を追加';

  @override
  String get colorPickerDefaultTitle => '色の変更';

  @override
  String get toastHabitCreated => '習慣を作成しました';

  @override
  String get habitStrength => '習慣の強さ';

  @override
  String get history => '履歴';

  @override
  String get clear => 'クリア';

  @override
  String get reminder => 'リマインダー';

  @override
  String get save => '保存';

  @override
  String get streaks => '連続記録';

  @override
  String get noHabitsFound => '習慣はありません';

  @override
  String get noHabitsLeftToDo => '今日の習慣はすべて完了しました！';

  @override
  String get longPressToToggle => '長押しするとチェックを付けたり外したりできます';

  @override
  String get reminderOff => 'オフ';

  @override
  String get createHabit => '習慣を作成';

  @override
  String get editHabit => '習慣を編集';

  @override
  String get check => 'チェック';

  @override
  String get snooze => '後で';

  @override
  String get introTitle1 => 'ようこそ';

  @override
  String get introDescription1 => 'ループ習慣トラッカーは、良い習慣を作り、維持するのに役立ちます。';

  @override
  String get introTitle2 => '新しい習慣を作成します';

  @override
  String get introDescription2 => '毎日、習慣を実行した後、アプリでチェックマークを付けます。';

  @override
  String get introTitle4 => '進捗状況を確認できます';

  @override
  String get introDescription4 => '詳細なグラフにより、あなたの習慣が時間とともに改善していく様子がわかります。';

  @override
  String get interval15Minutes => '15 分';

  @override
  String get interval30Minutes => '30 分';

  @override
  String get interval1Hour => '1 時間';

  @override
  String get interval2Hour => '2 時間';

  @override
  String get interval4Hour => '4 時間';

  @override
  String get interval8Hour => '8 時間';

  @override
  String get interval24Hour => '24 時間';

  @override
  String get intervalAlwaysAsk => '毎回選択する';

  @override
  String get intervalCustom => 'カスタム...';

  @override
  String get prefToggleTitle => 'タップでチェックをON/OFF';

  @override
  String get prefToggleDescription2 => '長押しの代わりにワンタップでチェックマークをつけます。';

  @override
  String get prefRateThisApp => 'Google Play でこのアプリを評価';

  @override
  String get prefSendFeedback => '開発者にフィードバックを送信';

  @override
  String get prefViewSourceCode => 'GitHub でソースコードを参照';

  @override
  String get links => 'リンク';

  @override
  String get name => 'タイトル';

  @override
  String get settings => '設定';

  @override
  String get selectSnoozeDelay => 'スヌーズの遅延時間を設定';

  @override
  String get hintTitle => 'ご存知ですか?';

  @override
  String get hintDrag => 'エントリーを並べ替えるには、習慣の名前を長押しして、正しい場所にドラッグしてください。';

  @override
  String get hintLandscape => 'お使いの携帯電話を横置きモードにすることで、より多くの日数を見ることができます。';

  @override
  String get habitNotFound => '習慣が削除されているか、見つかりませんでした';

  @override
  String get weekends => '週末';

  @override
  String get anyWeekday => '月曜日から金曜日';

  @override
  String get anyDay => 'すべての曜日';

  @override
  String get selectWeekdays => '曜日の選択';

  @override
  String get exportToCsv => 'CSV としてエクスポート';

  @override
  String get doneLabel => '完了';

  @override
  String get clearLabel => 'クリア';

  @override
  String get selectHours => '何時にするかを決めます';

  @override
  String get selectMinutes => '何分するかを決めます';

  @override
  String get about => 'アプリについて';

  @override
  String get translators => '翻訳者';

  @override
  String get developers => '開発者';

  @override
  String versionN(String p1) {
    return 'バージョン $p1';
  }

  @override
  String get frequency => '頻度';

  @override
  String get checkmark => 'チェック';

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
  String get bestStreaks => '最長の連続記録';

  @override
  String get everyDay => '毎日';

  @override
  String get everyWeek => '毎週';

  @override
  String get help => 'ヘルプ & FAQ';

  @override
  String get couldNotExport => 'データのエクスポートに失敗しました。';

  @override
  String get couldNotImport => 'データのインポートに失敗しました。';

  @override
  String get fileNotRecognized => 'ファイルを認識できません。';

  @override
  String get habitsImported => '習慣を正常にインポートしました。';

  @override
  String get importData => 'データのインポート';

  @override
  String get exportFullBackup => '完全なバックアップのエクスポート';

  @override
  String get importDataSummary =>
      'このアプリでエクスポートしたフルバックアップだけではなく、Tickmate、HabitBull、Rewire で生成したファイルも同様にサポートしています。詳細については FAQ を参照してください。';

  @override
  String get exportAsCsvSummary =>
      'Microsoft Excel や OpenOffice Calc などの表計算ソフトで開くことができるファイルを生成します。このファイルはインポートで戻すことはできません。';

  @override
  String get exportFullBackupSummary =>
      'すべてのデータが含まれるファイルを生成します。このファイルはインポートして戻すことができます。';

  @override
  String get selectPublicBackupFolder => '公開バックアップフォルダを選択';

  @override
  String get noPublicBackupFolderSelected => 'フォルダが選択されていません';

  @override
  String get bugReportFailed => 'バグレポートの作成に失敗しました。';

  @override
  String get generateBugReport => 'バグレポートの作成';

  @override
  String get troubleshooting => 'トラブルシューティング';

  @override
  String get helpTranslate => 'このアプリの翻訳を支援する';

  @override
  String get nightMode => 'ダークテーマ';

  @override
  String get usePureBlack => 'ダークテーマで完全な黒を使用する';

  @override
  String get pureBlackDescription =>
      '夜間モードで灰色の背景を完全な黒で置き換えます。AMOLED ディスプレイの電話でバッテリー使用量を抑えます。';

  @override
  String get interfacePreferences => 'インターフェース';

  @override
  String get reverseDays => '日付の表示順を逆にする';

  @override
  String get reverseDaysDescription => 'メイン画面で日付を逆順に表示します';

  @override
  String get day => '日';

  @override
  String get week => '週';

  @override
  String get month => '月';

  @override
  String get quarter => '四半期';

  @override
  String get year => '年';

  @override
  String get total => '合計';

  @override
  String get yesOrNo => 'はい / いいえ';

  @override
  String everyXDays(int p1) {
    return '$p1 日ごと';
  }

  @override
  String everyXWeeks(int p1) {
    return '$p1 週ごと';
  }

  @override
  String get score => 'スコア';

  @override
  String get reminderSound => 'リマインダーの音';

  @override
  String get none => 'なし';

  @override
  String get filter => 'フィルター';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => '達成した習慣を非表示';

  @override
  String get hideEntered => '入力されたものを非表示にする';

  @override
  String get hideArchived => 'アーカイブした習慣を非表示';

  @override
  String get stickyNotifications => '通知を固定';

  @override
  String get stickyNotificationsDescription => '通知をスワイプして消せないようにする';

  @override
  String get ledNotifications => '通知ランプ';

  @override
  String get ledNotificationsDescription =>
      'リマインダーで通知LEDを点滅します。通知LEDのある携帯でのみ有効です。';

  @override
  String get repairDatabase => 'データベースを修復';

  @override
  String get databaseRepaired => 'データベースが修復されました。';

  @override
  String get uncheck => 'チェックを外す';

  @override
  String get toggle => '切り替え';

  @override
  String get action => 'アクション';

  @override
  String get habit => '習慣';

  @override
  String get sort => '並び替え';

  @override
  String get manually => '手動で並び替え';

  @override
  String get byName => '名前で並び替え';

  @override
  String get byColor => '色で並び替え';

  @override
  String get byScore => 'スコアで並び替え';

  @override
  String get byStatus => 'ステータスで並び替え';

  @override
  String get export => 'エクスポート';

  @override
  String get longPressToEdit => '長押しすると値を変更できます';

  @override
  String get value => '値';

  @override
  String get calendar => 'カレンダー';

  @override
  String get unit => '単位';

  @override
  String get targetType => '目標タイプ';

  @override
  String get targetTypeAtLeast => '少なくとも';

  @override
  String get targetTypeAtMost => '最大でも';

  @override
  String get exampleQuestionBoolean => '例：今日は運動しましたか？';

  @override
  String get question => '質問';

  @override
  String get target => '目標';

  @override
  String get yes => 'はい';

  @override
  String get no => 'いいえ';

  @override
  String get customizeNotificationSummary => '音、バイブレーション、通知ランプ、その他の通知設定を変更する';

  @override
  String get customizeNotification => '通知をカスタマイズする';

  @override
  String get prefViewPrivacy => 'プライバシーポリシーを見る';

  @override
  String get viewAllContributors => 'すべての貢献者を表示&#8230;';

  @override
  String get database => 'データベース';

  @override
  String get widgetOpacityTitle => 'ウィジェットの透明度';

  @override
  String get widgetOpacityDescription => 'ホーム画面のウィジェットの透明度を調節します。';

  @override
  String get firstDayOfTheWeek => '週の始まりの曜日';

  @override
  String get defaultReminderQuestion => '今日この習慣を完了しましたか？';

  @override
  String get notes => 'メモ';

  @override
  String get exampleNotes => '（省略可）';

  @override
  String get yesOrNoExample => '例：今日は早く起きましたか？運動しましたか？チェスをしましたか？';

  @override
  String get measurable => '数えられるもの';

  @override
  String get measurableExample => '例：今日は何キロ走りましたか？何ページ読みましたか？';

  @override
  String xTimesPerWeek(int p1) {
    return '1 週間に $p1 回';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '1 か月に $p1 回';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 回 $p2 日';
  }

  @override
  String get yesOrNoShortExample => '例：運動';

  @override
  String get color => '色';

  @override
  String get exampleTarget => '例：15';

  @override
  String get measurableShortExample => '例：ランニング';

  @override
  String get measurableQuestionExample => '例：今日は何km走りましたか?';

  @override
  String get measurableUnitsExample => '例：km';

  @override
  String get everyMonth => '毎月';

  @override
  String get validationCannotBeBlank => '空白にはできません';

  @override
  String get today => '今日';

  @override
  String get enter => '入力';

  @override
  String get noHabits => '習慣が見つかりませんでした';

  @override
  String get noNumericalHabits => '量を記録するタイプの習慣は見つかりませんでした';

  @override
  String get noBooleanHabits => 'はい/いいえタイプの習慣は見つかりませんでした';

  @override
  String get increment => '増加';

  @override
  String get decrement => '減少';

  @override
  String get prefSkipTitle => 'スキップ日を有効にする';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      '2回切り替えることで、チェックマークの代わりにスキップを追加できます。スキップはスコアに影響を与えず、連続記録を継続させたままにできます。';

  @override
  String get prefUnknownTitle => '入力のない日に？マークを表示する';

  @override
  String get prefUnknownDescription =>
      'データが未入力である日と実行しなかった日とを区別します。実行しなかったことを記録するには、2回切り替えます。';

  @override
  String get youAreNowADeveloper => 'これで開発者になりました!';

  @override
  String get activityNotFound => 'この操作を行うアプリが見つかりませんでした。';

  @override
  String get prefMidnightDelayTitle => '一日の終わりを午前0時から数時間延長する';

  @override
  String get prefMidnightDelayDescription =>
      '一日の始まりを午前3時にします。よく午前0時以降に就寝する場合に役立ちます。アプリの再起動が必要です。';

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
      other: '習慣を変更しました',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣を削除しました',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣をアーカイブしました',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣のアーカイブを解除しました',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣を削除',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '習慣は完全に削除されます。この操作を元に戻すことはできません。',
    );
    return '$_temp0';
  }
}
