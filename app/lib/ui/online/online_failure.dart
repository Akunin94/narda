import '../../l10n/gen/app_text.dart';
import '../../online/online_backend.dart';

/// Почему онлайн не вышел — одним текстом на языке интерфейса.
String onlineFailureText(AppText text, OnlineFailure failure) =>
    switch (failure) {
      OnlineFailure.notConfigured => text.onlineNotConfigured,
      OnlineFailure.network => text.onlineNetworkError,
      OnlineFailure.roomNotFound => text.onlineNoRoom,
      OnlineFailure.roomFull => text.onlineRoomFull,
    };
