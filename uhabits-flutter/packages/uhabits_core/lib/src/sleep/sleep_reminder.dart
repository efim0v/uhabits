import '../time/date_utils.dart';
import 'sleep_goal.dart';

/// When to ask for a night that has not arrived.
///
/// The moment is the goal's wake time plus a delay, read in the goal's own
/// frame — so during an adaptation the prompt travels with the goal rather
/// than staying on the clock the person left behind.
///
/// Always in the future. When today's night is already on record the answer
/// is tomorrow's: a prompt for something the app is already holding is a
/// prompt that teaches people to ignore prompts.
int nextSleepPromptMillis({
  required SleepGoal goal,
  required int effectiveOffsetMinutes,
  required int nowMillis,
  required bool todaysNightRecorded,
}) {
  final int promptMinutes =
      (goal.wakeMinutes + goal.promptAfterWakeMinutes) % 1440;

  final int localNow = nowMillis + effectiveOffsetMinutes * 60000;
  final int startOfLocalDay =
      _floorDiv(localNow, DateUtils.dayLength) * DateUtils.dayLength;
  var localPrompt = startOfLocalDay + promptMinutes * 60000;

  if (localPrompt <= localNow || todaysNightRecorded) {
    localPrompt += DateUtils.dayLength;
  }
  return localPrompt - effectiveOffsetMinutes * 60000;
}

int _floorDiv(int a, int b) {
  final int q = a ~/ b;
  return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
}
