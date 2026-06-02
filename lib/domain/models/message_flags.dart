import '../enums/message_enums.dart';

/// [MessageFlag] 集合与位掩码（持久化于 Drift）的互转工具。
class MessageFlags {
  const MessageFlags._();

  static int toBitmask(Set<MessageFlag> flags) {
    var mask = 0;
    for (final f in flags) {
      mask |= 1 << f.index;
    }
    return mask;
  }

  static Set<MessageFlag> fromBitmask(int mask) {
    return {
      for (final f in MessageFlag.values)
        if (mask & (1 << f.index) != 0) f,
    };
  }

  static bool has(int mask, MessageFlag flag) => mask & (1 << flag.index) != 0;

  static int withFlag(int mask, MessageFlag flag, bool value) {
    return value ? (mask | (1 << flag.index)) : (mask & ~(1 << flag.index));
  }
}
